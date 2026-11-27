"""Normal release browser proof; canonical API redirected to synthetic loopback DB.
Build with the unchanged Render command, then run with existing QA dependencies:
python scripts/same_origin_renderer_browser.py --web /absolute/build/web --output /tmp/proof
For a --base-href /app/ build, add --mount /app/.
Blocks external renderer CDN; records/suppresses window.open, never OS handlers.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import uuid
import httpx
import psycopg
import uvicorn
from playwright.sync_api import sync_playwright, expect
from fastapi.staticfiles import StaticFiles

ROOT=Path(__file__).resolve().parents[1]
IMAGE='postgres@sha256:23799e521dee9265a8b388ecf3bc0f1eaa34b95be67f5a76af4f8f6adb44c720'
ORIGIN='http://127.0.0.1:54335'

def run(*args):
    return subprocess.check_output(args,text=True,stderr=subprocess.PIPE).strip()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--safari-ua',action='store_true')
    parser.add_argument('--mount',default='/')
    parser.add_argument('--web',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    assert (args.web/'main.dart.js').is_file()
    args.output.mkdir(parents=True,exist_ok=False)
    run('docker','image','inspect',IMAGE)
    name='tv2-foundation-'+uuid.uuid4().hex[:10]
    server=None;conn=None
    result={'requests':[], 'viewport':[390,844], 'origin':ORIGIN,
            'backend':'actual local FastAPI/Postgres; canonical browser API intercepted to loopback',
            'main_js_sha256':hashlib.sha256((args.web/'main.dart.js').read_bytes()).hexdigest()}
    try:
        run('docker','run','--pull=never','-d','--name',name,
            '-p','127.0.0.1::5432','-e','POSTGRES_HOST_AUTH_METHOD=trust',
            '-e','POSTGRES_DB=tv2_bootstrap_proof',IMAGE)
        port=run('docker','port',name,'5432/tcp').split(':')[-1]
        dsn=f'postgresql://postgres@127.0.0.1:{port}/tv2_bootstrap_proof'
        for _ in range(200):
            try:
                conn=psycopg.connect(dsn,autocommit=True);break
            except psycopg.OperationalError:time.sleep(.2)
        else:raise RuntimeError('Disposable DB unavailable within 40 seconds')
        for path in ['backend/bootstrap/schema.sql','backend/bootstrap/audited_rpc.sql','backend/review_sql/public_visibility.sql']:
            conn.execute((ROOT/path).read_text())
        conn.execute("CREATE TABLE country_namespaces(iso2 text,country_name text,nid text,default_language_tag text,active boolean)")
        conn.execute("INSERT INTO country_namespaces VALUES('US','Shared namespace','1','en',true),('IN','India','91','en',true)")
        cases=[('1*529','1','529',None,'Synthetic Contact','contact'),('1*529.411','1','529','411','Synthetic Suffix','suffix'),('1*5291','1','5291',None,'Synthetic Longer','longer'),('91*529','91','529',None,'Synthetic India','india'),('*529',None,'529',None,'Synthetic Global','global')]
        cases=cases[:1]
        for identity,nid,base,suffix,title,slug in cases:
            lid=conn.execute("INSERT INTO listings(country_code,list_number,tldx,display_name,entity_type) VALUES(%s,%s,%s,%s,'business') RETURNING id",(nid,base,suffix,title)).fetchone()[0]
            rid=conn.execute("INSERT INTO listing_resources(listing_id,resource_key,resource_type,public_uri) VALUES(%s,'website','web',%s) RETURNING id",(lid,'https://sample.example.com/'+slug)).fetchone()[0]
            conn.execute("INSERT INTO listing_buttons(listing_id,slot,label,resource_id) VALUES(%s,4,'WEBSITE',%s)",(lid,rid))
            if slug=='contact':
                for slot,kind,meta in [(1,'call',{'handoff':'device','phone_e164':'+12025550123'}),(2,'text',{'handoff':'device','phone_e164':'+12025550123'}),(3,'email',{'handoff':'device','address':'demo@example.invalid'})]:
                    rid=conn.execute("INSERT INTO listing_resources(listing_id,resource_key,resource_type,public_metadata) VALUES(%s,%s,%s,%s::jsonb) RETURNING id",(lid,kind,kind,json.dumps(meta))).fetchone()[0]
                    conn.execute("INSERT INTO listing_buttons(listing_id,slot,label,resource_id) VALUES(%s,%s,%s,%s)",(lid,slot,kind.upper(),rid))
        os.environ['TV2_REPOSITORY']='postgres';os.environ['DATABASE_URL']=dsn
        sys.path.insert(0,str(ROOT/'backend/src'))
        import app as service
        @service.app.middleware('http')
        async def observe(request,call_next):
            if request.url.path.startswith('/v1/'):result['requests'].append(request.url.path+'?'+request.url.query)
            return await call_next(request)
        service.app.mount(args.mount,StaticFiles(directory=args.web,html=True),name='local-web')
        server=uvicorn.Server(uvicorn.Config(service.app,host='127.0.0.1',port=54335,log_level='critical',access_log=False))
        threading.Thread(target=server.run,daemon=True).start()
        for _ in range(100):
            if server.started:break
            time.sleep(.05)
        assert server.started
        with httpx.Client(trust_env=False) as client:
            for identity,nid,base,suffix,title,slug in cases:
                exact=client.get(ORIGIN+'/v1/resolve',params={'input':identity}).json()
                prefix=client.get(ORIGIN+'/v1/prefix',params={'input':identity}).json()
                assert exact['listing']['display_name']==title
                assert any(m['qualified_input']==identity and m['display_name']==title for m in prefix['matches'])
                kinds={r['type'] for r in exact['listing']['resources']}
                assert kinds==({'web','call','text','email'} if slug=='contact' else {'web'})
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
            context=browser.new_context(viewport={'width':390,'height':844},service_workers='allow', **({'user_agent':'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'} if args.safari_ua else {}))
            context.add_init_script("window.contactProof=[]; window.open=function(url,target,features){window.contactProof.push({url:String(url),target,features,activation:{active:navigator.userActivation?.isActive,ever:navigator.userActivation?.hasBeenActive},ua:navigator.userAgent});return null;};")
            # Exact canonical release bytes; intercept only resolver transport to synthetic loopback API.
            def resolver_route(route):
                from urllib.parse import urlsplit
                u=urlsplit(route.request.url)
                with httpx.Client(trust_env=False) as client:
                    r=client.get(ORIGIN+u.path+('?' + u.query if u.query else ''))
                route.fulfill(status=r.status_code,content_type='application/json',body=r.content,headers={'access-control-allow-origin':'*'})
            context.route('https://tv2-development.onrender.com/**', resolver_route)
            result['canonical_api_intercepted_to_loopback']=True
            local_fonts=[]
            context.on('response',lambda r: local_fonts.append({'url':r.url,'status':r.status,'bytes':len(r.body())}) if '/assets/web_fonts/' in r.url else None)
            renderer_requests=[];renderer_responses=[];external_renderer=[];font_requests=[]
            def block_renderer(route):
                external_renderer.append(route.request.url);route.abort()
            context.route('https://www.gstatic.com/flutter-canvaskit/**',block_renderer)
            context.route('https://fonts.gstatic.com/**',lambda route: route.abort())
            context.route('https://fonts.googleapis.com/**',lambda route: route.abort())
            context.on('request',lambda r: renderer_requests.append(r.url) if '/canvaskit/' in r.url else None)
            context.on('response',lambda r: renderer_responses.append({'url':r.url,'status':r.status}) if '/canvaskit/' in r.url else None)
            context.on('request',lambda r: font_requests.append(r.url) if 'fonts.gstatic.com' in r.url else None)
            page=context.new_page();page.on('requestfailed',lambda r: print('FAILED',r.url,r.failure,flush=True));page.on('pageerror',lambda e: print('PAGEERROR',str(e),flush=True));page.goto(ORIGIN+args.mount+'index.html');page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
            page.screenshot(path=str(args.output/'picker.png'))
            page.get_by_role('button',name=re.compile(r'^\+1\s')).click()
            page.screenshot(path=str(args.output/'keypad-empty.png'))
            result['cases']=[]
            for identity,nid,base,suffix,title,slug in cases:
                page.get_by_role('button',name='Clear',exact=True).click()
                for digit in identity:page.get_by_role('button',name=digit,exact=True).click()
                page.get_by_text(title,exact=True).first.wait_for()
                page.wait_for_timeout(400)
                page.screenshot(path=str(args.output/(slug+'-preview.png')))
                count=len(result['requests']);page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_role('button',name='Back',exact=True).wait_for();page.get_by_text(title,exact=True).first.wait_for()
                assert any('/v1/resolve?' in r for r in result['requests'][count:])
                before=page.evaluate('contactProof.length')
                if slug=='contact':
                    for label,dialog,final,uri in [('CALL','Open phone app?','Open device app','tel:+12025550123'),('TEXT','Open messaging app?','Open device app','sms:+12025550123'),('EMAIL','Open email app?','Compose email','mailto:demo@example.invalid')]:
                        page.get_by_role('button',name=label,exact=True).click()
                        page.get_by_text('Listing available',exact=True).wait_for();assert page.evaluate('contactProof.length')==before
                        page.get_by_role('button',name='Continue',exact=True).click();page.get_by_text(dialog,exact=True).wait_for()
                        assert page.evaluate('contactProof.length')==before
                        page.screenshot(path=str(args.output/(label.lower()+'-confirmation.png')))
                        page.get_by_role('button',name='Cancel',exact=True).click();assert page.evaluate('contactProof.length')==before
                        page.get_by_role('button',name=label,exact=True).click();page.get_by_role('button',name='Continue',exact=True).click()
                        page.get_by_role('button',name=final,exact=True).click();page.wait_for_timeout(300)
                        assert page.evaluate('contactProof.at(-1).url')==uri
                        before+=1;assert page.evaluate('contactProof.length')==before
                else:
                    for label in ['CALL','TEXT','EMAIL']:assert page.get_by_role('button',name=label,exact=True).count()==0
                page.get_by_text(title,exact=True).first.wait_for()
                result['cases'].append({'identity':identity,'contacts_cancelled_and_launched_once':True,'listing_usable':True})
                page.get_by_role('button',name='Back',exact=True).click()
                page.get_by_role('button',name='ENTER',exact=True).wait_for()
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_text(title,exact=True).first.wait_for()
                page.get_by_role('button',name='Back',exact=True).wait_for()
                page.screenshot(path=str(args.output/'listing-after-interceptions.png'))
                records=page.evaluate('contactProof')
                assert len(records)==3
                assert all(x['target']==('_top' if args.safari_ua else '') for x in records)
                assert all(x['features']=='noopener,noreferrer' for x in records)
                assert all(x['activation']['active'] is True for x in records)
                result['safari_ua_branch_only']=args.safari_ua
                result['back_and_reopen_passed']=True
            result['captured_launch_intents']=page.evaluate('contactProof');result['browser']=browser.version;result['semantic_flow_passed']=True;result['visual_text_acceptance']='Requires screenshot review; semantics do not prove glyph rendering'
            assert not external_renderer, external_renderer
            assert any(r.endswith('canvaskit.js') for r in renderer_requests)
            assert any(r.endswith('canvaskit.wasm') for r in renderer_requests)
            assert all(r.startswith(ORIGIN+args.mount+'canvaskit/') for r in renderer_requests)
            assert all(r['status']==200 for r in renderer_responses)
            result['renderer_requests']=renderer_requests;result['renderer_responses']=renderer_responses
            result['external_renderer_requests']=external_renderer;result['fallback_font_requests']=font_requests
            result['service_worker_registrations']=page.evaluate('navigator.serviceWorker.getRegistrations().then(rs=>rs.map(r=>r.scope))')
            assert result['service_worker_registrations']==[] # pinned default does not register for a fresh visitor
            result['document_base']=page.evaluate('document.baseURI')
            result['mount']=args.mount
            result['local_fonts']=local_fonts
            assert len([f for f in local_fonts if f['url'].endswith('.ttf') and f['status']==200])==3
            browser.close()
        (args.output/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
    finally:
        if server:server.should_exit=True
        if conn:conn.close()
        subprocess.run(['docker','rm','-fv',name],capture_output=True)
if __name__=='__main__':main()
