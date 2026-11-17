"""Optional request-time landing/media gate. Mounted only by expiry_app.

Production must inject the existing trusted exact RPC and private media source.
No static mount, redirects, signed URLs, caller clock, or public storage URL.
"""
import re
from fastapi import FastAPI, Request
from fastapi.responses import Response, HTMLResponse


def create_gate(exact, clip: bytes):
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)

    @app.middleware('http')
    async def gate(request: Request, next_handler):
        try:
            response = await next_handler(request)
        except Exception:
            response = Response(status_code=503)
        response.headers['Cache-Control'] = 'no-store, max-age=0'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        return response

    @app.api_route('/listing/{number}', methods=['GET', 'HEAD'])
    def landing(number: str, request: Request):
        if exact(number) is None:
            return Response(status_code=404)
        # Synthetic content only; identity is constrained by exact lookup.
        return HTMLResponse('' if request.method == 'HEAD' else
            '<!doctype html><html lang="en"><title>Limited preview</title>'
            '<h1>Limited preview</h1>' +
            ('<video controls preload="none" src="../media/'+number+'"></video>' if clip else '<p>No media configured.</p>') + '</html>')

    @app.api_route('/media/{number}', methods=['GET', 'HEAD'])
    def media(number: str, request: Request):
        # Check before every body, range, HEAD or conditional response.
        if exact(number) is None or not clip:
            return Response(status_code=404)
        size = len(clip)
        start, end, status = 0, size - 1, 200
        headers = {'Accept-Ranges': 'bytes'}
        value = request.headers.get('range')
        if value:
            match = re.fullmatch(r'bytes=(\d*)-(\d*)', value)
            if not match or not any(match.groups()):
                return Response(status_code=416, headers={'Content-Range': f'bytes */{size}'})
            a, b = match.groups()
            if a:
                start, end = int(a), min(int(b), size-1) if b else size-1
            else:
                start = max(0, size-int(b))
            if start > end or start >= size or (not a and int(b) == 0):
                return Response(status_code=416, headers={'Content-Range': f'bytes */{size}'})
            status = 206
            headers['Content-Range'] = f'bytes {start}-{end}/{size}'
        headers['Content-Length'] = str(end-start+1)
        return Response(b'' if request.method == 'HEAD' else clip[start:end+1],
                        status_code=status, headers=headers, media_type='video/mp4')
    return app
