"""Regression against a real release build: python test_package.py BUILD_DIR."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urljoin, urlsplit
import zipfile

build = Path(sys.argv[1]).resolve()
original_manifest = (build/'manifest.json').read_bytes()
original = json.loads(original_manifest)
with tempfile.TemporaryDirectory() as directory:
    output = Path(directory)/'candidate'
    subprocess.run([sys.executable, str(Path(__file__).with_name('package.py')),
                    str(build), str(output)], check=True)
    with zipfile.ZipFile(output.with_suffix('.zip')) as archive:
        assert archive.testzip() is None
        inventory = json.loads(archive.read('MANIFEST.json'))
        assert set(archive.namelist()) == set(inventory) | {'MANIFEST.json'}
        for name, expected in inventory.items():
            data = archive.read(name)
            assert len(data) == expected['bytes']
            assert hashlib.sha256(data).hexdigest() == expected['sha256']
        manifest = json.loads(archive.read('www/app/manifest.json'))
        assert manifest == {**original, 'orientation': 'any'}
        index = archive.read('www/app/index.html').decode()
        assert '<base href="/app/">' in index
        assert 'href="manifest.json"' in index
        assert 'flutter_bootstrap.js' in index
        assert archive.read('www/app/flutter_bootstrap.js')
        manifest_url = 'https://example.invalid/app/manifest.json'
        start = urljoin(manifest_url, manifest['start_url'])
        scope = urljoin(manifest_url, manifest.get('scope', './'))
        identity = urljoin(start, manifest.get('id', start))
        assert start == scope == identity == 'https://example.invalid/app/'
        assert manifest['display'] == 'standalone'
        assert manifest['icons'] == original['icons'] and manifest['icons']
        for icon in manifest['icons']:
            path = urlsplit(urljoin(manifest_url, icon['src'])).path
            assert path.startswith('/app/icons/')
            assert archive.read('www'+path) == (build/icon['src']).read_bytes()
        guide = archive.read('www/index.html').decode()
        assert 'href="/app/"' in guide
        assert 'flutter_bootstrap.js' not in guide
        assert 'rel="manifest"' not in guide
        assert guide != index
assert (build/'manifest.json').read_bytes() == original_manifest
print('PASS: actual packaged index, /app/ launch/identity/scope, standalone, any orientation, icons, guide separation and inventory')
