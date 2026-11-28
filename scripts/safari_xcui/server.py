import json,sys
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from urllib.parse import urlsplit,parse_qs
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=sys.argv[1],**kw)
 def do_GET(self):
  u=urlsplit(self.path);n=parse_qs(u.query).get('input',[''])[0]
  if u.path=='/health':
   body=b'<html><body><h1>TV2 LOOPBACK HEALTH B42077A</h1><a href="/">Open synthetic TV2</a></body></html>';kind='text/html'
  elif u.path.startswith('/v1/'):
   listing=dict(country_code='1',list_number='529',tldx=None,display_name='Sample Cedar Workshop',entity_type='business',template_key='basic',resources=[],buttons=[])
   if u.path=='/v1/countries':data=[dict(iso2='US',country_name='Shared calling-code namespace',nid='1',default_language_tag='en')]
   elif u.path=='/v1/prefix':data=dict(input=n,country_context='1',has_more=False,matches=[dict(listing,qualified_input='1*529',exact=n in ['529','1*529'])] if '529'.startswith(n) or n=='1*529' else [])
   elif u.path=='/v1/resolve':data=dict(input=n,country_context='1',status='resolved' if n in ['529','1*529'] else 'not_found',listing=listing if n in ['529','1*529'] else None)
   else:self.send_error(404);return
   body=json.dumps(data).encode();kind='application/json'
  else:return super().do_GET()
  self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
ThreadingHTTPServer(('127.0.0.1',8765),Handler).serve_forever()
