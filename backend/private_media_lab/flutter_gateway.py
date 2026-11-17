"""Explicit local browser gateway; never imported by deployed app.py."""
import secrets
import json
import httpx
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from .app import create_app, connect
from .providers import AuthRejected


def create_gateway(*, auth, store, database, web_dir):
    app = create_app(enabled=True, auth=auth, store=store, database=database)
    sessions = {}  # Test-only, process memory. No token reaches Flutter or browser storage.
    app.state.preview_sessions = sessions

    @app.middleware('http')
    async def session_cookie(request, call_next):
        if request.client.host not in ('127.0.0.1', '::1', 'testclient') or request.url.hostname not in ('127.0.0.1', 'testserver'):
            return JSONResponse({}, status_code=403)
        if request.method not in ('GET', 'HEAD') and request.headers.get('origin') != str(request.base_url).rstrip('/'):
            return JSONResponse({}, status_code=403)
        # Browser sessions only: caller-provided authorization is not forwarded.
        headers = [(k,v) for k,v in request.scope['headers'] if k != b'authorization']
        token = sessions.get(request.cookies.get('tv2_preview', ''))
        if token:
            headers.append((b'authorization', ('Bearer '+token).encode()))
        request.scope['headers'] = headers
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        return response

    @app.post('/preview/session')
    async def sign_in(request: Request):
        data = bytearray()
        async for chunk in request.stream():
            if len(data) + len(chunk) > 2048:
                return JSONResponse({}, status_code=413)
            data.extend(chunk)
        try:
            body = json.loads(data)
            email, password = body['email'], body['password']
            if not isinstance(email,str) or not isinstance(password,str) or len(email)>254 or not 1<=len(password)<=256:
                raise ValueError()
            # Existing disposable GoTrue only; no signup or admin API exposed here.
            async with httpx.AsyncClient(trust_env=False,timeout=5) as client:
                r = await client.post(auth.origin+'/token?grant_type=password',json={'email':email,'password':password})
            r.raise_for_status()
            token = r.json()['access_token']
            uid = auth.user(token)
        except (KeyError, ValueError, TypeError, httpx.HTTPError, AuthRejected):
            return JSONResponse({'error':'Sign-in unavailable. Check the test account and retry.'},status_code=401)
        old = request.cookies.get('tv2_preview',''); sessions.pop(old,None)
        sid = secrets.token_urlsafe(32); sessions[sid]=token
        with connect(database) as db:
            owner = db.execute('SELECT 1 FROM listings WHERE identity=? AND owner=?',('1*73141',uid)).fetchone() is not None
        response = JSONResponse({'owner':owner})
        response.set_cookie('tv2_preview',sid,httponly=True,samesite='strict',path='/')
        # HTTP is exclusively loopback; TLS/Secure cookies remain a staging gate.
        return response

    @app.delete('/preview/session')
    def sign_out(request: Request):
        sessions.pop(request.cookies.get('tv2_preview',''),None)
        response = JSONResponse({});response.delete_cookie('tv2_preview',path='/')
        return response

    app.mount('/', StaticFiles(directory=web_dir,html=True))
    return app
