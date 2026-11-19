"""Local verification host for www/. No auth, sessions, API or write routes.
Owner-private hosting/access control remains a separate approval and responsibility.
"""
from http.server import BaseHTTPRequestHandler
import mimetypes
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


def handler_for(root):
    root = Path(root).resolve()
    files = {p.resolve() for p in root.rglob('*') if p.is_file() and not p.is_symlink()}
    class ReadOnly(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def reject(self, code, headers=None):
            self.send_response(code)
            self.send_header('Cache-Control','no-store')
            self.send_header('Content-Length','0')
            for k,v in (headers or {}).items(): self.send_header(k,v)
            self.end_headers()
        def do_GET(self): self.serve()
        def do_HEAD(self): self.serve(head=True)
        def do_POST(self): self.reject(405, {'Allow':'GET, HEAD'})
        do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_TRACE = do_CONNECT = do_POST
        def serve(self, head=False):
            raw=unquote(urlsplit(self.path).path)
            path=(root/raw.lstrip('/')).resolve()
            if raw.endswith('/'): path=path/'index.html'
            if not path.is_relative_to(root) or path not in files:
                return self.reject(404)
            size=path.stat().st_size; start=0; end=size-1; code=200
            value=self.headers.get('Range')
            if value:
                match=re.fullmatch(r'bytes=(\d*)-(\d*)',value)
                if not match or not any(match.groups()) or size==0:
                    return self.reject(416,{'Content-Range':f'bytes */{size}'})
                first,last=match.groups()
                if first:
                    start=int(first); end=min(int(last),size-1) if last else size-1
                else:
                    length=int(last); start=max(0,size-length)
                if start>=size or start>end:
                    return self.reject(416,{'Content-Range':f'bytes */{size}'})
                code=206
            self.send_response(code)
            self.send_header('Content-Type',mimetypes.guess_type(path)[0] or 'application/octet-stream')
            self.send_header('Cache-Control','no-store')
            self.send_header('X-Content-Type-Options','nosniff')
            self.send_header('Referrer-Policy','no-referrer')
            self.send_header('Accept-Ranges','bytes')
            self.send_header('Content-Length',str(end-start+1))
            if code==206: self.send_header('Content-Range',f'bytes {start}-{end}/{size}')
            self.end_headers()
            if not head:
                with path.open('rb') as f:
                    f.seek(start); self.wfile.write(f.read(end-start+1))
    return ReadOnly
