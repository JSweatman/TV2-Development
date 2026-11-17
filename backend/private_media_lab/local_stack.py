"""Opt-in local integration. Uses only fixed loopback ports and disposable Docker names.
Run: python -m private_media_lab.local_stack --run-local OUTPUT_DIRECTORY
Never links a hosted project; fails if its disposable names already exist.
"""
import argparse
import base64
import hashlib
import hmac
import json
from pathlib import Path
import secrets
import subprocess
import time
import httpx
from .proof import run_proof

IMAGES = {
 'postgres:15-alpine': 'postgres@sha256:23799e521dee9265a8b388ecf3bc0f1eaa34b95be67f5a76af4f8f6adb44c720',
 'supabase/gotrue:v2.186.0': 'supabase/gotrue@sha256:f2112b9289422f205df4ea15b8b550d425ae42528ea54521faa32cc7b62490de',
 'supabase/storage-api:v1.89.12': 'supabase/storage-api@sha256:8526956cb462e9f7d392e9848ec77133b2769982ed614e9753cc687e8e4339a6',
}

def run(args):
    # Do not print environment arguments or provider logs (contain local secrets).
    args=[IMAGES.get(x,x) for x in args]
    result=subprocess.run(['docker',*args],capture_output=True,text=True)
    if result.returncode: raise RuntimeError('Disposable Docker operation failed: '+args[0])
    return result.stdout.strip()

def wait_ready(url):
    with httpx.Client(trust_env=False,timeout=2) as client:
        for _ in range(150):
            try:
                if client.get(url).status_code==200:return
            except httpx.HTTPError:pass
            time.sleep(.1)
    raise RuntimeError('Local provider did not become healthy: '+url)

def setup():
    p=secrets.token_urlsafe(32); jwt=secrets.token_urlsafe(48)
    run(['network','create','tv2-private-lab'])
    run(['volume','create','tv2-private-auth-db'])
    run(['run','-d','--name','tv2-private-db','--network','tv2-private-lab','-e','POSTGRES_PASSWORD='+p,'-v','tv2-private-auth-db:/var/lib/postgresql/data','postgres:15-alpine'])
    for _ in range(40):
     if subprocess.run(['docker','exec','tv2-private-db','pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
     time.sleep(.25)
    run(['exec','tv2-private-db','psql','-U','postgres','-c','CREATE SCHEMA IF NOT EXISTS auth;'])
    env={'GOTRUE_API_HOST':'0.0.0.0','GOTRUE_API_PORT':'9999','API_EXTERNAL_URL':'http://127.0.0.1:54329','GOTRUE_DB_DRIVER':'postgres','GOTRUE_DB_DATABASE_URL':f'postgres://postgres:{p}@tv2-private-db:5432/postgres?search_path=auth','GOTRUE_SITE_URL':'http://127.0.0.1:54329','GOTRUE_JWT_SECRET':jwt,'GOTRUE_JWT_EXP':'3600','GOTRUE_JWT_AUD':'authenticated','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated','GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_MAILER_AUTOCONFIRM':'true','GOTRUE_DISABLE_SIGNUP':'false','GOTRUE_LOG_LEVEL':'error','GOTRUE_RATE_LIMIT_EMAIL_SENT':'100'}
    args=['run','-d','--name','tv2-private-auth','--network','tv2-private-lab','-p','127.0.0.1:54329:9999']
    for k,v in env.items():args+=['-e',k+'='+v]
    run([*args,'supabase/gotrue:v2.186.0'])

    s={'jwt':jwt,'db_password':p}
    def token(role):
     enc=lambda v:base64.urlsafe_b64encode(json.dumps(v,separators=(',',':')).encode()).decode().rstrip('=')
     b=enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'role':role,'iss':'supabase','iat':int(time.time()),'exp':int(time.time())+3600})
     return b+'.'+base64.urlsafe_b64encode(hmac.new(s['jwt'].encode(),b.encode(),hashlib.sha256).digest()).decode().rstrip('=')
    service=token('service_role'); anon=token('anon')
    s['service']=service;s['anon']=anon
    sql="""CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS;
    GRANT anon,authenticated,service_role TO postgres;
    CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.role',true),'') $$;
    CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claims',true),'')::jsonb $$;
    GRANT USAGE ON SCHEMA auth TO anon,authenticated,service_role;
    """
    run(['exec','tv2-private-db','psql','-U','postgres','-v','ON_ERROR_STOP=1','-c',sql])
    run(['volume','create','tv2-private-objects'])
    env={'ANON_KEY':anon,'SERVICE_KEY':service,'AUTH_JWT_SECRET':s['jwt'],'DATABASE_URL':f"postgres://postgres:{s['db_password']}@tv2-private-db:5432/postgres",'POSTGREST_URL':'http://127.0.0.1:1','STORAGE_BACKEND':'file','FILE_STORAGE_BACKEND_PATH':'/var/lib/storage','GLOBAL_S3_BUCKET':'local','TENANT_ID':'local','REGION':'local','FILE_SIZE_LIMIT':'5242880','ENABLE_IMAGE_TRANSFORMATION':'false','STORAGE_PUBLIC_URL':'http://127.0.0.1:54328'}
    args=['run','-d','--name','tv2-private-storage','--network','tv2-private-lab','-p','127.0.0.1:54328:5000','-v','tv2-private-objects:/var/lib/storage']
    for k,v in env.items():args+=['-e',k+'='+v]
    run([*args,'supabase/storage-api:v1.89.12'])

    wait_ready('http://127.0.0.1:54329/health')
    wait_ready('http://127.0.0.1:54328/status')
    run(['exec','tv2-private-db','psql','-U','postgres','-v','ON_ERROR_STOP=1','-c',
     'GRANT USAGE ON SCHEMA storage TO service_role, authenticated, anon; GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role; GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role; GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated; GRANT SELECT ON storage.buckets TO authenticated, anon;'])
    with httpx.Client(trust_env=False) as client:
        r=client.post('http://127.0.0.1:54328/bucket',headers={'Authorization':'Bearer '+service},json={'id':'tv2-private-lab','name':'tv2-private-lab','public':False,'file_size_limit':5242880,'allowed_mime_types':['video/mp4']})
        r.raise_for_status()
    return service

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--run-local',action='store_true',required=True)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Use a new empty output directory')
    names=('tv2-private-storage','tv2-private-auth','tv2-private-db')
    # Refuse reuse or deletion of any preexisting resources.
    for kind,values in [('container',names),('volume',('tv2-private-auth-db','tv2-private-objects')),('network',('tv2-private-lab',))]:
        for name in values:
            if subprocess.run(['docker',kind,'inspect',name],capture_output=True).returncode==0:
                raise RuntimeError('Existing local resource; refusing reuse: '+name)
    try:
        credential=setup()
        run_proof(credential,args.output)
    finally:
        for name in names:
            subprocess.run(['docker','rm','-f',name],capture_output=True)
        for name in ('tv2-private-auth-db','tv2-private-objects'):
            subprocess.run(['docker','volume','rm',name],capture_output=True)
        subprocess.run(['docker','network','rm','tv2-private-lab'],capture_output=True)
        # Do not retain synthetic identities/authorization state in evidence.
        for name in ('private-metadata.sqlite','private-metadata.sqlite-journal'):
            (args.output/name).unlink(missing_ok=True)

if __name__=='__main__':main()
