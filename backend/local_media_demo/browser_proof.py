"""Real local TLS + production resolver + Flutter keypad proof; no interception.

python -m local_media_demo.browser_proof WEB_BUILD OUTPUT_DIR
Requires existing Chromium, Playwright, openssl, ffprobe, and loopback port 443.
Creates a temporary certificate trusted only by this test Chromium's SPKI pin.
Never installs a trust root, disables general TLS checks, or contacts Supabase.
"""
import base64
import hashlib
import json
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import urlsplit

import uvicorn
from playwright.sync_api import sync_playwright
from .server import create_app, validate_clip, TLS_ORIGIN


def main():
    web_dir, output = map(Path, sys.argv[1:3])
    output.mkdir(parents=True, exist_ok=True)
    fixture = Path(__file__).resolve().parents[2] / 'TV2_flutter/test/fixtures/tutorial_test_pattern.mp4'
    validate_clip(fixture)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        key, cert = root/'key.pem', root/'cert.pem'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
                        '-keyout',str(key),'-out',str(cert),'-subj','/CN=tv2-media.example.org',
                        '-addext','subjectAltName=DNS:tv2-media.example.org'],check=True,capture_output=True)
        public = subprocess.run(['openssl','x509','-in',str(cert),'-pubkey','-noout'],check=True,capture_output=True).stdout
        der = subprocess.run(['openssl','pkey','-pubin','-outform','DER'],input=public,check=True,capture_output=True).stdout
        pin = base64.b64encode(hashlib.sha256(der).digest()).decode()
        session = secrets.token_urlsafe(32)
        app = create_app(owner_session=session, storage=root/'media', origin=TLS_ORIGIN, web_dir=web_dir)
        server = uvicorn.Server(uvicorn.Config(app,host='127.0.0.1',port=443,
            ssl_keyfile=str(key),ssl_certfile=str(cert),log_level='error'))
        thread = threading.Thread(target=server.run,daemon=True);thread.start()
        try:
            for _ in range(100):
                if server.started: break
                time.sleep(.1)
            if not server.started: raise RuntimeError('Local TLS server could not bind 127.0.0.1:443')
            with sync_playwright() as p:
                browser = p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=[
                    '--no-sandbox','--no-proxy-server',
                    '--host-resolver-rules=MAP tv2-media.example.org 127.0.0.1',
                    '--ignore-certificate-errors-spki-list='+pin])
                owner = browser.new_context(viewport={'width':390,'height':844})
                viewer = browser.new_context(viewport={'width':390,'height':844})
                owner.add_cookies([{'name':'local_owner','value':session,'url':TLS_ORIGIN,'httpOnly':True,'secure':True,'sameSite':'Strict'}])
                owner_page = owner.new_page();owner_page.goto(TLS_ORIGIN+'/owner')
                owner_page.locator('#clip').set_input_files(str(fixture))
                owner_page.get_by_role('button',name='Upload listing video').click()
                owner_page.get_by_text('Published for local viewers.',exact=True).wait_for()
                owner_page.screenshot(path=str(output/'owner-upload.png'))
                page=viewer.new_page(); responses=[]; requests=[]
                page.on('request',lambda r: requests.append(r.url))
                page.on('response',lambda r: responses.append(r))
                page.goto(TLS_ORIGIN+'/')
                page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
                page.get_by_role('button',name='+1 Shared calling-code namespace',exact=True).click()
                for digit in ['5','2','4','7']:
                    page.get_by_role('button',name=digit,exact=True).click()
                # Wait for the real HTTP exact lookup before entering the listing.
                page.wait_for_function('document.body.innerText.includes("Local owner fixture")')
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_role('button',name='Load listing video',exact=True).wait_for()
                exact=[r for r in responses if '/v1/resolve?' in r.url]
                assert exact and exact[-1].status == 200
                record=exact[-1].json()['listing']; assert record['country_code']=='1' and record['list_number']=='5247'
                uri=record['resources'][0]['uri'];digest=hashlib.sha256(fixture.read_bytes()).hexdigest()
                assert uri == TLS_ORIGIN+'/clips/'+digest+'.mp4'
                assert not any('/clips/' in u for u in requests)
                assert page.evaluate("async()=> (await fetch('/owner')).status") == 403
                assert page.evaluate("async()=> (await fetch('/listings/1*5247/video',{method:'PUT',body:'bad',headers:{'Content-Type':'video/mp4'}})).status") == 403
                # Low-bandwidth media-only phase; renderer assets already loaded.
                cdp=viewer.new_cdp_session(page);cdp.send('Network.enable')
                cdp.send('Network.emulateNetworkConditions',{'offline':False,'latency':150,'downloadThroughput':8192,'uploadThroughput':8192})
                started=time.monotonic()
                page.get_by_role('button',name='Load listing video',exact=True).click()
                page.get_by_role('button',name='Play listing video',exact=True).wait_for(timeout=30000)
                load_seconds=time.monotonic()-started
                assert page.locator('video').evaluate('(v)=>v.paused && v.currentTime===0')
                media=[r for r in responses if '/clips/' in r.url]
                assert media and media[-1].status in (200,206)
                assert media[-1].security_details()['protocol'].startswith('TLS')
                assert media[-1].server_addr()['ipAddress']=='127.0.0.1'
                assert media[-1].headers['content-type']=='video/mp4'
                # Slow the tiny synthetic clip for observation, not the app code.
                page.locator('video').evaluate('(v)=>v.playbackRate=0.25')
                page.get_by_role('button',name='Play listing video',exact=True).click()
                page.wait_for_function('document.querySelector("video").currentTime > 0.1')
                playback=page.locator('video').evaluate('(v)=>({time:v.currentTime,paused:v.paused,width:v.videoWidth,height:v.videoHeight})')
                assert not playback['paused'] and playback['width']==160
                page.screenshot(path=str(output/'viewer-playback.png'))
                page.get_by_role('button',name='Replay listing video',exact=True).wait_for(timeout=15000)
                page.get_by_role('button',name='Dismiss listing video',exact=True).click()
                page.get_by_role('button',name='Show listing video',exact=True).wait_for()
                # Real byte-range round trip, not mocked browser data.
                ranged=page.evaluate("""async (uri)=>{const r=await fetch(uri,{headers:{Range:'bytes=0-31'}});return {status:r.status,range:r.headers.get('Content-Range'),bytes:(await r.arrayBuffer()).byteLength}}""",uri)
                assert ranged['status']==206 and ranged['bytes']==32
                assert all(urlsplit(u).hostname=='tv2-media.example.org' for u in requests if u.startswith('http'))
                result={'browser':browser.version,'resolver':'production /v1/prefix and /v1/resolve via HttpResolverApi',
                    'tls':media[-1].security_details()['protocol'],'server_ip':media[-1].server_addr()['ipAddress'],
                    'request_interception':False,'separate_owner_visitor_contexts':True,'visitor_write_rejected':True,
                    'uploaded_sha256':digest,'playback':playback,'range':ranged,'load_seconds':round(load_seconds,3),
                    'network':{'latency_ms':150,'bytes_per_second':8192},'no_media_before_opt_in':True,'no_autoplay':True,
                    'scope':'local synthetic ownership; real TLS with ephemeral test pin and local DNS mapping; no hosted auth/storage'}
                (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));browser.close()
        finally:
            server.should_exit=True;thread.join(timeout=5)

if __name__=='__main__': main()
