"""Local proof tests: deployed resolver never imports this application."""
import re
import secrets
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from local_media_demo.server import MAX_BYTES, create_app


class LocalMediaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.origin = 'http://127.0.0.1:8088'
        self.session = secrets.token_urlsafe(32)
        self.app = create_app(owner_session=self.session, storage=Path(self.temp.name), origin=self.origin)
        self.owner = TestClient(self.app, base_url=self.origin, cookies={'local_owner': self.session})
        self.viewer = TestClient(self.app, base_url=self.origin)
        page = self.owner.get('/owner').text
        csrf = re.search(r'X-Local-CSRF\':"([^"]+)"', page)[1]
        self.headers = {'Content-Type': 'video/mp4', 'Origin': self.origin, 'X-Local-CSRF': csrf}
        self.body = b'\x00\x00\x00\x18ftypisom' + b'local mock payload'

    def test_owner_upload_viewer_reads_and_cannot_write(self):
        self.assertEqual(self.viewer.get('/owner').status_code, 403)
        self.assertEqual(self.viewer.put('/listings/1*5247/video', content=self.body, headers=self.headers).status_code, 403)
        with patch('local_media_demo.server.validate_clip'):
            response = self.owner.put('/listings/1*5247/video', content=self.body, headers=self.headers)
        self.assertEqual(response.status_code, 200)
        record = self.viewer.get('/v1/resolve?country=1&input=5247').json()['listing']
        self.assertEqual(record['resources'][0]['metadata']['publication'], 'published')
        clip = self.viewer.get('/clips/' + response.json()['sha256'] + '.mp4')
        self.assertEqual(clip.content, self.body)
        self.assertEqual(clip.headers['content-type'], 'video/mp4')
        self.assertEqual(clip.headers['x-content-type-options'], 'nosniff')

    def test_authorization_csrf_and_host_boundaries(self):
        for headers in [dict(self.headers, Origin='https://evil.example.org'), dict(self.headers, **{'X-Local-CSRF': 'wrong'})]:
            self.assertEqual(self.owner.put('/listings/1*5247/video', content=self.body, headers=headers).status_code, 403)
        self.assertEqual(self.owner.put('/listings/1*529/video', content=self.body, headers=self.headers).status_code, 403)
        self.assertEqual(self.viewer.get('/owner', headers={'Host': 'evil.example.org'}).status_code, 403)

    def test_rejected_upload_never_publishes(self):
        self.assertEqual(self.owner.put('/listings/1*5247/video', content=self.body, headers=dict(self.headers, **{'Content-Type': 'text/html'})).status_code, 415)
        self.assertEqual(self.owner.put('/listings/1*5247/video', content=self.body, headers=dict(self.headers, **{'Content-Length': str(MAX_BYTES + 1)})).status_code, 413)
        with patch('local_media_demo.server.validate_clip', side_effect=ValueError('invalid')):
            self.assertEqual(self.owner.put('/listings/1*5247/video', content=self.body, headers=self.headers).status_code, 422)
        self.assertEqual(self.viewer.get('/v1/resolve?country=1&input=5247').json()['listing']['resources'], [])
        self.assertEqual(list(Path(self.temp.name).iterdir()), [])

    def test_real_resolver_identity_grammar_and_prefix(self):
        prefix = self.viewer.get('/v1/prefix?country=1&input=5247').json()
        self.assertTrue(prefix['matches'][0]['exact'])
        self.assertEqual(prefix['matches'][0]['qualified_input'], '1*5247')
        self.assertEqual(self.viewer.get('/v1/resolve?country=91&input=5247').json()['status'], 'not_found')
        exact = self.viewer.get('/v1/resolve?country=91&input=1*5247').json()
        self.assertEqual(exact['listing']['country_code'], '1')
        self.assertEqual(self.viewer.get('/v1/resolve?country=1&input=12**34').status_code, 400)

    def test_fixture_override_cannot_reconfigure_deployed_app(self):
        import app as resolver
        self.assertNotIn(resolver.get_repository, resolver.app.dependency_overrides)
        with patch.dict('os.environ', {'TV2_REPOSITORY': 'supabase'}):
            with self.assertRaisesRegex(ValueError, 'fixture repository mode'):
                create_app(owner_session=self.session, storage=Path(self.temp.name), origin=self.origin)

    def test_deployed_app_has_no_upload_route(self):
        import app
        self.assertFalse(any('PUT' in (getattr(route, 'methods', None) or []) for route in app.app.routes))

class ClipValidationTests(unittest.TestCase):
    def test_header_duration_codec_and_track_validation(self):
        import json
        from types import SimpleNamespace
        from local_media_demo.server import validate_clip
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'clip.mp4'
            path.write_bytes(b'not an mp4')
            with self.assertRaises(ValueError):
                validate_clip(path)
            path.write_bytes(b'\x00\x00\x00\x18ftypisom')
            good = {'codec_type': 'video', 'codec_name': 'h264', 'width': 160, 'height': 90}
            cases = [('31', [good]), ('nan', [good]), ('1', [dict(good, codec_name='hevc')]), ('1', [dict(good, width=4000)]), ('1', [good, {'codec_type': 'attachment', 'codec_name':'bin'}])]
            for duration, streams in cases:
                with patch('local_media_demo.server.subprocess.run', return_value=SimpleNamespace(stdout=json.dumps({'format':{'duration':duration},'streams':streams}))), self.assertRaises(ValueError):
                    validate_clip(path)
            with patch('local_media_demo.server.subprocess.run', return_value=SimpleNamespace(stdout=json.dumps({'format':{'duration':'1'},'streams':[good]}))):
                validate_clip(path)
