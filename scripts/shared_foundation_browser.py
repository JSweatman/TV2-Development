"""Disposable Postgres -> real FastAPI -> normal Flutter web acceptance.
Run with existing backend + Playwright dependencies and system Chromium:
python scripts/shared_foundation_browser.py --web /absolute/build/web --output /tmp/new-evidence
Use main.dart built with TV2_LOCAL_FIXTURE=true and TV2_API_BASE_URL=http://127.0.0.1:54335.
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
    parser.add_argument('--web',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    assert (args.web/'main.dart.js').is_file()
    args.output.mkdir(parents=True,exist_ok=False)
    run('docker','image','inspect',IMAGE)
    name='tv2-foundation-'+uuid.uuid4().hex[:10]
    server=None;conn=None
    result={'requests':[], 'viewport':[390,844], 'origin':ORIGIN,
            'backend':'actual FastAPI PostgresResolverRepository; no interception',
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
        conn.execute("""CREATE TABLE country_namespaces(iso2 text,country_name text,nid text,default_language_tag text,active boolean);
        INSERT INTO country_namespaces VALUES('US','Shared calling-code namespace','1','en',true),('IN','India','91','en',true);
        INSERT INTO listings(country_code,list_number,display_name,entity_type,visibility) VALUES
        ('1','529','Synthetic One','business','public'),('91','529','Synthetic India','business','public'),
        ('1','700001','Hidden Private','business','private'),('1','700002','Hidden Restricted','business','restricted'),
        ('1','700003','Hidden Invitation','business','invitation_only'),('1','700004','Expired Sample','business','public'),
        ('1','700005','Active Sample','business','public');
        UPDATE listings SET expires_at=statement_timestamp()-interval '1 second' WHERE list_number='700004';
        INSERT INTO listing_resources(listing_id,resource_key,resource_type,public_uri)
        SELECT id,'web','web','https://hidden.example/destination' FROM listings WHERE visibility<>'public';""")
        try:
            conn.execute("INSERT INTO listings(country_code,list_number,display_name,entity_type) VALUES('1','529','Duplicate','business')")
        except psycopg.errors.UniqueViolation:result['whole_number_duplicate_rejected']=True
        else:raise AssertionError('Duplicate accepted')
        os.environ['TV2_REPOSITORY']='postgres';os.environ['DATABASE_URL']=dsn
        sys.path.insert(0,str(ROOT/'backend/src'))
        import app as service
        @service.app.middleware('http')
        async def observe(request,call_next):
            if request.url.path.startswith('/v1/'):
                result['requests'].append(request.url.path+'?'+request.url.query)
            return await call_next(request)
        service.app.mount('/',StaticFiles(directory=args.web,html=True),name='local-web')
        server=uvicorn.Server(uvicorn.Config(service.app,host='127.0.0.1',port=54335,log_level='critical',access_log=False))
        thread=threading.Thread(target=server.run,daemon=True);thread.start()
        for _ in range(100):
            if server.started:break
            time.sleep(.05)
        assert server.started
        with httpx.Client(trust_env=False) as client:
            checks=[]
            for number in ['700001','700002','700003','700004','700005']:
                exact=client.get(ORIGIN+'/v1/resolve',params={'input':number,'country':'1'})
                prefix=client.get(ORIGIN+'/v1/prefix',params={'input':number,'country':'1'})
                assert exact.status_code==prefix.status_code==200
                visible=number=='700005'
                assert (exact.json()['status']=='resolved')==visible
                assert bool(prefix.json()['matches'])==visible
                if not visible:assert 'Hidden' not in exact.text+prefix.text and 'hidden.example' not in exact.text+prefix.text
                checks.append({'number':number,'visible':visible})
            # Changing the existing public row to private is effective at the next request.
            conn.execute("UPDATE listings SET visibility='private' WHERE list_number='700005'")
            for path in ['resolve','prefix']:
                reply=client.get(ORIGIN+'/v1/'+path,params={'input':'700005','country':'1'})
                assert 'Active Sample' not in reply.text
            result['immediate_visibility_change']=True
            conn.execute("UPDATE listings SET visibility='public' WHERE list_number='700005'")
            result['api_visibility_and_time']=checks
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
            context=browser.new_context(viewport={'width':390,'height':844},service_workers='block')
            page=context.new_page();page.goto(ORIGIN+'/index.html')
            page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
            page.get_by_role('button',name=re.compile(r'^\+1\s')).click()
            def type_number(value):
                for digit in value:
                    key = page.get_by_role('button',name=re.compile(r'^0(?:\s|$)')) if digit=='0' else page.get_by_role('button',name=digit,exact=True)
                    key.click()
            def open_listing(label,identity,filename):
                page.get_by_text(label,exact=True).first.wait_for()
                page.get_by_role('button',name='ENTER',exact=True).click()
                page.get_by_role('button',name='Back',exact=True).wait_for()
                assert identity in page.locator('body').inner_text()
                page.screenshot(path=str(args.output/filename))
                page.get_by_role('button',name='Back',exact=True).click()
            type_number('529');open_listing('Synthetic One','1*529','01-one.png')
            page.get_by_text('+1',exact=True).click();page.get_by_role('button',name=re.compile('^India')).click()
            open_listing('Synthetic India','91*529','02-india.png')
            page.get_by_text('IN  +91',exact=True).click();page.get_by_role('button',name=re.compile(r'^\+1\s')).click()
            for number in ['700001','700002','700003','700004']:
                page.get_by_role('button',name='Clear',exact=True).click()
                with page.expect_response(lambda r: '/v1/prefix?' in r.url and 'input='+number+'&' in r.url) as reply:
                    type_number(number)
                assert reply.value.json()['matches']==[]
                expect(page.get_by_role('button',name='ENTER',exact=True)).to_be_disabled()
                assert not page.get_by_role('button',name='ENTER',exact=True).is_enabled()
                assert 'Hidden' not in page.locator('body').inner_text()
            page.screenshot(path=str(args.output/'03-expired-blocked.png'))
            page.get_by_role('button',name='Clear',exact=True).click();type_number('700005')
            open_listing('Active Sample','1*700005','04-active.png')
            result.update(browser=browser.version,normal_entrypoint=True,browser_pass=True)
            browser.close()
        (args.output/'result.json').write_text(json.dumps(result,indent=2))
        print('PASS real normal-entrypoint browser -> FastAPI -> rebuilt Postgres; evidence saved')
    finally:
        if server:server.should_exit=True
        if conn:conn.close()
        subprocess.run(['docker','rm','-fv',name],capture_output=True)

if __name__=='__main__':main()
