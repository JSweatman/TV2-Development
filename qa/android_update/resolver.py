import json,time,threading,functools,re
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from urllib.parse import urlsplit,parse_qs
ROOT=Path('.');NAME='Sample Update'
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  u=urlsplit(self.path);q=parse_qs(u.query);inp=q.get('input',[''])[0]
  listing=dict(country_code='81',list_number='529',tldx=None,display_name=NAME,entity_type='business',template_key='basic',resources=[],buttons=[])
  if u.path=='/v1/countries': data=[dict(iso2='JP',country_name='Japan',nid='81',default_language_tag='ja')]
  elif u.path=='/v1/prefix': data=dict(country_context='81',input=inp,has_more=False,matches=[dict(**{k:listing[k] for k in ['country_code','list_number','tldx','display_name','entity_type']},qualified_input='81*529',exact=inp in ['529','81*529'])] if '529'.startswith(inp) or inp=='81*529' else [])
  elif u.path=='/v1/resolve': data=dict(status='resolved' if inp in ['529','81*529'] else 'not_found',country_context='81',input=inp,listing=listing if inp in ['529','81*529'] else None)
  else:return super().do_GET()
  b=json.dumps(data,ensure_ascii=False).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)

ThreadingHTTPServer(('127.0.0.1',54335),Handler).serve_forever()
