"""Integrated visitor proof: local TLS and shared resolver handlers; no interception.

python -m local_media_demo.visitor_proof WEB_BUILD OUTPUT_DIR [--review]
Requires existing Chromium, Playwright, openssl, ffprobe, and loopback port 443.
Creates a temporary certificate trusted only by this test Chromium's SPKI pin.
Never installs a trust root, disables general TLS checks, or contacts Supabase.
"""
import base64
import hashlib
import json
import re
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
from .visitor_fixtures import install_visitor_fixtures


def main():
    web_dir, output = map(Path, sys.argv[1:3])
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        fixture = root/'sample.mp4'
        subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i',
                        'testsrc2=size=160x90:rate=15','-t','8','-an',
                        '-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',
                        str(fixture)], check=True, capture_output=True)
        validate_clip(fixture)
        key, cert = root/'key.pem', root/'cert.pem'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
                        '-keyout',str(key),'-out',str(cert),'-subj','/CN=tv2-media.example.org',
                        '-addext','subjectAltName=DNS:tv2-media.example.org'],check=True,capture_output=True)
        public = subprocess.run(['openssl','x509','-in',str(cert),'-pubkey','-noout'],check=True,capture_output=True).stdout
        der = subprocess.run(['openssl','pkey','-pubin','-outform','DER'],input=public,check=True,capture_output=True).stdout
        pin = base64.b64encode(hashlib.sha256(der).digest()).decode()
        session = secrets.token_urlsafe(32)
        app = create_app(owner_session=session, storage=root/'media', origin=TLS_ORIGIN, web_dir=web_dir)
        install_visitor_fixtures(app)
        server = uvicorn.Server(uvicorn.Config(app,host='127.0.0.1',port=443,
            ssl_keyfile=str(key),ssl_certfile=str(cert),log_level='error'))
        thread = threading.Thread(target=server.run,daemon=True);thread.start()
        try:
            for _ in range(100):
                if server.started: break
                time.sleep(.1)
            if not server.started: raise RuntimeError('Local TLS server could not bind 127.0.0.1:443')
            with sync_playwright() as p:
                browser = p.chromium.launch(executable_path='/usr/bin/chromium',headless='--review' not in sys.argv,args=[
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
                for digit in ['7','0','0','0','0','1']:
                    page.get_by_role('button',name=re.compile(r'^0(?:\s|$)') if digit == '0' else digit,exact=digit != '0').click()
                # Wait for the real HTTP exact lookup before entering the listing.
                assert not any('/v1/resolve?' in r.url for r in responses)
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_role('button',name='Load listing video',exact=True).wait_for()
                exact=[r for r in responses if '/v1/resolve?' in r.url]
                assert exact and exact[-1].status == 200
                record=exact[-1].json()['listing']; assert record['country_code']=='1' and record['list_number']=='700001'
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
                from .landscape_checks import verify_landscape
                rotation = verify_landscape(page, output)
                page.get_by_role('button',name='Replay listing video',exact=True).wait_for(timeout=15000)
                page.get_by_role('button',name='Dismiss listing video',exact=True).click()
                page.get_by_role('button',name='Show listing video',exact=True).wait_for()
                assert page.locator('video').count() == 0
                # Genuine external browser handoff; no activity tracking in TV2.
                page.mouse.wheel(0, 550)
                with page.expect_popup() as popup_event:
                    page.get_by_role('button', name='WEBSITE', exact=True).click()
                destination = popup_event.value
                destination.wait_for_url(TLS_ORIGIN + '/sample-website')
                assert destination.get_by_role('heading', name='Northstar Workshop').is_visible()
                destination.screenshot(path=str(output/'website.png'))
                destination.close(); page.bring_to_front()
                page.get_by_role('button', name='Show listing video', exact=True).wait_for()
                page.screenshot(path=str(output/'listing-return.png'))
                page.get_by_role('button', name='Back', exact=True).click()
                page.get_by_role('button', name='ENTER', exact=True).wait_for()
                assert '700001' in page.locator('body').inner_text()
                # Preview selection fills the full qualified number, without navigation.
                page.mouse.wheel(0, -800)
                page.get_by_role('button', name='Clear', exact=True).click()
                for digit in ['7','0','0','0','0','1']:
                    page.get_by_role('button',name=re.compile(r'^0(?:\s|$)') if digit=='0' else digit,exact=digit!='0').click()
                page.mouse.move(195, 400); page.mouse.wheel(0, -1500)
                page.wait_for_timeout(1200)
                page.screenshot(path=str(output/'suggestion.png'))
                page.get_by_role('button', name=re.compile('Northstar')).click()
                page.get_by_role('button',name='ENTER',exact=True).wait_for()
                page.wait_for_function("document.body.innerText.includes('1*700001')")
                assert page.get_by_role('button',name='Load listing video',exact=True).count()==0
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_role('button',name='Load listing video',exact=True).wait_for()
                page.get_by_role('button',name='Back',exact=True).click()
                page.get_by_role('button',name='Clear',exact=True).click()
                for digit in ['7','0','0','0','2']:
                    page.get_by_role('button',name=re.compile(r'^0(?:\s|$)') if digit=='0' else digit,exact=digit!='0').click()
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_text('Alex (sample)',exact=True).wait_for()
                assert page.get_by_role('button',name='Load listing video',exact=True).count()==0
                page.screenshot(path=str(output/'personal.png'))
                page.get_by_role('button',name='Back',exact=True).click()
                page.get_by_role('button',name='Clear',exact=True).click()
                for digit in '999999':
                    page.get_by_role('button',name=digit,exact=True).click()
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_text('No exact match. ENTER retries.',exact=True).wait_for()
                page.mouse.move(195, 650); page.mouse.wheel(0, 500)
                page.get_by_role('button',name='ENTER',exact=True).wait_for()
                assert page.get_by_role('button',name='ENTER',exact=True).is_enabled()
                # Real byte-range round trip, not mocked browser data.
                ranged=page.evaluate("""async (uri)=>{const r=await fetch(uri,{headers:{Range:'bytes=0-31'}});return {status:r.status,range:r.headers.get('Content-Range'),bytes:(await r.arrayBuffer()).byteLength}}""",uri)
                assert ranged['status']==206 and ranged['bytes']==32
                assert all(urlsplit(u).hostname=='tv2-media.example.org' for u in requests if u.startswith('http'))
                result={'browser':browser.version,'resolver':'local /v1/prefix and /v1/resolve via shared handlers and HttpResolverApi',
                    'tls':media[-1].security_details()['protocol'],'server_ip':media[-1].server_addr()['ipAddress'],
                    'request_interception':False,'separate_owner_visitor_contexts':True,'visitor_write_rejected':True,
                    'uploaded_sha256':digest,'playback':playback,'range':ranged,'load_seconds':round(load_seconds,3),
                    'network':{'latency_ms':150,'bytes_per_second':8192},'no_media_before_opt_in':True,'no_autoplay':True,
                    'rotation':rotation,'visitor_flow':{'immediate_enter':True,'qualified_selection':True,'website_popup_return':True,'personal_account_free':True,'unavailable_retry':True},'scope':'local synthetic ownership; real TLS with ephemeral test pin and local DNS mapping; no hosted auth/storage'}
                (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
                if '--review' in sys.argv:
                    review = browser.new_context(viewport={'width':390,'height':844}).new_page()
                    review.goto(TLS_ORIGIN+'/review')
                    print('Local synthetic visitor review ready in isolated Chromium; Ctrl-C stops and deletes disposable data.')
                    try:
                        while not review.is_closed():
                            review.wait_for_timeout(1000)
                    except KeyboardInterrupt:
                        pass
                browser.close()
        finally:
            server.should_exit=True;thread.join(timeout=5)

if __name__=='__main__': main()
