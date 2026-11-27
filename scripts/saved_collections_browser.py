"""Sequential same-origin saved-collection regression, synthetic API interception only.
Run with existing Playwright and Chromium, no dependency installation required:
python scripts/saved_collections_browser.py --web TV2_flutter/build/web --out /tmp/collections
This uses normal main.dart. No API request leaves the test browser. Each case has
fresh storage; tabs within a case share that storage. Not an overlapping-write test.
"""
import argparse, functools, hashlib, json, re, threading
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlsplit, parse_qs
from playwright.sync_api import sync_playwright
p=argparse.ArgumentParser();p.add_argument('--web',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
class Static(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Static,directory=str(a.web)));threading.Thread(target=server.serve_forever,daemon=True).start();origin=f'http://127.0.0.1:{server.server_port}'
result={'origin':origin,'main_sha256':hashlib.sha256((a.web/'main.dart.js').read_bytes()).hexdigest(),'cases':[],'api':[]}
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);result['browser']=browser.version
  for mode in ['single','sequential','withdrawal']:
   ctx=browser.new_context(viewport={'width':390,'height':844},service_workers='block');unavailable=set()
   def route(r):
    u=urlsplit(r.request.url)
    if u.netloc==urlsplit(origin).netloc:r.continue_();return
    if u.netloc!='tv2-development.onrender.com':r.abort();return
    q=parse_qs(u.query);n=q.get('input',[''])[0];base=n.split('*')[-1];result['api'].append([mode,u.path,n])
    title={'529':'Fictional Cedar','530':'Fictional Maple'}.get(base)
    if u.path=='/v1/countries':data=[dict(iso2='US',country_name='Shared calling-code namespace',nid='1',default_language_tag='en')]
    elif u.path=='/v1/prefix':data=dict(country_context='1',input=n,has_more=False,matches=[])
    elif u.path=='/v1/resolve':data=dict(status='resolved' if title and base not in unavailable else 'not_found',country_context='1',input=n,listing=dict(country_code='1',list_number=base,tldx=None,display_name=title,entity_type='business',template_key='basic',resources=[],buttons=[]) if title and base not in unavailable else None)
    else:raise AssertionError(u.path)
    r.fulfill(status=200,content_type='application/json',body=json.dumps(data),headers={'access-control-allow-origin':'*'})
   ctx.route('**/*',route)
   def launch():
    page=ctx.new_page();page.set_default_timeout(12000);page.goto(origin);page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()');page.wait_for_timeout(700)
    choose=page.get_by_role('button',name=re.compile(r'^\+1\s'))
    if choose.count():choose.click()
    page.get_by_role('button',name='HOME',exact=True).click();page.wait_for_timeout(500);page.get_by_text(re.compile('^Bookmarks')).click();page.wait_for_timeout(500)
    print('initialized collection',mode,flush=True)
    page.get_by_role('button',name=re.compile('^Back')).click();page.wait_for_timeout(500);page.get_by_role('button',name=re.compile('^Back')).click();page.wait_for_timeout(350);return page
   def lookup(page,n):
    page.bring_to_front();page.wait_for_timeout(400)
    # clear is toolbar trash; use known accessibility label from actual app
    for d in n:page.get_by_role('button',name=re.compile('^0') if d=='0' else d,exact=d!='0').click()
    page.get_by_role('button',name='ENTER',exact=True).click();page.get_by_role('button',name='Save listing',exact=True).wait_for();page.wait_for_timeout(700)
   def save(page,folder,alias=None,contact=False):
    page.bring_to_front();page.wait_for_timeout(400)
    page.get_by_role('button',name='Add to Address Book' if contact else 'Save listing',exact=True).click();page.wait_for_timeout(500)
    page.get_by_role('textbox',name='Custom listing name (optional)').wait_for()
    if page.get_by_label('Create new folder',exact=True).count():page.get_by_label('Create new folder',exact=True).click();page.wait_for_timeout(300)
    if alias:
     field=page.get_by_role('textbox',name='Custom listing name (optional)');field.click();page.wait_for_timeout(250);field.press_sequentially(alias,delay=15)
    field=page.get_by_role('textbox',name='New folder name');field.click();page.wait_for_timeout(250);field.press_sequentially(folder,delay=15)
    page.get_by_role('button',name='Save',exact=True).click();page.get_by_text('Contact saved to your Address Book.' if contact else 'Listing saved to your device.',exact=True).wait_for();page.wait_for_timeout(250)
   def storage(page):return page.evaluate("(()=>{let d=JSON.parse(localStorage.getItem('flutter.tv2_saved_collections_v1'));return typeof d==='string'?JSON.parse(d):d})()")
   A=launch()
   if mode=='withdrawal':
    lookup(A,'529');save(A,'Woodshops','My Cedar');save(A,'People','Cedar friend',True);A.get_by_role('button',name=re.compile('^Back')).click();A.wait_for_timeout(350)
    # clear current digits using BACK, no storage injection
    A.get_by_role('button',name='Clear',exact=True).click()
   B=launch() if mode!='single' else A
   lookup(A,'530' if mode=='withdrawal' else '529');save(A,'Other' if mode=='withdrawal' else 'Cedar folder')
   if mode=='single':
    A.get_by_role('button',name=re.compile('^Back')).click();A.wait_for_timeout(350)
    A.get_by_role('button',name='Clear',exact=True).click()
   if mode!='withdrawal':lookup(B,'530');save(B,'Maple folder')
   else:
    B.bring_to_front();B.wait_for_timeout(400);unavailable.add('529')
    for d in '529':B.get_by_role('button',name=re.compile('^0') if d=='0' else d,exact=d!='0').click()
    B.get_by_role('button',name='ENTER',exact=True).click();B.wait_for_timeout(800)
   C=launch();data=storage(C);case={'mode':mode,'storage':data};result['cases'].append(case)
   C.get_by_role('button',name='HOME',exact=True).click();C.wait_for_timeout(500);C.get_by_text(re.compile('^Bookmarks')).click();C.wait_for_timeout(300)
   for folder in data['folders']:
    if folder.get('kind','bookmarks')=='bookmarks':C.get_by_text(re.compile('^'+re.escape(folder['label']))).click()
   C.screenshot(path=str(a.out/(mode+'.png')));case['visible']=C.locator('flt-semantics-host').aria_snapshot()
   ids={r['qualified_identity'] for r in data['bookmarks']};case['unrelated_retained']='1*530' in ids;case['seed_retained']='1*529' in ids
   if mode=='withdrawal':case['titles_cleared']=all(r['owner_title']=='' for r in data['bookmarks'] if r['qualified_identity']=='1*529')
   print(json.dumps(case),flush=True);ctx.close()
  browser.close()
except Exception:
 try: print(page.locator('flt-semantics-host').inner_text(),flush=True)
 except Exception: pass
 raise
finally:
 (a.out/'result.json').write_text(json.dumps(result,indent=2));server.shutdown()

if len(result['cases']) != 3:
 raise AssertionError('Incomplete browser cases')
for case in result['cases']:
 assert case['unrelated_retained'] and case['seed_retained'], case
 if case['mode']=='withdrawal':
  assert case['titles_cleared'], case
  rows=[r for r in case['storage']['bookmarks'] if r['qualified_identity']=='1*529']
  assert {r['alias'] for r in rows}=={'My Cedar','Cedar friend'}, rows
  assert {f['label'] for f in case['storage']['folders']}=={'Woodshops','People','Other'}
