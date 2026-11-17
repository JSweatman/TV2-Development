"""Actual local GoTrue + Storage round trip; no remote URL or real user data."""
import hashlib
import json
from pathlib import Path
import secrets
import subprocess
import threading
import time
import httpx
import uvicorn
from .app import create_app, connect
from .providers import SupabaseAuth, SupabasePrivateStore

AUTH='http://127.0.0.1:54329'
STORAGE='http://127.0.0.1:54328'
SERVICE='http://127.0.0.1:54327'
BASE='/private/listings/1*73141'


def run_proof(secret, output):
    output.mkdir(parents=True, exist_ok=True)
    client=httpx.Client(trust_env=False,timeout=15)
    identities=[]
    for role in ('owner','viewer','outsider'):
        password=secrets.token_urlsafe(32)
        email=role+'-'+secrets.token_hex(4)+'@example.invalid'
        r=client.post(AUTH+'/signup',json={'email':email,'password':password})
        r.raise_for_status()
        # Exercise genuine password sign-in, not an injected owner cookie.
        r=client.post(AUTH+'/token?grant_type=password',json={'email':email,'password':password})
        r.raise_for_status();session=r.json()
        identities.append((session['user']['id'],session['access_token']))
    (owner,ot),(viewer,vt),(outsider,xt)=identities
    headers=lambda token:{'Authorization':'Bearer '+token}
    auth=SupabaseAuth(AUTH)
    assert auth.user(ot)==owner and auth.user(vt)==viewer
    store=SupabasePrivateStore(STORAGE,secret)
    db=output/'private-metadata.sqlite'
    app=create_app(enabled=True,auth=auth,store=store,database=db)
    with connect(db) as conn:
        conn.execute('INSERT INTO listings VALUES (?,?)',('1*73141',owner))
        conn.execute('INSERT INTO viewers VALUES (?,?)',('1*73141',viewer))
    clip=output/'synthetic.mp4'
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=blue:s=160x90:d=2','-c:v','libx264','-pix_fmt','yuv420p',str(clip)],check=True)
    data=clip.read_bytes();digest=hashlib.sha256(data).hexdigest()
    def start():
        app=create_app(enabled=True,auth=SupabaseAuth(AUTH),store=SupabasePrivateStore(STORAGE,secret),database=db)
        from fastapi.responses import HTMLResponse
        @app.get('/local-viewer', response_class=HTMLResponse)
        def viewer_page():
            return '<!doctype html><html lang="en"><meta name="viewport" content="width=device-width"><title>Private local media proof</title><h1>Synthetic private media</h1><p>Local provider integration harness, not the TV2 Flutter UI.</p><video controls preload="none" width="320" src="'+BASE+'/video"></video><button onclick="document.querySelector(\'video\').play()">Play synthetic clip</button></html>'
        server=uvicorn.Server(uvicorn.Config(app,host='127.0.0.1',port=54327,log_level='error',access_log=False))
        thread=threading.Thread(target=server.run,daemon=True);thread.start()
        for _ in range(100):
            if server.started:return server,thread
            time.sleep(.05)
        raise RuntimeError('private service did not start')
    def stop(server,thread):
        server.should_exit=True;thread.join(5)
    server,thread=start()
    results={}
    try:
        def put(token):return client.put(SERVICE+BASE+'/uploads',headers={**headers(token),'Content-Type':'video/mp4'},content=data)
        results['nonowner_upload']=put(vt).status_code;assert results['nonowner_upload']==403
        results['forged_token_upload']=put('fabricated').status_code;assert results['forged_token_upload']==401
        results['anonymous_upload']=client.put(SERVICE+BASE+'/uploads',content=data).status_code;assert results['anonymous_upload']==401
        r=put(ot);r.raise_for_status();key=r.json()['upload_id'];assert not r.json()['published']
        results['owner_upload']=r.status_code
        assert client.get(SERVICE+BASE+'/video',headers=headers(vt)).status_code==404
        r=client.post(SERVICE+BASE+'/publish/'+key,headers=headers(vt));results['nonowner_publish']=r.status_code;assert r.status_code==403
        r=client.post(SERVICE+BASE+'/publish/'+key,headers=headers(ot));r.raise_for_status();results['owner_publish']=r.status_code
        object_path='/object/tv2-private-lab/'+key+'.mp4'
        for label,token in [('owner',ot),('viewer',vt)]:
            r=client.post(STORAGE+object_path,headers={**headers(token),'Content-Type':'video/mp4'},content=data)
            assert r.status_code>=400;results[label+'_direct_storage_write']=r.status_code
            r=client.get(STORAGE+object_path,headers=headers(token))
            assert r.status_code>=400;results[label+'_direct_storage_read']=r.status_code
        r=client.get(STORAGE+'/object/public/tv2-private-lab/'+key+'.mp4')
        assert r.status_code>=400;results['public_bucket_read']=r.status_code
        assert client.get(SERVICE+BASE+'/video',headers=headers(xt)).status_code==403
        assert client.get(SERVICE+BASE+'/video').status_code==401
        results['unauthorized_playback']=403
        # Stop the service and restart actual Storage container; retain its volume.
        stop(server,thread)
        subprocess.run(['docker','restart','tv2-private-storage'],check=True,capture_output=True)
        for _ in range(100):
            try:
                if client.get(STORAGE+'/status').status_code==200:break
            except httpx.HTTPError:pass
            time.sleep(.1)
        server,thread=start()
        r=client.get(SERVICE+BASE+'/video',headers=headers(vt));r.raise_for_status()
        assert hashlib.sha256(r.content).hexdigest()==digest
        results['service_and_storage_restart_preserved_sha256']=True
        (output/'viewer-download.mp4').write_bytes(r.content)
        rr=client.get(SERVICE+BASE+'/video',headers={**headers(vt),'Range':'bytes=0-31'})
        assert rr.status_code==206 and rr.content==data[:32];results['authorized_range']=206
        # Real Chromium decoder, separate owner/viewer contexts, explicit Play.
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
            owner_context=browser.new_context(extra_http_headers=headers(ot))
            viewer_context=browser.new_context(extra_http_headers=headers(vt))
            page=viewer_context.new_page(); media_requests=[]
            page.on('request',lambda request: media_requests.append(request.url) if request.url.endswith('/video') else None)
            # Minimal local media harness (not Flutter UI); fetch uses viewer auth.
            page.goto(SERVICE+'/local-viewer')
            page.locator('video').wait_for()
            assert page.locator('video').evaluate('(v)=>v.paused')
            assert media_requests == []
            page.get_by_role('button',name='Play synthetic clip').click()
            page.wait_for_function('document.querySelector("video").currentTime > 0.2')
            results['browser_playback']={'browser':browser.version,'current_time':page.locator('video').evaluate('(v)=>v.currentTime'),'paused_before_explicit_play':True,'harness':'local explicit-play HTML harness; not Flutter'}
            page.screenshot(path=str(output/'authorized-viewer.png'))
            owner_context.close();viewer_context.close();browser.close()
        with connect(db) as conn:conn.execute('DELETE FROM viewers')
        assert client.get(SERVICE+BASE+'/video',headers=headers(vt)).status_code==403
        results['revoked_viewer_denied']=True
        results.update({'clip_sha256':digest,'clip_bytes':len(data),'real_gotrue':True,'real_supabase_storage':True,'private_bucket':True,'remote_requests':False,'physical_devices':0})
        (output/'result.json').write_text(json.dumps(results,indent=2)+'\n')
        print(json.dumps(results))
    finally:
        stop(server,thread)
        client.close()
