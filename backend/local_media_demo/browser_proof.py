"""Run only locally: python -m local_media_demo.browser_proof WEB_BUILD OUTPUT_DIR.

Requires existing Chromium, Playwright and ffprobe. No provisioning or uploads
outside loopback. Uses only the repository's one-second synthetic blue fixture.
"""
import hashlib
import json
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import time

import httpx
import uvicorn
from playwright.sync_api import sync_playwright
from .server import create_app, validate_clip


def main():
    web_dir, output = map(Path, sys.argv[1:3])
    output.mkdir(parents=True, exist_ok=True)
    fixture = Path(__file__).resolve().parents[2] / 'TV2_flutter/test/fixtures/tutorial_test_pattern.mp4'
    validate_clip(fixture)
    origin = 'http://127.0.0.1:8088'
    with tempfile.TemporaryDirectory() as directory:
        session = secrets.token_urlsafe(32)
        app = create_app(owner_session=session, storage=Path(directory), origin=origin, web_dir=web_dir)
        server = uvicorn.Server(uvicorn.Config(app, host='127.0.0.1', port=8088, log_level='error'))
        thread = threading.Thread(target=server.run, daemon=True)
        thread.start()
        try:
            for _ in range(100):
                try:
                    if httpx.get(origin + '/v1/resolve?input=5247').status_code == 200:
                        break
                except httpx.TransportError:
                    pass
                time.sleep(.1)
            with sync_playwright() as p:
                browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
                owner = browser.new_context(viewport={'width': 390, 'height': 844})
                viewer = browser.new_context(viewport={'width': 390, 'height': 844})
                owner.add_cookies([{'name':'local_owner','value':session,'url':origin,'httpOnly':True,'sameSite':'Strict'}])
                assert viewer.request.get(origin+'/owner').status == 403
                assert viewer.request.put(origin+'/listings/1*5247/video',data=fixture.read_bytes(),headers={'Content-Type':'video/mp4'}).status == 403
                before = viewer.request.get(origin+'/v1/resolve?input=5247').json()
                assert before['listing']['resources'] == []
                owner_page = owner.new_page()
                owner_page.goto(origin+'/owner')
                owner_page.locator('#clip').set_input_files(str(fixture))
                owner_page.get_by_role('button',name='Upload listing video').click()
                owner_page.get_by_text('Published for local viewers.',exact=True).wait_for()
                owner_page.screenshot(path=str(output/'owner-upload.png'))
                record = viewer.request.get(origin+'/v1/resolve?input=5247').json()['listing']
                uri = record['resources'][0]['uri']
                digest = hashlib.sha256(fixture.read_bytes()).hexdigest()
                assert uri.endswith('/'+digest+'.mp4')
                requests = []
                def local_clip(route):
                    requests.append(route.request.url)
                    # Controlled mapping: no request to the external example host.
                    response = viewer.request.get(origin+'/clips/'+digest+'.mp4', headers={k:v for k,v in route.request.headers.items() if k.lower() == 'range'})
                    assert response.status in (200,206)
                    route.fulfill(status=response.status,body=response.body(),headers={**response.headers,'access-control-allow-origin':origin})
                viewer.route('https://media.example.org/**', local_clip)
                page = viewer.new_page()
                page.goto(origin+'/')
                page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
                page.get_by_role('button', name='Load listing video',exact=True).wait_for()
                assert requests == []
                page.get_by_role('button', name='Load listing video',exact=True).click()
                page.get_by_role('button', name='Play listing video',exact=True).wait_for()
                assert requests and page.locator('video').evaluate('(v)=>v.paused')
                # Slow the one-second fixture for reliable screenshot observation.
                page.locator('video').evaluate('(v)=>v.playbackRate=0.25')
                page.get_by_role('button', name='Play listing video',exact=True).click()
                page.wait_for_function('document.querySelector("video").currentTime > 0.1')
                playback = page.locator('video').evaluate('(v)=>({time:v.currentTime,paused:v.paused,width:v.videoWidth,height:v.videoHeight})')
                assert not playback['paused'] and playback['width'] == 160
                page.screenshot(path=str(output/'viewer-playback.png'))
                page.get_by_role('button',name='Replay listing video',exact=True).wait_for(timeout=15000)
                page.get_by_role('button',name='Dismiss listing video',exact=True).click()
                page.get_by_role('button',name='Show listing video',exact=True).wait_for()
                result = {'browser':browser.version,'owner_upload':True,'viewer_write_rejected':True,'separate_contexts':True,'uploaded_sha256':digest,'playback':playback,'no_media_before_opt_in':True,'completion_and_dismiss':True,'external_requests':False,'scope':'local synthetic sessions; actual Flutter listing; HTTPS test-host interception to loopback'}
                (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
                print(json.dumps(result))
                browser.close()
        finally:
            server.should_exit = True
            thread.join(timeout=5)

if __name__ == '__main__':
    main()
