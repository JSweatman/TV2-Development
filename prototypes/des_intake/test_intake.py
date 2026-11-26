import concurrent.futures
import json
import sqlite3
import threading
import pytest
from server import Intake

@pytest.fixture
def store(tmp_path): return Intake(str(tmp_path/'synthetic.sqlite'))
def row(number='1*700003',**changes):
    data=dict(number=number,name='Sample Woodshop',plan='business',rta='N',website='https://example.test/class',phone='+12025550101',text='',video='',social1='',social2='',social3='',social4='',ack=True,simulated_approval=True)
    data.update(changes);return data

def test_identity_and_reserved(store):
    for n in ('1*700001','1*700002'):assert 'number' in store.validate(row(n))
    for n in ('1*529','81*529','*529','1*529.12'):
        assert store.save(row(n))[0]==201
        assert store.save(row(n))[0]==422
    assert store.key(' 1*529 ')==store.key('1*529')
    assert 'number' in store.validate(row('529'))

def test_gates_and_no_secret_storage(store):
    assert store.save(row(plan='10E',rta='Y'))[0]==422
    assert store.save(row(ack=False))[0]==422
    assert store.save(row(simulated_approval=False))[0]==422
    assert store.save(row(pin='DO_NOT_STORE'))[0]==422
    assert store.save(row(phone='+44123456789'))[0]==422
    assert store.save(row(website='https://real.example.com'))[0]==422
    assert store.save(row(video='javascript:alert(1)'))[0]==422
    for url in ('https://example.test/?token=bad','https://user@example.test/a','https://example.test:443/a','https://example.test/#x'):
        assert store.save(row(website=url))[0]==422
    assert store.save(row(plan='10E'))[0]==201
    again=Intake(store.path)
    assert again.rows()[-1]['state']=='phone_verification_required'
    raw=open(store.path,'rb').read()
    assert b'DO_NOT_STORE' not in raw and b'simulated_approval' not in raw

def test_atomic_competing_saves(store):
    # Both pass quick validation before racing final INSERT; not just UI preflight.
    original=store.validate;barrier=threading.Barrier(2)
    def simultaneous(data,final=False):
        errors=original(data,final)
        barrier.wait(timeout=5)
        return errors
    store.validate=simultaneous
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        responses=list(pool.map(lambda _:store.save(row()),range(2)))
    assert sorted(status for status,_ in responses)==[201,409]
    with sqlite3.connect(store.path) as db:
        assert db.execute("SELECT count(*) FROM intake WHERE number='1*700003'").fetchone()[0]==1

def test_invalid_shape(store):
    for data in (None,[],{'phone':{}},row(name='<script>'),row(number=[])):
        assert store.validate(data)


def test_all_optional_cells_persist_without_activation(store):
    data=row(text='+12025550102',video='https://example.test/clip',
             **{f'social{i}':f'https://example.test/social{i}' for i in range(1,5)})
    assert store.save(data)[0]==201
    with sqlite3.connect(store.path) as db:
        payload,state=db.execute("SELECT payload,state FROM intake WHERE number='1*700003'").fetchone()
    saved=json.loads(payload)
    assert saved=={k:v for k,v in data.items() if k!='simulated_approval'}
    assert state=='phone_verification_required'
