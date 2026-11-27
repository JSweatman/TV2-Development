"""Exercise loader options without network or Flutter compilation."""
import json
from pathlib import Path
import subprocess
import unittest
ROOT = Path(__file__).resolve().parents[1]

class BootstrapTest(unittest.TestCase):
    def test_relative_renderer_and_service_worker_modes(self):
        source = (ROOT/'TV2_flutter/web/flutter_bootstrap.js').read_text()
        for version in ['"123"', 'null']:
            script = source.replace('{{flutter_js}}', 'const _flutter={loader:{load:o=>console.log(JSON.stringify(o))}};').replace('{{flutter_build_config}}', '').replace('{{flutter_service_worker_version}}', version)
            options = json.loads(subprocess.check_output(['node','-e',script],text=True))
            self.assertEqual(options['config'], {'canvasKitBaseUrl':'canvaskit/'})
            self.assertEqual(options.get('serviceWorkerSettings'), None if version=='null' else {'serviceWorkerVersion':'123'})
            for base in ['https://example.invalid/', 'https://example.invalid/app/']:
                url = subprocess.check_output(['node','-e',f'console.log(new URL({json.dumps(options["config"]["canvasKitBaseUrl"])},{json.dumps(base)}).href)'],text=True).strip()
                self.assertEqual(url, base+'canvaskit/')

if __name__=='__main__': unittest.main()
