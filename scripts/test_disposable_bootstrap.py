"""Local Docker proof, pinned cached image, no ports/network/hosted credentials.
Run: python3 scripts/test_disposable_bootstrap.py
"""
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'postgres@sha256:23799e521dee9265a8b388ecf3bc0f1eaa34b95be67f5a76af4f8f6adb44c720'


def run(*args, input=None):
    result = subprocess.run(args, input=input, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout


def main():
    # Do not implicitly download or provision anything if the local image is absent.
    run('docker', 'image', 'inspect', IMAGE)
    name = 'tv2-bootstrap-' + uuid.uuid4().hex[:10]
    try:
        run('docker', 'run', '--pull=never', '-d', '--name', name, '--network', 'none',
            '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_DB=tv2_bootstrap_proof', IMAGE)
        for _ in range(200):
            ready = subprocess.run(['docker','exec',name,'psql','-h','127.0.0.1','-U','postgres','-d','tv2_bootstrap_proof','-Atc','SELECT 1'], capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(.2)
        else:
            raise RuntimeError('Disposable Postgres did not become ready within 40 seconds')
        for iteration in (1, 2):
            for file in ('schema.sql', 'audited_rpc.sql', 'assertions.sql'):
                run('docker','exec','-i',name,'psql','-U','postgres','-d','tv2_bootstrap_proof',
                    '-v','ON_ERROR_STOP=1', input=(ROOT/'backend/bootstrap'/file).read_text())
            if iteration == 1:
                run('docker','exec','-i',name,'psql','-U','postgres','-d','tv2_bootstrap_proof',
                    '-v','ON_ERROR_STOP=1', input="INSERT INTO listings(country_code,list_number,display_name,entity_type) VALUES('1','888888','Rerun sentinel','business');")
            else:
                run('docker','exec','-i',name,'psql','-U','postgres','-d','tv2_bootstrap_proof',
                    '-v','ON_ERROR_STOP=1', input="DO $$ BEGIN ASSERT (SELECT count(*) FROM listings WHERE list_number='888888')=1, 'rerun lost preexisting synthetic row'; END $$;")
            print(f'PASS install/rerun {iteration}: uniqueness, exact/prefix, state, time, observed visibility, disabled resource')
        rejected = subprocess.run(['docker','exec','-i',name,'psql','-U','postgres','-d','postgres',
            '-v','ON_ERROR_STOP=1'], input=(ROOT/'backend/bootstrap/schema.sql').read_text(), text=True,capture_output=True)
        assert rejected.returncode != 0 and 'dedicated disposable proof database' in rejected.stderr
        print('PASS wrong-database guard; no public ports, no copied data')
    finally:
        subprocess.run(['docker','rm','-fv',name], capture_output=True)


if __name__ == '__main__':
    main()
