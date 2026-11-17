from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from fastapi.testclient import TestClient
from expiry_app import configured_gate
from repository import SupabaseResolverRepository

class Repo(SupabaseResolverRepository):
    def __init__(self): self.calls=0;self.active=True
    def get_listing(self,*args):
        self.calls+=1
        return object() if self.active else None

def test_gate_boundaries_and_direct_ranges():
    now=datetime(2030,1,1,tzinfo=timezone.utc)
    repo=Repo()
    with TemporaryDirectory() as directory:
        path=Path(directory)/'synthetic.mp4';path.write_bytes(b'0000ftyp' + b'0'*32)
        env={'TV2_LIMITED_ENABLED':'true','TV2_LIMITED_COUNTRY':'1',
             'TV2_LIMITED_NUMBER':'70001','TV2_LIMITED_NOT_AFTER':now.isoformat(),
             'TV2_LIMITED_MP4_FILE':str(path)}
        for delta in (-1,0,1):
            client=TestClient(configured_gate(env,repo,now=lambda:now+timedelta(microseconds=delta)))
            for target in ('listing','media'):
                for method in ('GET','HEAD'):
                    for headers in ({},{'range':'bytes=0-3'},{'range':'bytes=-4'}, {'if-none-match':'*'}):
                        r=client.request(method,f'/{target}/70001',headers=headers)
                        assert r.status_code == (404 if delta>=0 else 206 if target=='media' and 'range' in headers else 200)
                        assert 'no-store' in r.headers['cache-control']
                        if delta>=0 or method=='HEAD':assert not r.content
        repo.active=False
        client=TestClient(configured_gate(env,repo,now=lambda:now-timedelta(seconds=1)))
        assert client.get('/media/70001').status_code==404
        assert client.get('/listing/70002').status_code==404

def test_default_invalid_and_missing_media():
    repo=Repo()
    for env in ({},{'TV2_LIMITED_ENABLED':'true'}, {'TV2_LIMITED_ENABLED':'true','TV2_LIMITED_NOT_AFTER':'bad'}):
        assert TestClient(configured_gate(env,repo)).get('/listing/70001').status_code==404
    assert repo.calls==0
    env={'TV2_LIMITED_ENABLED':'true','TV2_LIMITED_COUNTRY':'1','TV2_LIMITED_NUMBER':'70001',
         'TV2_LIMITED_NOT_AFTER':'2099-01-01T00:00:00Z'}
    client=TestClient(configured_gate(env,repo))
    assert 'No media configured' in client.get('/listing/70001').text
    assert client.get('/media/70001').status_code==404
    assert TestClient(configured_gate(env,object())).get('/listing/70001').status_code==503
