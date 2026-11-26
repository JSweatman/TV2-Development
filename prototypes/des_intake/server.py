"""Loopback/managed-preview-only synthetic intake. Never import into the release app."""
import argparse, json, os, re, sqlite3, sys, tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend/src'))
from identity_rules import parse_identity, InvalidIdentity
FIELDS = ('number','name','plan','rta','website','phone','text','video','social1','social2','social3','social4','ack','simulated_approval')
PHONES = ('+12025550101', '+12025550102')
class Intake:
    def __init__(self, path):
        self.path = path
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS intake(identity TEXT PRIMARY KEY, number TEXT NOT NULL, state TEXT NOT NULL, payload TEXT NOT NULL)')
            for number,state in [('1*700001','draft'),('1*700002','expired')]:
                db.execute('INSERT OR IGNORE INTO intake VALUES(?,?,?,?)',(self.key(number),number,state,'{}'))
    def connect(self): return sqlite3.connect(self.path, timeout=5)
    @staticmethod
    def key(number):
        if not isinstance(number,str) or '*' not in number: raise ValueError('Use the complete qualified number, such as 1*700003.')
        i=parse_identity(number.strip())
        return json.dumps([i.country_code,i.base,i.tldx],separators=(',',':'))
    def validate(self,data, final=False):
        errors={}
        if not isinstance(data,dict) or set(data)-set(FIELDS): return {'form':'Only the listed synthetic fields are accepted. Never submit a real PIN.'}
        try:
            key=self.key(data.get('number',''))
            with self.connect() as db:
                if db.execute('SELECT 1 FROM intake WHERE identity=?',(key,)).fetchone(): errors['number']='Occupied identity, including draft or expired records. Choose another complete number.'
        except (ValueError,InvalidIdentity): errors['number']='Enter a valid complete qualified List Number.'
        name=data.get('name','')
        if not isinstance(name,str) or not re.fullmatch(r'Sample [A-Za-z ]{2,45}',name): errors['name']='Use a fictional name beginning with Sample (letters and spaces only).'
        if data.get('plan') not in ('business','10E'): errors['plan']='Choose a sample listing type.'
        if data.get('rta') not in ('Y','N'): errors['rta']='Choose Yes or No.'
        if data.get('plan')=='10E' and data.get('rta')=='Y': errors['rta']='RTA Yes is unavailable for 10E / free in this simulation.'
        if data.get('rta')=='N' and data.get('ack') is not True: errors['ack']='Acknowledge the draft RTA No notice before saving.'
        if data.get('phone') not in PHONES: errors['phone']='Select a reserved synthetic registration phone.'
        if data.get('text','') not in ('',)+PHONES: errors['text']='Use a reserved synthetic text number or leave blank.'
        for field in ('website','video','social1','social2','social3','social4'):
            value=data.get(field,'')
            try:
                if not isinstance(value,str) or len(value)>200: raise ValueError()
                u=urlsplit(value)
                if value and (u.scheme!='https' or u.hostname!='example.test' or u.netloc!='example.test' or u.query or u.fragment or any(ord(c)<33 for c in value)): raise ValueError()
                if field=='website' and not value: raise ValueError()
            except ValueError: errors[field]='Use https://example.test/path only. No fetch or playback occurs.'
        if final and data.get('simulated_approval') is not True: errors['form']='Complete the simulated approval challenge. This is not authentication.'
        return errors
    def save(self,data):
        errors=self.validate(data,True)
        if errors:return 422,{'errors':errors}
        payload={k:v for k,v in data.items() if k!='simulated_approval'}
        try:
            with self.connect() as db:
                db.execute('INSERT INTO intake VALUES(?,?,?,?)',(self.key(data['number']),data['number'].strip(),'phone_verification_required',json.dumps(payload)))
        except sqlite3.IntegrityError:return 409,{'errors':{'number':'Another save reserved this identity. Nothing was replaced.'}}
        return 201,{'state':'phone_verification_required','phone_assessment':{'possession':'unverified','classification_fixture':'unknown' if data['phone']==PHONES[0] else 'unavailable','account_eligibility':'pending','grants_10e':False,'activates_listing':False},'message':'Synthetic draft saved. Phone verification and owner permission remain unverified. Nothing is published.'}
    def rows(self):
        with self.connect() as db:return [dict(number=n,state=s,name=json.loads(p).get('name','Reserved fixture')) for n,s,p in db.execute('SELECT number,state,payload FROM intake ORDER BY number')]

def make_server(path,port):
    store=Intake(path)
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def send(self,status,body,kind='application/json'):
            raw=body.encode() if isinstance(body,str) else json.dumps(body).encode()
            self.send_response(status);self.send_header('Content-Type',kind);self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(raw)))
            self.send_header('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'none'; media-src 'none'; frame-src 'none'; form-action 'none'; frame-ancestors 'none'")
            self.end_headers();self.wfile.write(raw)
        def do_GET(self):
            if self.path=='/api/rows': return self.send(200,store.rows())
            files={'/':('index.html','text/html'),'/app.js':('app.js','text/javascript'),'/style.css':('style.css','text/css')}
            if self.path not in files:return self.send(404,{'error':'Unavailable in synthetic preview.'})
            filename,kind=files[self.path];self.send(200,(Path(__file__).parent/'web'/filename).read_text(),kind)
        def do_POST(self):
            # No CORS; reject cross-origin browser submissions, including form posts.
            if self.headers.get('Origin') and self.headers['Origin'] not in ('http://'+self.headers.get('Host',''),'https://'+self.headers.get('Host','')):return self.send(403,{'errors':{'form':'Cross-origin request denied.'}})
            if self.headers.get('Content-Type')!='application/json':return self.send(415,{'errors':{'form':'JSON required.'}})
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=8192:raise ValueError()
                data=json.loads(self.rfile.read(length))
                if not isinstance(data,dict):raise ValueError()
            except (ValueError,json.JSONDecodeError):return self.send(400,{'errors':{'form':'Invalid synthetic intake.'}})
            if self.path=='/api/validate':return self.send(200,{'errors':store.validate(data)})
            if self.path=='/api/save':return self.send(*store.save(data))
            self.send(404,{'error':'No publishing or verification endpoint exists.'})
    return ThreadingHTTPServer(('127.0.0.1',port),Handler)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--host',choices=['127.0.0.1'],default='127.0.0.1');p.add_argument('--strictPort',action='store_true');p.add_argument('--port',type=int,default=int(os.environ.get('PORT','5173')));p.add_argument('--db',default=None);a=p.parse_args()
    # Default is isolated ephemeral state; an explicit path supports controlled restart tests.
    with tempfile.TemporaryDirectory(prefix='des-synthetic-') as temp:make_server(a.db or str(Path(temp)/'intake.sqlite'),a.port).serve_forever()
