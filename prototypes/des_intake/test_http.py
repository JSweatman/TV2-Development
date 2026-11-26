"""Real loopback HTTP contract tests, not a browser/preview relay substitute."""
import json
import threading
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import pytest
from server import make_server
from test_intake import row

@pytest.fixture
def http(tmp_path):
    path=tmp_path/'synthetic.sqlite'
    server=make_server(str(path),0)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    origin=f'http://127.0.0.1:{server.server_port}'
    def request(route, data=None, headers=None, raw=None):
        body=raw if raw is not None else None if data is None else json.dumps(data).encode()
        h={'Content-Type':'application/json','Origin':origin};h.update(headers or {})
        req=Request(origin+route,data=body,headers=h)
        try:r=urlopen(req,timeout=3)
        except HTTPError as e:r=e
        with r:return r.status,dict(r.headers),r.read()
    yield request,path
    server.shutdown();server.server_close();thread.join(timeout=3)

def test_entrypoint_csp_and_local_assets(http):
    request,_=http
    status,headers,body=request('/')
    assert status==200 and 'text/html' in headers['Content-Type']
    html=body.decode()
    for marker in ('id="sheet"','id="fields"','Synthetic only','type="password"','never sent or saved'):
        assert marker in html
    csp=headers['Content-Security-Policy']
    for rule in ("connect-src 'self'","media-src 'none'","frame-src 'none'","form-action 'none'","frame-ancestors 'none'"):assert rule in csp
    assert headers['Cache-Control']=='no-store'
    assert request('/app.js')[0]==request('/style.css')[0]==200
    script=request('/app.js')[2].decode()
    assert "el('pin').value=''" in script
    assert "['pin'" not in script and 'localStorage' not in script
    for url in ('/api/rows','/api/validate','/api/save'):assert url in script
    assert request('/api/publish',{})[0]==404
    assert request('/server.py')[0]==404

def test_actual_http_states_and_persistence(http,capsys):
    request,path=http
    for number in ('1*700001','1*700002'):
        code,_,body=request('/api/validate',row(number))
        assert code==200 and 'number' in json.loads(body)['errors']
    for changes,key in (({'plan':'10E','rta':'Y'},'rta'),({'ack':False},'ack'),({'phone':'+44123456789'},'phone'),({'simulated_approval':False},'form')):
        status,_,body=request('/api/save',row(**changes))
        assert status==422 and key in json.loads(body)['errors']
    for number in ('1*529','81*529'):
        status,_,body=request('/api/save',row(number))
        assert status==201 and json.loads(body)['state']=='phone_verification_required'
    assert request('/api/save',row('1*529'))[0]==422
    rows=json.loads(request('/api/rows')[2]);assert len(rows)==4
    assert {r['number'] for r in rows}=={'1*700001','1*700002','1*529','81*529'}
    marker='DO_NOT_STORE_CHALLENGE'
    assert request('/api/save',row(pin=marker))[0]==422
    assert marker.encode() not in path.read_bytes()
    assert marker not in capsys.readouterr().err

def test_http_bounds_and_origin(http):
    request,_=http
    assert request('/api/save',raw=b'x'*8193)[0]==400
    assert request('/api/save',raw=b'{')[0]==400
    assert request('/api/save',raw=b'[]')[0]==400
    assert request('/api/save',row(),headers={'Content-Type':'text/plain'})[0]==415
    assert request('/api/save',row(),headers={'Origin':'https://example.test'})[0]==403
    for change in ({'number':'1*'+'5'*16},{'name':'Sample '+'A'*46},{'website':'https://example.test/'+'a'*201},{'video':'https://outside.example/video'}):
        assert request('/api/save',row(**change))[0]==422

def test_simulated_challenge_never_grants_eligibility(http):
    request,path=http
    for number,phone,classification in [('1*700003','+12025550101','unknown'),('81*700003','+12025550102','unavailable')]:
        status,_,body=request('/api/save',row(number,phone=phone,plan='10E',simulated_approval=True))
        assert status==201
        result=json.loads(body)
        assert result['state']=='phone_verification_required'
        assert result['phone_assessment']==dict(possession='unverified',classification_fixture=classification,account_eligibility='pending',grants_10e=False,activates_listing=False)
    assert request('/api/save',row('1*700004',possession='verified'))[0]==422
    assert request('/api/save',row('1*700004',plan='10E',rta='Y'))[0]==422
    assert request('/api/activate',row())[0]==404
    assert all(r['state']!='active' for r in json.loads(request('/api/rows')[2]))
    assert b'2468' not in path.read_bytes()
