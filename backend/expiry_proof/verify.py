"""Disposable local PostgreSQL + ASGI HTTP tests; no hosted credentials/endpoints."""
import json
import re
import subprocess
from pathlib import Path
from fastapi.testclient import TestClient
from gateway import create_app

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = 'tv2-expiry-proof'
def sql(query):
    return subprocess.run(['docker','exec','-i',CONTAINER,'psql','-U','postgres',
        '-XAt','-v','ON_ERROR_STOP=1'], input=query, text=True,
        capture_output=True, check=True).stdout.strip()

sql((ROOT/'backend/sql/001_schema.sql').read_text())
baseline = (Path(__file__).parent/'proposal.sql').read_text()
baseline = baseline.replace('AND (expires_at IS NULL OR expires_at > statement_timestamp())', '')
baseline = baseline.replace('AND (l.expires_at IS NULL OR l.expires_at > statement_timestamp())', '')
sql(baseline)
sql("REVOKE ALL ON FUNCTION resolver_get_listing(text,text,text) FROM PUBLIC;")
guarded=(Path(__file__).parent/'guarded_migration.sql').read_text()
sql(guarded)
sql(guarded)  # repeatability, no grant expansion
assert sql("SELECT has_function_privilege('public','resolver_get_listing(text,text,text)','EXECUTE');") == 'f'
print('PASS guarded migration: existing grants/security retained; idempotent')
sql("""TRUNCATE listings CASCADE;
INSERT INTO listings(country_code,list_number,display_name,entity_type,resolution_state)
VALUES ('1','70001','Synthetic temporary','business','active'),
       ('1','70002','Synthetic permanent','business','active'),
       ('1','70003','Synthetic draft','business','draft');""")
# In one server statement, statement_timestamp is exact and stable. This tests
# the deployed-shape RPC bodies, not a client-side approximation of the clock.
sql("""DO $$ DECLARE test_case record; found boolean; rows jsonb;
BEGIN
 FOR test_case IN SELECT * FROM (VALUES
   ('before open', interval '-1 microsecond', false),
   ('exact open', interval '0', true),
   ('before close', interval '24 hours' - interval '1 microsecond', true),
   ('exact close', interval '24 hours', false),
   ('after close', interval '24 hours' + interval '1 microsecond', false)
 ) AS cases(label,elapsed,allowed) LOOP
  UPDATE listings SET starts_at=statement_timestamp()-test_case.elapsed,
    expires_at=statement_timestamp()-test_case.elapsed+interval '24 hours'
    WHERE list_number='70001';
  found := resolver_get_listing('1','70001',null) IS NOT NULL;
  ASSERT found = test_case.allowed, test_case.label || ' exact RPC';
  rows := resolver_prefix('1','7000',null,10);
  ASSERT (rows @> '[{"list_number":"70001"}]'::jsonb) = test_case.allowed, test_case.label || ' prefix RPC';
  ASSERT resolver_get_listing('1','70002',null) IS NOT NULL, 'permanent';
  ASSERT rows @> '[{"list_number":"70002"}]'::jsonb, 'permanent prefix';
  ASSERT resolver_get_listing('1','70003',null) IS NULL, 'draft remains hidden';
 END LOOP;
END $$;""")
print('PASS SQL RPC window: before open, exact open, before close, exact close, after close; permanent/draft unchanged')
def rejects_migration():
    try: sql(guarded)
    except subprocess.CalledProcessError: return
    raise AssertionError('unsafe migration unexpectedly accepted')
sql('ALTER TABLE listings ALTER COLUMN starts_at SET DEFAULT now();')
rejects_migration()
sql('ALTER TABLE listings ALTER COLUMN starts_at DROP DEFAULT;')
sql('ALTER FUNCTION resolver_get_listing(text,text,text) VOLATILE;')
rejects_migration()
sql('ALTER FUNCTION resolver_get_listing(text,text,text) STABLE;')
definition=sql("SELECT pg_get_functiondef('resolver_get_listing(text,text,text)'::regprocedure);")
sql(definition.replace('starts_at <=', 'starts_at <'))
rejects_migration() # marker still present, predicate tampering must fail closed
sql(definition)
sql(guarded)
print('PASS catalog/column/tampered-tag rejection and recovery')
def rpc(fn, number):
    if not re.fullmatch('[0-9]{1,15}',number): return None if fn=='resolver_get_listing' else []
    raw = sql(f"SELECT {fn}('1','{number}',null);")
    return json.loads(raw) if raw else None
clip = subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=blue:s=32x32:d=0.2',
    '-an','-c:v','libx264','-pix_fmt','yuv420p','-movflags','frag_keyframe+empty_moov',
    '-f','mp4','pipe:1'],capture_output=True,check=True).stdout
app=create_app(lambda n:rpc('resolver_get_listing',n),lambda n:rpc('resolver_prefix',n),clip)
checks=0
with TestClient(app) as client:
 for expired in (False,True):
  sql("UPDATE listings SET starts_at=NULL, expires_at=statement_timestamp()"+ ("-" if expired else "+") +"interval '24 hours' WHERE list_number='70001';")
  assert (client.get('/v1/resolve/70001').json() is None)==expired
  assert any(r['list_number']=='70001' for r in client.get('/v1/prefix/7000').json()) != expired
  for number in ('70001','70002'):
   denied=expired and number=='70001'
   for path in ('listing','media'):
    for method in ('GET','HEAD'):
     for headers in ({},{'Range':'bytes=0-15'},{'Range':'bytes=-8'},
                     {'Range':'bytes=8-'},{'Range':'bytes=999999-'},
                     {'If-None-Match':'*'},{'If-Modified-Since':'Wed, 01 Jan 2031 00:00:00 GMT'}):
      r=client.request(method,f'/{path}/{number}',headers=headers)
      expected=404 if denied else (416 if path=='media' and headers.get('Range')=='bytes=999999-' else 206 if path=='media' and 'Range' in headers else 200)
      assert r.status_code==expected,(number,path,method,headers,r.status_code)
      assert 'no-store' in r.headers['cache-control']
      if denied or method=='HEAD': assert not r.content
      if not denied and path=='media' and method=='GET' and headers.get('Range')=='bytes=0-15': assert r.content==clip[:16]
      checks+=1
 # Backend failure must not accidentally deliver media.
 broken=create_app(lambda n: (_ for _ in ()).throw(RuntimeError()),lambda n:[],clip)
 with TestClient(broken) as b:
  r=b.get('/media/70001');assert r.status_code==503 and 'no-store' in r.headers['cache-control']
print(f'PASS {checks} direct/range/HEAD/conditional HTTP checks + resolver and fail-closed checks')
