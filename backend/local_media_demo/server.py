"""Loopback-only synthetic ownership/upload proof, NOT production authentication.

Run through the test harness, which injects a random owner session into one
browser context. A second unauthenticated context reads the published listing.
The deployed app.py never imports or mounts this application.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import os
import secrets
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlsplit
import sys

from fastapi import APIRouter, FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

MAX_BYTES = 5 * 1024 * 1024
IDENTITY = '1*5247'
TLS_ORIGIN = 'https://tv2-media.example.org'


def validate_clip(path: Path) -> None:
    """Bounded local validator. Production needs isolated decoding/transcoding."""
    with path.open('rb') as source:
        header = source.read(12)
    if len(header) < 12 or header[4:8] != b'ftyp':
        raise ValueError('Expected MP4')
    result = subprocess.run([
        'ffprobe', '-v', 'error', '-protocol_whitelist', 'file',
        '-show_entries', 'format=duration:stream=codec_type,codec_name,width,height',
        '-of', 'json', str(path),
    ], capture_output=True, timeout=5, check=True)
    info = json.loads(result.stdout)
    duration = float(info['format']['duration'])
    streams = info['streams']
    videos = [s for s in streams if s['codec_type'] == 'video']
    if not 0 < duration <= 30 or len(videos) != 1 or len(streams) > 2:
        raise ValueError('Expected a short single-video clip')
    video = videos[0]
    # Bound the encoded pixel dimensions independently of portrait/landscape.
    short_side, long_side = sorted((video['width'], video['height']))
    if video['codec_name'] != 'h264' or not (0 < short_side <= 1080 and long_side <= 1920):
        raise ValueError('Unsupported video')
    for stream in streams:
        if stream is not video and (stream['codec_type'] != 'audio' or stream['codec_name'] != 'aac'):
            raise ValueError('Unsupported track')


def create_app(*, owner_session: str, storage: Path, origin: str,
               web_dir: Path | None = None) -> FastAPI:
    if os.getenv('TV2_REPOSITORY', 'fixture') != 'fixture':
        raise ValueError('Local proof requires fixture repository mode')
    if origin != TLS_ORIGIN and (not origin.startswith('http://127.0.0.1:') or not origin.removeprefix('http://127.0.0.1:').isdigit()):
        raise ValueError('Loopback origin required')
    if len(owner_session) < 32:
        raise ValueError('Inject a random local owner session')
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    storage.mkdir(parents=True, exist_ok=True)
    csrf = secrets.token_urlsafe(32)
    published: str | None = None
    upload_lock = asyncio.Lock()

    @app.middleware('http')
    async def loopback_only(request: Request, call_next):
        from fastapi.responses import Response
        if request.client is None or request.client.host not in ('127.0.0.1', '::1', 'testclient') or request.headers.get('host') != urlsplit(origin).netloc:
            return Response(status_code=403)
        response = await call_next(request)
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Cache-Control'] = 'no-store'
        return response

    def require_owner(request: Request):
        if not secrets.compare_digest(request.cookies.get('local_owner', ''), owner_session):
            raise HTTPException(403, 'Local fixture owner session required')

    @app.get('/owner', response_class=HTMLResponse)
    def owner(request: Request):
        require_owner(request)
        return '''<!doctype html><html lang="en"><meta name="viewport" content="width=device-width"><title>Local TV2 upload proof</title>
<h1>Local test owner — 1*5247</h1><p>Simulated owner session, not a live account. Upload a synthetic MP4, maximum 5 MiB / 30 seconds.</p>
<label>Video <input id="clip" type="file" accept="video/mp4"></label><button id="upload">Upload listing video</button><p id="status" role="status"></p>
<script>document.querySelector('#upload').onclick=async()=>{
const f=document.querySelector('#clip').files[0]; if(!f)return;
const s=document.querySelector('#status');s.textContent='Uploading…';
try {const r=await fetch('/listings/1*5247/video',{method:'PUT',headers:{'Content-Type':'video/mp4','X-Local-CSRF':''' + json.dumps(csrf) + '''},body:f});
s.textContent=r.ok?'Published for local viewers.':'Upload rejected ('+r.status+').';}catch(e){s.textContent='Upload failed.';}};</script></html>'''

    @app.put('/listings/{identity}/video')
    async def upload(identity: str, request: Request):
        nonlocal published
        require_owner(request)
        if request.headers.get('origin') != origin or not secrets.compare_digest(request.headers.get('x-local-csrf', ''), csrf):
            raise HTTPException(403, 'Same-origin owner action required')
        if identity != IDENTITY:
            raise HTTPException(403, 'Owner does not own this fixture')
        if request.headers.get('content-type') != 'video/mp4':
            raise HTTPException(415, 'Only MP4 is supported')
        try:
            length = int(request.headers.get('content-length', '-1'))
        except ValueError:
            length = -1
        if length < 1 or length > MAX_BYTES:
            raise HTTPException(413, 'Expected 1 byte to 5 MiB')
        if upload_lock.locked():
            raise HTTPException(409, 'Upload already in progress')
        async with upload_lock:
            path = None
            try:
                with tempfile.NamedTemporaryFile(dir=storage, suffix='.mp4', delete=False) as target:
                    path = Path(target.name)
                    size = 0
                    async for chunk in request.stream():
                        size += len(chunk)
                        if size > MAX_BYTES:
                            raise HTTPException(413, 'Video too large')
                        target.write(chunk)
                if size != length:
                    raise HTTPException(400, 'Incomplete video')
                try:
                    await asyncio.to_thread(validate_clip, path)
                except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError):
                    raise HTTPException(422, 'Invalid or unsupported short MP4')
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                destination = storage / (digest + '.mp4')
                path.replace(destination)
                old = published
                published = digest
                if old and old != digest:
                    (storage / (old + '.mp4')).unlink(missing_ok=True)
                return {'published': True, 'sha256': digest}
            finally:
                if path:
                    path.unlink(missing_ok=True)

    # Real route functions, identity grammar, schemas and repository interface.
    # Dependency override belongs only to this local app, not the deployed app.
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
    import app as resolver
    from repository import FixtureRepository, ListingRecord, ResourceRecord

    class PublishedFixtureRepository(FixtureRepository):
        def get_listing(self, country_code, base, tldx):
            record = super().get_listing(country_code, base, tldx)
            if record is None or published is None:
                return record
            from dataclasses import replace
            media_origin = origin if origin == TLS_ORIGIN else 'https://media.example.org'
            return replace(record, resources=(ResourceRecord(
                'video', 'listing_video', f'{media_origin}/clips/{published}.mp4',
                {'publication': 'published', 'content_type': 'video/mp4'}),))

    fixture_repository = PublishedFixtureRepository([ListingRecord(
        '1', '5247', None, 'Local owner fixture', 'test', 'basic')])
    routes = APIRouter(routes=[route for route in resolver.app.routes
                              if route.path.startswith('/v1/')])
    app.include_router(routes)
    app.dependency_overrides[resolver.get_repository] = lambda: fixture_repository

    @app.get('/clips/{name}')
    def clip(name: str):
        if published is None or name != published + '.mp4':
            raise HTTPException(404)
        return FileResponse(storage / name, media_type='video/mp4')

    if web_dir:
        app.mount('/', StaticFiles(directory=web_dir, html=True))
    return app
