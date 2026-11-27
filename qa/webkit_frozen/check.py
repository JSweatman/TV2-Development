"""Synthetic-only frozen-build WebKit check. No contact actions or hosted API."""
import argparse,base64,functools,hashlib,json,re,threading
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from urllib.parse import urlsplit,parse_qs
from playwright.sync_api import sync_playwright,expect

def main():
 p=argparse.ArgumentParser();p.add_argument('--web',type=Path,required=True);p.add_argument('--mount',default='/');a=p.parse_args()
 class Static(SimpleHTTPRequestHandler):
  def log_message(self,*args):pass
  def translate_path(self,path):return str(a.web/urlsplit(path).path.removeprefix(a.mount))
 server=ThreadingHTTPServer(('127.0.0.1',0),Static);threading.Thread(target=server.serve_forever,daemon=True).start();origin=f'http://127.0.0.1:{server.server_port}'
 result={'mount':a.mount,'viewport':[390,844],'main_sha256':hashlib.sha256((a.web/'main.dart.js').read_bytes()).hexdigest(),'renderer':[],'api':[],'blocked_external':[],'errors':[]};page=None;browser=None
 listing=dict(country_code='1',list_number='529',tldx=None,display_name='Synthetic Workshop',entity_type='business',template_key='basic',resources=[],buttons=[])
 try:
  with sync_playwright() as pw:
   browser=pw.webkit.launch(headless=True);result['engine']='Playwright WebKit';result['version']=browser.version
   context=browser.new_context(viewport={'width':390,'height':844},service_workers='allow')
   def route(r):
    u=urlsplit(r.request.url)
    if u.netloc==urlsplit(origin).netloc:r.continue_();return
    if u.netloc=='tv2-development.onrender.com':
     q=parse_qs(u.query);n=q.get('input',[''])[0];result['api'].append(u.path+'?'+u.query)
     if u.path=='/v1/countries':data=[dict(iso2='US',country_name='Shared calling-code namespace',nid='1',default_language_tag='en')]
     elif u.path=='/v1/prefix':data=dict(country_context='1',input=n,has_more=False,matches=[dict(country_code='1',list_number='529',tldx=None,display_name='Synthetic Workshop',entity_type='business',qualified_input='1*529',exact=n in ['529','1*529'])])
     elif u.path=='/v1/resolve':data=dict(status='resolved',country_context='1',input=n,listing=listing)
     else:raise AssertionError('Unexpected API path')
     r.fulfill(status=200,content_type='application/json',body=json.dumps(data),headers={'access-control-allow-origin':'*'});return
    result['blocked_external'].append(r.request.url);r.abort()
   context.route('**/*',route)
   page=context.new_page();page.on('pageerror',lambda e:result['errors'].append(str(e)))
   def response(r):
    if '/canvaskit/' in r.url:result['renderer'].append({'url':r.url,'status':r.status,'mime':r.headers.get('content-type'),'bytes':len(r.body())})
   page.on('response',response)
   page.goto(origin+a.mount+'index.html');page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
   page.get_by_role('button',name=re.compile(r'^\+1\s')).wait_for();page.wait_for_timeout(500);capture(page,'picker',a.mount)
   page.get_by_role('button',name=re.compile(r'^\+1\s')).click()
   for digit in '529':page.get_by_role('button',name=digit,exact=True).click()
   page.get_by_text('Synthetic Workshop',exact=True).first.wait_for();page.wait_for_timeout(500);capture(page,'keypad',a.mount)
   page.get_by_role('button',name='ENTER',exact=True).click();page.get_by_role('button',name='Back',exact=True).wait_for();page.get_by_text('Synthetic Workshop',exact=True).first.wait_for();page.wait_for_timeout(500);capture(page,'listing',a.mount)
   for name,mime in [('canvaskit.js','javascript'),('canvaskit.wasm','application/wasm')]:
    found=[r for r in result['renderer'] if r['url']==origin+a.mount+'canvaskit/'+name];assert found and all(r['status']==200 and mime in r['mime'] for r in found),result['renderer']
   assert not any('/flutter-canvaskit/' in x for x in result['blocked_external'])
   assert any('/v1/resolve?' in x and ('input=529' in x or 'input=1%2A529' in x) for x in result['api'])
   assert not result['errors'],result['errors'];result['passed']=True
 except Exception as e:
  result['passed']=False;result['failure']=str(e)
  if page:
   try:capture(page,'failure',a.mount)
   except Exception:pass
  raise
 finally:
  print('WEBKIT_RESULT '+json.dumps(result),flush=True)
  if browser:
   try:browser.close()
   except Exception:pass
  server.shutdown();server.server_close()

def capture(page,label,mount):
 name=('root' if mount=='/' else 'app')+'-'+label
 data=page.screenshot();encoded=base64.b64encode(data).decode()
 print('PNG_BEGIN '+name+' '+hashlib.sha256(data).hexdigest(),flush=True)
 for i in range(0,len(encoded),2000):print('PNG_DATA '+encoded[i:i+2000],flush=True)
 print('PNG_END '+name,flush=True)

if __name__=='__main__':main()
