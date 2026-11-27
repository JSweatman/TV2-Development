"""Synthetic theme integration stays out of deployed resolver resources."""
import sys
import secrets
from pathlib import Path
from tempfile import TemporaryDirectory

from fastapi.testclient import TestClient

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT));sys.path.insert(0,str(ROOT/'src'))
from local_media_demo.server import create_app, TLS_ORIGIN
from local_media_demo.theme_fixtures import install_theme_fixtures


def test_distinct_local_theme_records_through_real_resolver():
    import app as resolver
    with TemporaryDirectory() as directory:
        local=create_app(owner_session=secrets.token_urlsafe(32),storage=Path(directory),origin=TLS_ORIGIN)
        install_theme_fixtures(local)
        client=TestClient(local,base_url=TLS_ORIGIN)
        for number,palette in [('70001','graphite'),('70002','lotus')]:
            prefix=client.get('/v1/prefix',params={'country':'1','input':number}).json()
            assert prefix['matches'][0]['exact']
            result=client.get('/v1/resolve',params={'country':'1','input':number}).json()['listing']
            assert result['list_number']==number
            assert len(result['buttons'])==6
            assert [b['slot'] for b in result['buttons']]==[1,2,3,4,5,6]
            theme=next(r for r in result['resources'] if r['type']=='landing_theme')
            assert theme['metadata']['palette']==palette
            assert all(r['type']!='listing_video' for r in result['resources'])
        assert resolver.get_repository not in resolver.app.dependency_overrides
