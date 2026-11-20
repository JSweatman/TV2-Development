"""Visitor review stays synthetic, read-only and free of contact actions."""
import secrets
from pathlib import Path
from tempfile import TemporaryDirectory
from fastapi.testclient import TestClient
from test_theme_fixtures import create_app, TLS_ORIGIN
from local_media_demo.visitor_fixtures import install_visitor_fixtures


def test_visitor_records_and_failure():
    import app as resolver
    with TemporaryDirectory() as directory:
        local = create_app(owner_session=secrets.token_urlsafe(32), storage=Path(directory), origin=TLS_ORIGIN)
        install_visitor_fixtures(local)
        client = TestClient(local, base_url=TLS_ORIGIN)
        for number, kind in [('700001', 'business'), ('70002', 'person')]:
            row = client.get('/v1/resolve', params={'country': '1', 'input': '1*' + number}).json()['listing']
            assert row['entity_type'] == kind
            assert row['list_number'] == number
            assert [b['label'] for b in row['buttons']] == ['WEBSITE']
            assert all(r['type'] not in ('call', 'text', 'email') for r in row['resources'])
        assert client.get('/v1/resolve', params={'country':'1','input':'999999'}).json()['listing'] is None
        assert client.get('/owner').status_code == 403
        assert client.get('/review').status_code == 200
        assert client.get('/sample-website').status_code == 200
        assert resolver.get_repository not in resolver.app.dependency_overrides
