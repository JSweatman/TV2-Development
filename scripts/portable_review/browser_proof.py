"""Verify extracted portable package with existing isolated local TLS harness."""
import base64, hashlib, json, re, ssl, subprocess, sys, tempfile, threading
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright
from readonly_host import handler_for
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from backend.local_media_demo.landscape_checks import verify_landscape

root, output=map(Path,sys.argv[1:3]);output.mkdir(parents=True,exist_ok=True)
origin='https://tv2-portable.example.org'
with tempfile.TemporaryDirectory() as directory:
    d=Path(directory);cert=d/'cert.pem';key=d/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
        '-keyout',str(key),'-out',str(cert),'-subj','/CN=tv2-portable.example.org',
        '-addext','subjectAltName=DNS:tv2-portable.example.org'],check=True,capture_output=True)
    public=subprocess.run(['openssl','x509','-in',str(cert),'-pubkey','-noout'],check=True,capture_output=True).stdout
    der=subprocess.run(['openssl','pkey','-pubin','-outform','DER'],input=public,check=True,capture_output=True).stdout
    pin=base64.b64encode(hashlib.sha256(der).digest()).decode()
    server=ThreadingHTTPServer(('127.0.0.1',443),handler_for(root))
    tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.load_cert_chain(cert,key)
    server.socket=tls.wrap_socket(server.socket,server_side=True)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    try:
      with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=[
          '--no-sandbox','--no-proxy-server','--host-resolver-rules=MAP tv2-portable.example.org 127.0.0.1',
          '--ignore-certificate-errors-spki-list='+pin])
        context=browser.new_context(viewport={'width':390,'height':844})
        requests=[];context.on('request',lambda r:requests.append(r.url))
        page=context.new_page();page.goto(origin+'/')
        assert page.get_by_text('Private review • sample data only.',exact=True).is_visible()
        page.get_by_role('link',name='Open List Number TV2').click()
        page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
        page.get_by_role('button',name='+1 Shared calling-code namespace',exact=True).click()
        def digits(number):
          for digit in number:
            page.get_by_role('button',name=re.compile(r'^0(?:\s|$)') if digit=='0' else digit,exact=digit!='0').click()
        digits('700001')
        page.get_by_role('button',name='ENTER',exact=True).click()
        page.get_by_role('button',name='Load listing video',exact=True).wait_for()
        assert not any('/media/' in u for u in requests)
        page.get_by_role('button',name='Load listing video',exact=True).click()
        page.get_by_role('button',name='Play listing video',exact=True).wait_for()
        assert page.locator('video').evaluate('(v)=>v.paused && v.currentTime===0')
        page.get_by_role('button',name='Play listing video',exact=True).click()
        page.wait_for_function('document.querySelector("video").currentTime>0.1')
        rotation=verify_landscape(page,output)
        page.get_by_role('button',name='Replay listing video',exact=True).wait_for(timeout=25000)
        page.mouse.wheel(0,500)
        with page.expect_popup() as popup:
          page.get_by_role('button',name='WEBSITE',exact=True).click()
        destination=popup.value;destination.wait_for_url(origin+'/sample-website.html')
        assert destination.get_by_role('heading',name='Northstar Workshop').is_visible()
        assert destination.get_by_text('Bring closed-toe shoes and a water bottle.',exact=True).is_visible()
        assert destination.get_by_text('We supply the wood, tools and eye protection.',exact=True).is_visible()
        assert destination.get_by_role('heading',name='Words from the video',exact=True).is_visible()
        assert destination.locator('form,input,iframe').count()==0
        assert destination.locator('a').evaluate_all("links=>links.every(a=>a.origin===location.origin)")
        assert destination.get_by_role('heading',name="Alex's notebook").count()==0
        destination.close();page.bring_to_front()
        page.get_by_role('button',name='Back',exact=True).click()
        page.get_by_role('button',name='ENTER',exact=True).wait_for()
        assert '700001' in page.locator('body').inner_text()
        page.get_by_role('button',name='Clear',exact=True).click();digits('700001')
        page.mouse.move(195,400);page.mouse.wheel(0,-1500);page.wait_for_timeout(300)
        page.get_by_role('button',name=re.compile('Northstar')).click()
        page.wait_for_function("document.body.innerText.includes('1*700001')")
        assert page.get_by_role('button',name='Load listing video',exact=True).count()==0
        page.get_by_role('button',name='ENTER',exact=True).click()
        page.get_by_role('button',name='Load listing video',exact=True).wait_for()
        page.get_by_role('button',name='Back',exact=True).click()
        page.get_by_role('button',name='Clear',exact=True).click();digits('70002')
        page.get_by_role('button',name='ENTER',exact=True).click()
        page.get_by_text('Alex (sample)',exact=True).wait_for()
        assert page.get_by_role('button',name='Load listing video',exact=True).count()==0
        page.screenshot(path=str(output/'personal.png'))
        with page.expect_popup() as personal_popup:
          page.get_by_role('button',name='WEBSITE',exact=True).click()
        personal_destination=personal_popup.value
        personal_destination.wait_for_url(origin+'/alex.html')
        assert personal_destination.get_by_role('heading',name="Alex's notebook",exact=True).is_visible()
        assert personal_destination.get_by_role('heading',name='Northstar Workshop').count()==0
        assert personal_destination.locator('form,input,iframe,video').count()==0
        assert personal_destination.locator('a').evaluate_all("links=>links.every(a=>a.origin===location.origin)")
        personal_destination.get_by_role('link',name='Small projects',exact=True).click()
        personal_destination.wait_for_url(origin+'/alex.html#projects')
        assert personal_destination.get_by_role('heading',name='Small projects',exact=True).is_visible()
        personal_destination.screenshot(path=str(output/'alex-page.png'))
        personal_destination.close();page.bring_to_front()
        page.get_by_text('Alex (sample)',exact=True).wait_for()
        assert '1*70002' in page.locator('body').inner_text()
        page.get_by_role('button',name='Back',exact=True).click()
        page.get_by_role('button',name='ENTER',exact=True).wait_for()
        assert '70002' in page.locator('body').inner_text()
        # Refresh keeps country; all navigation can start again without an account.
        page.reload();page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
        page.get_by_role('button',name='+1',exact=True).wait_for()
        digits('999999');page.get_by_role('button',name='ENTER',exact=True).click()
        page.get_by_text('No exact match. ENTER retries.',exact=True).wait_for()
        # HTTP-level proof: range, read-only methods, no API/lab routes or CORS.
        statuses=page.evaluate('''async()=>{let out={};for(const [path,method] of [['/','GET'],['/media/sample.mp4','HEAD'],['/owner','GET'],['/v1/resolve','GET'],['/media/sample.mp4','PUT'],['/','POST']]){let r=await fetch(path,{method});out[path+':'+method]=r.status;if(r.headers.get('access-control-allow-origin'))throw Error('Unexpected CORS');if(r.headers.get('cache-control')!=='no-store')throw Error('Missing no-store');}let r=await fetch('/media/sample.mp4',{headers:{Range:'bytes=0-15'}});out.range={status:r.status,range:r.headers.get('content-range'),bytes:(await r.arrayBuffer()).byteLength};return out;}''')
        assert statuses['/owner:GET']==404 and statuses['/v1/resolve:GET']==404
        assert statuses['/:POST']==405 and statuses['/media/sample.mp4:PUT']==405
        assert statuses['range']['status']==206 and statuses['range']['bytes']==16
        assert all(urlsplit(u).netloc=='tv2-portable.example.org' for u in requests if u.startswith('http'))
        # HTTP guard fails closed without issuing media/resolver requests.
        insecure=ThreadingHTTPServer(('127.0.0.1',0),handler_for(root))
        insecure_thread=threading.Thread(target=insecure.serve_forever,daemon=True);insecure_thread.start()
        try:
          blocked=context.new_page();blocked_requests=[]
          blocked.on('request',lambda r:blocked_requests.append(r.url))
          blocked.goto(f'http://127.0.0.1:{insecure.server_port}/app/')
          blocked.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
          blocked.get_by_text('Private sample review requires an approved HTTPS host.',exact=True).wait_for()
          assert not any('/media/' in u or '/v1/' in u for u in blocked_requests)
          blocked.close()
        finally:
          insecure.shutdown();insecure.server_close();insecure_thread.join()
        result={'browser':browser.version,'package_root':root.name,'viewport':[390,844],
          'guide_to_app':True,'account_free':True,'immediate_enter':True,'fill_only_selection':True,
          'website_popup_return':True,'concrete_bring_answer':True,'accessible_transcript':True,'distinct_personal_destination':True,'personal_links_and_return':True,'country_retained_on_refresh':True,'unknown_retry':True,
          'rotation':rotation,'http':statuses,'all_requests_same_origin':True,'no_autoplay':True,
          'no_media_before_opt_in':True,'no_request_interception':True,'http_guard_blocks_app':True}
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));browser.close()
    finally:
      server.shutdown();server.server_close();thread.join()
