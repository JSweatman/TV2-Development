import secrets
import subprocess
import sys
from pathlib import Path
from uuid import uuid4
import httpx
import pytest
from fastapi.testclient import TestClient
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from private_media_lab.app import create_app, connect
from private_media_lab.providers import SupabaseAuth, SupabasePrivateStore, DiskPrivateStore, AuthRejected
OWNER, VIEWER, OUTSIDER=[str(uuid4()) for _ in range(3)]
TOKENS={secrets.token_urlsafe(32):uid for uid in (OWNER,VIEWER,OUTSIDER)}
HEADERS={uid:{'Authorization':'Bearer '+t} for t,uid in TOKENS.items()}
IDENTITY='1*73141'; BASE='/private/listings/'+IDENTITY

def auth_response(r):
    token=r.headers.get('authorization','').removeprefix('Bearer ')
    if token not in TOKENS:return httpx.Response(401)
    return httpx.Response(200,json={'id':TOKENS[token],'role':'authenticated','is_anonymous':False,'user_metadata':{'owner':True}})

@pytest.fixture
def lab(tmp_path):
    clip=tmp_path/'clip.mp4'
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=blue:s=160x90:d=1','-c:v','libx264','-pix_fmt','yuv420p',str(clip)],check=True)
    auth=SupabaseAuth('http://127.0.0.1:54329',httpx.Client(transport=httpx.MockTransport(auth_response)))
    store=DiskPrivateStore(tmp_path/'objects'); db=tmp_path/'metadata.sqlite'
    app=create_app(enabled=True,auth=auth,store=store,database=db)
    with connect(db) as con:
        con.execute('INSERT INTO listings VALUES (?,?)',(IDENTITY,OWNER))
        con.execute('INSERT INTO listings VALUES (?,?)',('81*37585',VIEWER))
        con.execute('INSERT INTO viewers VALUES (?,?)',(IDENTITY,VIEWER))
    return TestClient(app),auth,store,db,clip.read_bytes()

def upload(c,data,uid=OWNER,base=BASE,**headers):
    return c.put(base+'/uploads',content=data,headers={**HEADERS[uid],'Content-Type':'video/mp4',**headers})

def test_owner_publish_viewer_restart(lab):
    c,auth,store,db,data=lab
    r=upload(c,data); assert r.status_code==200 and not r.json()['published']
    key=r.json()['upload_id']
    assert c.get(BASE+'/video',headers=HEADERS[VIEWER]).status_code==404
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[VIEWER]).status_code==403
    assert c.post('/private/listings/81*37585/publish/'+key,headers=HEADERS[VIEWER]).status_code==404
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[OWNER]).status_code==200
    c=TestClient(create_app(enabled=True,auth=auth,store=DiskPrivateStore(store.root),database=db))
    r=c.get(BASE+'/video',headers=HEADERS[VIEWER]);assert r.content==data
    assert r.headers['cache-control']=='no-store'
    assert c.get(BASE+'/video',headers=HEADERS[OUTSIDER]).status_code==403
    assert c.get(BASE+'/video').status_code==401
    r=c.get(BASE+'/video',headers={**HEADERS[VIEWER],'Range':'bytes=0-15'})
    assert r.status_code==206 and r.content==data[:16]
    assert c.get(BASE+'/video',headers={**HEADERS[VIEWER],'Range':'bytes=999999-'}).status_code==416
    with connect(db) as con: con.execute('DELETE FROM viewers')
    assert c.get(BASE+'/video',headers=HEADERS[VIEWER]).status_code==403

def test_denials_limits(lab):
    c,_,store,db,data=lab
    assert upload(c,data,VIEWER).status_code==403
    assert upload(c,data,OUTSIDER).status_code==403
    assert upload(c,data,base='/private/listings/81*73141').status_code==403
    assert c.put(BASE+'/uploads',content=data).status_code==401
    assert upload(c,data,**{'Authorization':'Bearer fabricated'}).status_code==401
    assert upload(c,data,**{'Content-Type':'text/html'}).status_code==415
    assert upload(c,b'not media').status_code==422
    assert upload(c,data,**{'Content-Length':'5242881'}).status_code==413
    assert upload(c,data,**{'Content-Length':'1'}).status_code==400
    assert not list(store.root.iterdir())
    with connect(db) as con: assert con.execute('SELECT count(*) FROM uploads').fetchone()[0]==0

def test_owner_rechecked_after_ingest(lab):
    c,_,store,db,data=lab;original=store.put
    def transfer(key,body):
        original(key,body)
        with connect(db) as con: con.execute('UPDATE listings SET owner=? WHERE identity=?',(VIEWER,IDENTITY))
    store.put=transfer
    assert upload(c,data).status_code==403
    assert not list(store.root.iterdir())

def test_corruption(lab):
    c,_,store,_,data=lab;key=upload(c,data).json()['upload_id']
    store.path(key).write_bytes(b'corrupt')
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[OWNER]).status_code==409
    store.path(key).write_bytes(data)
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[OWNER]).status_code==200
    store.path(key).unlink()
    assert c.get(BASE+'/video',headers=HEADERS[VIEWER]).status_code==503

def test_disabled_no_side_effect(tmp_path):
    path=tmp_path/'absent.sqlite';c=TestClient(create_app(database=path))
    assert c.put(BASE+'/uploads').status_code==404 and not path.exists()

@pytest.mark.parametrize('origin',['https://real.supabase.co','http://localhost:1234','http://127.0.0.1:1234/path','http://u:p@127.0.0.1:1234'])
def test_remote_provider_refused(origin):
    with pytest.raises(ValueError):SupabaseAuth(origin)
    with pytest.raises(ValueError):SupabasePrivateStore(origin,'fixture')

@pytest.mark.parametrize('payload',[{'id':OWNER,'role':'authenticated','is_anonymous':True},{'id':OWNER,'role':'service_role','is_anonymous':False},{'id':'invalid','role':'authenticated','is_anonymous':False},{'id':OWNER,'role':'authenticated'}])
def test_identity_fails_closed(payload):
    client=httpx.Client(transport=httpx.MockTransport(lambda r:httpx.Response(200,json=payload)))
    with pytest.raises(AuthRejected):SupabaseAuth('http://127.0.0.1:1234',client).user('fixture')

def test_storage_contract():
    objects={};seen=[]
    def provider(r):
        seen.append(r);assert r.headers['authorization']=='Bearer server-fixture'
        if r.url.path.startswith('/bucket/'):return httpx.Response(200,json={'public':False,'file_size_limit':5242880,'allowed_mime_types':['video/mp4']})
        if r.method=='POST':
            assert r.headers['x-upsert']=='false';objects[r.url.path]=r.content;return httpx.Response(200,json={})
        if r.method=='GET':return httpx.Response(200,content=objects[r.url.path])
        return httpx.Response(200,json={})
    store=SupabasePrivateStore('http://127.0.0.1:54328','server-fixture',httpx.Client(transport=httpx.MockTransport(provider)))
    key=str(uuid4());store.put(key,b'controlled');assert store.get(key)==b'controlled';store.delete(key)
    assert len(seen)==4
    with pytest.raises(ValueError):store.get('../escape')
    bad=httpx.Client(transport=httpx.MockTransport(lambda r:httpx.Response(200,json={'public':True})))
    with pytest.raises(ValueError):SupabasePrivateStore('http://127.0.0.1:54328','fixture',bad)

def test_auth_provider_outage_is_denied():
    client=httpx.Client(transport=httpx.MockTransport(lambda r:httpx.Response(503)))
    with pytest.raises(AuthRejected):SupabaseAuth('http://127.0.0.1:1234',client).user('fixture')

def test_old_owner_cannot_publish_after_transfer(lab):
    c,_,_,db,data=lab;key=upload(c,data).json()['upload_id']
    with connect(db) as con:con.execute('UPDATE listings SET owner=? WHERE identity=?',(VIEWER,IDENTITY))
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[OWNER]).status_code==403
    assert c.post(BASE+'/publish/'+key,headers=HEADERS[VIEWER]).status_code==404

def test_storage_outage_leaves_no_publication(lab):
    c,_,store,db,data=lab
    def fail(*args):raise httpx.ConnectError('local provider unavailable')
    store.put=fail;c.raise_server_exceptions=False
    assert upload(c,data).status_code==503
    with connect(db) as con:
        assert con.execute('SELECT count(*) FROM uploads').fetchone()[0]==0
        assert con.execute('SELECT count(*) FROM publications').fetchone()[0]==0
