"""Postbuild root PWA contract. No hosting or runtime changes."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def verify(build):
    build = Path(build)
    expected = json.loads((ROOT / 'TV2_flutter/web/manifest.json').read_text())
    actual = json.loads((build / 'manifest.json').read_text())
    assert expected['orientation'] == 'any'
    assert actual == expected, 'Built manifest drifted from tracked root manifest'
    assert actual['start_url'] == '.' and actual['display'] == 'standalone'
    assert 'scope' not in actual and 'id' not in actual, 'Preserve existing implicit root scope/identity'
    assert '<link rel="manifest" href="manifest.json">' in (build / 'index.html').read_text()
    for icon in actual['icons']:
        assert (build / icon['src']).is_file(), 'Missing referenced icon'
    print('PASS root entrypoint manifest: orientation any; launch/scope/identity/icons preserved')

if __name__ == '__main__':
    verify(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'TV2_flutter/build/web')
