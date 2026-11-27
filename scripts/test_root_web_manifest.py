import contextlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from check_root_web_manifest import ROOT, verify

class RootManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        shutil.copy(ROOT/'TV2_flutter/web/manifest.json', self.path/'manifest.json')
        self.manifest = json.loads((self.path/'manifest.json').read_text())
        (self.path/'index.html').write_text('<link rel="manifest" href="manifest.json">')
        for icon in self.manifest['icons']:
            p=self.path/icon['src'];p.parent.mkdir(exist_ok=True);p.write_bytes(b'synthetic icon')
    def test_root(self):
        with contextlib.redirect_stdout(io.StringIO()): verify(self.path)
    def test_reject_portrait_or_identity_drift(self):
        for field,value in [('orientation','portrait-primary'),('start_url','/app/'),('scope','/app/'),('id','new'),('name','changed')]:
            with self.subTest(field=field):
                (self.path/'manifest.json').write_text(json.dumps({**self.manifest,field:value}))
                with self.assertRaises(AssertionError): verify(self.path)
    def test_reject_missing_icon(self):
        (self.path/self.manifest['icons'][0]['src']).unlink()
        with self.assertRaises(AssertionError): verify(self.path)
    def test_reject_wrong_entrypoint(self):
        (self.path/'index.html').write_text('<html>guide only</html>')
        with self.assertRaises(AssertionError): verify(self.path)
if __name__=='__main__': unittest.main()
