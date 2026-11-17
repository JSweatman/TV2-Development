"""Read-only public synthetic canary headers. Never read/archive response bodies."""
import os
import re
import time
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None


def main():
    raw=os.environ['CANARY_ORIGIN']
    origin=urlsplit(raw)
    if origin.scheme!='https' or not origin.hostname or origin.username or origin.password or origin.port not in (None,443) or origin.path not in ('','/') or origin.query or origin.fragment:
        raise ValueError('Expected one HTTPS origin')
    deadline=datetime.fromisoformat(os.environ['CANARY_EXPIRES_AT'].replace('Z','+00:00'))
    if deadline.tzinfo is None: raise ValueError('Timezone required')
    remaining=(deadline-datetime.now(timezone.utc)).total_seconds()
    if not 30 <= remaining <= 480: raise ValueError('Need 30–480 seconds remaining when job starts; reset canary window')
    opener=build_opener(NoRedirect())
    def check(path,status,range_header=None):
        headers={'User-Agent':'TV2-Synthetic-Expiry-Smoke/1.0'}
        if range_header: headers['Range']=range_header
        try: response=opener.open(Request(raw.rstrip('/')+path,headers=headers),timeout=15)
        except HTTPError as response_error: response=response_error
        with response:
            assert response.status==status, f'{path}: expected {status}, received {response.status}'
            assert 'no-store' in response.headers.get('Cache-Control','').lower(), 'Missing no-store'
            if status==200: assert 'text/html' in response.headers.get('Content-Type','').lower()
            if status==206:
                assert 'video/mp4' in response.headers.get('Content-Type','').lower()
                assert re.fullmatch(r'bytes 0-15/\d+',response.headers.get('Content-Range',''))
            # Deliberately no response.read(), body logging or uploaded artifact.
            print(f'PASS {path} status={status} no-store range={bool(range_header)}',flush=True)
    check('/',200)
    check('/clip.mp4',206,'bytes=0-15')
    while datetime.now(timezone.utc) <= deadline:
        time.sleep(min(5,max(.05,(deadline-datetime.now(timezone.utc)).total_seconds())))
    check('/',410)
    check('/clip.mp4',410)
    check('/clip.mp4',410,'bytes=0-15')
    print('PASS active and first post-deadline HTTP checks; network timing cannot establish exact boundary equality')

if __name__=='__main__':main()
