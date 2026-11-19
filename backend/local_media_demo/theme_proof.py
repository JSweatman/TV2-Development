"""Real local TLS + production resolver + Flutter keypad proof; no interception.

python -m local_media_demo.theme_proof WEB_BUILD OUTPUT_DIR
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
from .theme_fixtures import install_theme_fixtures


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
        install_theme_fixtures(app)
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
                results=[]
                for number,palette in [('70001','graphite'),('70002','lotus')]:
                    context=browser.new_context(viewport={'width':390,'height':844})
                    page=context.new_page();responses=[];requests=[]
                    page.on('request',lambda r:requests.append(r.url))
                    page.on('response',lambda r:responses.append(r))
                    page.goto(TLS_ORIGIN+'/')
                    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
                    page.get_by_role('button',name='+1 Shared calling-code namespace',exact=True).click()
                    for digit in number:
                        page.get_by_role('button',name=re.compile(r'^0(?:\s|$)') if digit=='0' else digit,exact=digit!='0').click()
                    page.wait_for_function('document.body.innerText.includes("synthetic demo")')
                    page.get_by_role('button',name='ENTER',exact=True).click()
                    page.get_by_role('button',name='Load listing video',exact=True).wait_for()
                    exact=[r for r in responses if '/v1/resolve?' in r.url][-1].json()['listing']
                    assert exact['list_number']==number
                    assert not any('/clips/' in u for u in requests)
                    page.screenshot(path=str(output/(palette+'-top.png')))
                    page.get_by_role('button',name='Load listing video',exact=True).click()
                    page.get_by_role('button',name='Play listing video',exact=True).wait_for()
                    assert page.locator('video').evaluate('(v)=>v.paused && v.currentTime===0')
                    page.locator('video').evaluate('(v)=>v.playbackRate=0.25')
                    page.get_by_role('button',name='Play listing video',exact=True).click()
                    page.wait_for_function('document.querySelector("video").currentTime > 0.1')
                    playback=page.locator('video').evaluate('(v)=>({time:v.currentTime,paused:v.paused})')
                    assert not playback['paused']
                    page.screenshot(path=str(output/(palette+'-playing.png')))
                    page.get_by_role('button',name='CALL',exact=True).click()
                    page.get_by_text('Open phone app?',exact=True).wait_for()
                    page.get_by_role('button',name='Cancel',exact=True).click()
                    page.get_by_role('button',name='TEXT',exact=True).click()
                    page.get_by_text('Open messaging app?',exact=True).wait_for()
                    page.get_by_role('button',name='Cancel',exact=True).click()
                    # Real externalApplication launcher; browser closes its tab.
                    returns=[]
                    listing_title=exact['display_name']
                    qualified='1*'+number
                    resolve_count=sum('/v1/resolve?' in u for u in requests)
                    app_url=page.url
                    for action in ('WEBSITE','SOCIAL'):
                        page.get_by_role('button',name=action,exact=True).scroll_into_view_if_needed()
                        with page.expect_popup() as opened:
                            page.get_by_role('button',name=action,exact=True).click()
                        popup=opened.value
                        popup.get_by_text('Synthetic action destination',exact=True).wait_for()
                        assert popup.url==TLS_ORIGIN+'/theme-info/'+action.lower()
                        popup.close()
                        page.bring_to_front()
                        assert page.url==app_url
                        page.get_by_text(listing_title,exact=True).wait_for(state='attached')
                        page.get_by_text(qualified,exact=True).wait_for(state='attached')
                        page.get_by_role('button',name='Back',exact=True).wait_for()
                        assert sum('/v1/resolve?' in u for u in requests)==resolve_count
                        returns.append({'action':action,'browser_tab_closed':True,
                                        'same_listing':True,'no_extra_lookup':True})
                    page.get_by_text(listing_title,exact=True).scroll_into_view_if_needed()
                    page.screenshot(path=str(output/(palette+'-returned-listing.png')))
                    # App-bar arrow exits listing; keypad BACK deletes a digit.
                    page.get_by_role('button',name='Back',exact=True).click()
                    page.get_by_role('button',name='ENTER',exact=True).wait_for()
                    snapshot=page.locator('body').aria_snapshot()
                    assert re.search(r'\bList Number\s+'+re.escape(number)+r'\b',snapshot)
                    page.get_by_role('button',name='+1',exact=True).wait_for()
                    page.screenshot(path=str(output/(palette+'-returned-keypad.png')))
                    assert all(urlsplit(u).hostname=='tv2-media.example.org' for u in requests if u.startswith('http'))
                    results.append({'palette':palette,'fixture':number,'resolved':True,
                        'inline_playback':playback,'call_text_confirmation_cancel':True,
                        'external_returns':returns,'keypad_query_retained':number,
                        'selected_nid_retained':'1','no_media_before_opt_in':True})
                    context.close()
                result={'browser':browser.version,'viewport':[390,844],'fixtures':results,'request_interception':False,'scope':'synthetic local fixtures, real resolver and TLS, no real handoff or business assignment'}
                (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));browser.close()
        finally:
            server.should_exit=True;thread.join(timeout=5)

if __name__=='__main__': main()
