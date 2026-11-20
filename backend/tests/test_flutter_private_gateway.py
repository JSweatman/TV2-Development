import json
from pathlib import Path
import sys
import httpx
from fastapi.testclient import TestClient
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from private_media_lab.flutter_gateway import create_gateway
from private_media_lab.app import connect
from private_media_lab.providers import DiskPrivateStore, AuthRejected

class Auth:
    origin='http://127.0.0.1:54329'
    valid=True
    def user(self,token):
        if not self.valid or token!='synthetic-token':raise AuthRejected()
        return 'synthetic-owner'

def test_cookie_boundary_and_invalid_session(tmp_path,monkeypatch):
    original=httpx.AsyncClient
    def response(r):
        body=json.loads(r.content)
        return httpx.Response(200,json={'access_token':'synthetic-token'}) if body['password']=='fixture' else httpx.Response(401)
    monkeypatch.setattr(httpx,'AsyncClient',lambda **kw:original(transport=httpx.MockTransport(response)))
    web=tmp_path/'web';web.mkdir();(web/'index.html').write_text('fixture')
    db=tmp_path/'db';auth=Auth()
    app=create_gateway(auth=auth,store=DiskPrivateStore(tmp_path/'objects'),database=db,web_dir=web)
    with connect(db) as con:con.execute('INSERT INTO listings VALUES (?,?)',('1*73141','synthetic-owner'))
    c=TestClient(app);origin={'Origin':'http://testserver'}
    assert c.post('/preview/session',json={'email':'x','password':'fixture'}).status_code==403
    assert c.put('/private/listings/1*73141/uploads',headers={**origin,'Authorization':'Bearer synthetic-token'},content=b'bad').status_code==401
    assert c.post('/preview/session',headers=origin,content=b'x'*2049).status_code==413
    assert c.post('/preview/session',headers=origin,json={'email':'x','password':'wrong'}).status_code==401
    r=c.post('/preview/session',headers=origin,json={'email':'x','password':'fixture'})
    assert r.json()=={'owner':True}
    assert 'HttpOnly' in r.headers['set-cookie'] and 'SameSite=strict' in r.headers['set-cookie']
    assert 'synthetic-token' not in r.text and 'synthetic-token' not in r.headers['set-cookie']
    # Role is determined for the selected exact listing, never globally.
    with connect(db) as con:con.execute('INSERT INTO listings VALUES (?,?)',('1*73142','another-owner'))
    assert c.post('/preview/session',headers=origin,json={'email':'x','password':'fixture','listing':'1*73142'}).json()=={'owner':False}
    assert c.put('/private/listings/1*73142/uploads',headers={**origin,'Content-Type':'video/mp4'},content=b'bad').status_code==403
    assert c.post('/private/listings/1*73142/publish/arbitrary',headers=origin).status_code==403
    assert c.post('/preview/session',headers=origin,json={'email':'x','password':'fixture','listing':'1*99999'}).status_code==400
    auth.valid=False
    assert c.put('/private/listings/1*73141/uploads',headers={**origin,'Content-Type':'video/mp4'},content=b'bad').status_code==401
    assert c.delete('/preview/session',headers=origin).status_code==200
    assert not app.state.preview_sessions
