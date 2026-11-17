"""Disabled-by-default, separate local private-media service. No public resolver mount."""
from contextlib import contextmanager
import asyncio
import httpx
import hashlib
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import tempfile
from uuid import uuid4

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import Response
from local_media_demo.server import MAX_BYTES, validate_clip
from .providers import AuthRejected


@contextmanager
def connect(path):
    db = sqlite3.connect(path, timeout=5)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    try:
        with db:
            yield db
    finally:
        db.close()


def initialize(path):
    with connect(path) as db:
        db.executescript('''
        CREATE TABLE IF NOT EXISTS listings(identity TEXT PRIMARY KEY, owner TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS viewers(identity TEXT REFERENCES listings, user TEXT,
          PRIMARY KEY(identity,user));
        CREATE TABLE IF NOT EXISTS uploads(id TEXT PRIMARY KEY, identity TEXT REFERENCES listings,
          owner TEXT NOT NULL, digest TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS publications(identity TEXT PRIMARY KEY REFERENCES listings,
          upload TEXT NOT NULL REFERENCES uploads);
        ''')
    os.chmod(path, 0o600)


def create_app(*, enabled=False, auth=None, store=None, database: Path | None = None):
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    if not enabled:
        return app  # No auth, storage, DB, routes or network access.
    if auth is None or store is None or database is None:
        raise ValueError('Explicit local providers required')
    initialize(database)
    lock = asyncio.Lock()

    @app.middleware('http')
    async def private_loopback(request, call_next):
        if request.client is None or request.client.host not in ('127.0.0.1', '::1', 'testclient'):
            return Response(status_code=403)
        if request.url.hostname not in ('127.0.0.1', 'testserver'):
            return Response(status_code=403)
        response = await call_next(request)
        response.headers.update({'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'})
        return response

    def user(request):
        header = request.headers.get('authorization', '')
        if not header.startswith('Bearer '):
            raise HTTPException(401, 'Verified identity required')
        try:
            return auth.user(header[7:])
        except AuthRejected:
            raise HTTPException(401, 'Verified identity required') from None

    def owner(db, identity, uid):
        if not re.fullmatch(r'[1-9][0-9]{0,2}\*[0-9]{1,15}', identity):
            raise HTTPException(403, 'Exact owned listing required')
        row = db.execute('SELECT owner FROM listings WHERE identity=?', (identity,)).fetchone()
        if row is None or row['owner'] != uid:
            raise HTTPException(403, 'Exact owned listing required')

    @app.put('/private/listings/{identity}/uploads')
    async def upload(identity: str, request: Request):
        uid = await asyncio.to_thread(user, request)
        with connect(database) as db:
            owner(db, identity, uid)
        if request.headers.get('content-type') != 'video/mp4':
            raise HTTPException(415)
        try:
            length = int(request.headers.get('content-length', '-1'))
        except ValueError:
            length = -1
        if not 0 < length <= MAX_BYTES:
            raise HTTPException(413)
        if lock.locked():
            raise HTTPException(409, 'Another ingest is running')
        async with lock:
            data = bytearray()
            async for chunk in request.stream():
                if len(data) + len(chunk) > MAX_BYTES:
                    raise HTTPException(413)
                data.extend(chunk)
            if len(data) != length:
                raise HTTPException(400)
            with tempfile.NamedTemporaryFile(suffix='.mp4') as f:
                f.write(data); f.flush()
                try:
                    await asyncio.to_thread(validate_clip, Path(f.name))
                except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError):
                    raise HTTPException(422, 'Unsupported short MP4') from None
            key = str(uuid4())
            digest = hashlib.sha256(data).hexdigest()
            try:
                await asyncio.to_thread(store.put, key, bytes(data))
            except (OSError, ValueError, httpx.HTTPError):
                raise HTTPException(503, 'Private storage unavailable') from None
            try:
                # Recheck authoritative ownership after ingest, in the metadata transaction.
                with connect(database) as db:
                    db.execute('BEGIN IMMEDIATE')
                    owner(db, identity, uid)
                    db.execute('INSERT INTO uploads VALUES (?,?,?,?)', (key, identity, uid, digest))
            except Exception:
                await asyncio.to_thread(store.delete, key)
                raise
            return {'upload_id': key, 'sha256': digest, 'published': False}

    @app.post('/private/listings/{identity}/publish/{upload_id}')
    def publish(identity: str, upload_id: str, request: Request):
        uid = user(request)
        with connect(database) as db:
            db.execute('BEGIN IMMEDIATE')
            owner(db, identity, uid)
            row = db.execute('SELECT * FROM uploads WHERE id=? AND identity=? AND owner=?',
                             (upload_id, identity, uid)).fetchone()
            if row is None:
                raise HTTPException(404)
            try:
                data = store.get(upload_id)
            except (OSError, ValueError, httpx.HTTPError):
                raise HTTPException(409, 'Stored media unavailable') from None
            if hashlib.sha256(data).hexdigest() != row['digest']:
                raise HTTPException(409, 'Stored media failed integrity check')
            db.execute('INSERT INTO publications VALUES (?,?) ON CONFLICT(identity) DO UPDATE SET upload=excluded.upload',
                       (identity, upload_id))
        return {'published': True, 'reference': '/private/listings/' + identity + '/video'}

    @app.get('/private/listings/{identity}/video')
    def video(identity: str, request: Request):
        uid = user(request)
        with connect(database) as db:
            allowed = db.execute('SELECT 1 FROM listings WHERE identity=? AND owner=? UNION SELECT 1 FROM viewers WHERE identity=? AND user=?',
                                 (identity, uid, identity, uid)).fetchone()
            if not allowed:
                raise HTTPException(403)
            row = db.execute('SELECT u.id,u.digest FROM publications p JOIN uploads u ON u.id=p.upload WHERE p.identity=?', (identity,)).fetchone()
        if row is None:
            raise HTTPException(404)
        try:
            data = store.get(row['id'])
        except (OSError, ValueError, httpx.HTTPError):
            raise HTTPException(503, 'Media unavailable') from None
        if hashlib.sha256(data).hexdigest() != row['digest']:
            raise HTTPException(503, 'Media integrity failure')
        headers = {'Accept-Ranges': 'bytes'}
        if request.headers.get('range'):
            match = re.fullmatch(r'bytes=(\d+)-(\d*)', request.headers['range'])
            if not match:
                raise HTTPException(416, headers={'Content-Range': f'bytes */{len(data)}'})
            start = int(match[1]); end = int(match[2]) if match[2] else len(data)-1
            end = min(end, len(data)-1)
            if start > end:
                raise HTTPException(416, headers={'Content-Range': f'bytes */{len(data)}'})
            headers['Content-Range'] = f'bytes {start}-{end}/{len(data)}'
            return Response(data[start:end+1], status_code=206, media_type='video/mp4', headers=headers)
        return Response(data, media_type='video/mp4', headers=headers)

    return app
