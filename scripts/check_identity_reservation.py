"""Additional disposable-only Des acceptance: identity is not parser.canonical.
Invoked by test_disposable_bootstrap.py; no editor or production write path.
"""
import os
from pathlib import Path
import subprocess
import sys
import time


def verify(container):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend/src'))
    os.environ['TV2_REPOSITORY'] = 'fixture'
    from identity_rules import parse_identity
    from repository import FixtureRepository, ListingRecord
    import app
    from fastapi.testclient import TestClient
    identities = [parse_identity(s) for s in ('1*529', '81*529')]
    assert [i.canonical for i in identities] == ['529', '529']
    assert [(i.country_code, i.base, i.tldx) for i in identities] == [('1','529',None), ('81','529',None)]
    original = app.repository
    try:
        app.repository = FixtureRepository([
            ListingRecord(country_code=i.country_code, list_number=i.base, tldx=i.tldx,
                          display_name='Synthetic', entity_type='business', template_key='basic') for i in identities])
        client = TestClient(app.app)
        for value in ('1*529', '81*529'):
            response = client.get('/v1/prefix', params={'input': value})
            assert response.status_code == 200
            assert response.json()['matches'][0]['qualified_input'] == value
    finally:
        app.repository = original
    print('PASS same canonical base, distinct tuples; existing HTTP qualified_input formatter')
    command = ['docker','exec','-i',container,'psql','-U','postgres','-d','tv2_bootstrap_proof','-v','ON_ERROR_STOP=1','-At']
    def sql(text):
        return subprocess.run(command,input=text,text=True,capture_output=True,check=True).stdout
    sql("""
INSERT INTO listings(country_code,list_number,display_name,entity_type,resolution_state,expires_at) VALUES
('1','777001','Synthetic draft','business','draft',NULL),
('1','777002','Synthetic expired','business','active',statement_timestamp()-interval '1 second');
DO $$ DECLARE n text; BEGIN
FOREACH n IN ARRAY ARRAY['777001','777002'] LOOP
 ASSERT resolver_get_listing('1',n,NULL) IS NULL;
 ASSERT resolver_prefix('1',n,NULL,10)='[]'::jsonb;
 ASSERT (SELECT count(*) FROM listings WHERE country_code='1' AND list_number=n)=1;
 BEGIN
  INSERT INTO listings(country_code,list_number,entity_type) VALUES('1',n,'business');
  RAISE EXCEPTION 'reserved identity reused';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END LOOP; END $$;
""")
    print('PASS draft/expired absent from discovery but database identities remain reserved')
    first = subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    second = None
    try:
        first.stdin.write("SET application_name='des_first'; BEGIN; INSERT INTO listings(country_code,list_number,entity_type) VALUES('1','777003','business'); SELECT pg_sleep(5); COMMIT;\n")
        first.stdin.close()
        deadline=time.monotonic()+4
        while time.monotonic()<deadline:
            if '1' in sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='des_first' AND wait_event='PgSleep';").splitlines(): break
            time.sleep(.05)
        else: raise AssertionError('first transaction did not hold an uncommitted insert')
        second=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        second.stdin.write("\\set VERBOSITY verbose\nSET application_name='des_second'; INSERT INTO listings(country_code,list_number,entity_type) VALUES('1','777003','business');\n")
        second.stdin.close()
        deadline=time.monotonic()+3
        while time.monotonic()<deadline:
            if '1' in sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='des_second' AND wait_event_type='Lock' AND wait_event='transactionid';").splitlines(): break
            time.sleep(.05)
        else: raise AssertionError('competing insert not observed waiting on transaction lock')
        assert first.wait(timeout=10)==0, first.stderr.read()
        assert second.wait(timeout=10)!=0
        error=second.stderr.read()
        assert '23505' in error and 'uq_listing_namespace_v2' in error
        assert sql("SELECT count(*) FROM listings WHERE country_code='1' AND list_number='777003';").strip()=='1'
    finally:
        for process in (first,second):
            if process and process.poll() is None: process.kill(); process.wait()
    print('PASS concurrent create: observed transaction lock, one commit, one 23505, exactly one row')
