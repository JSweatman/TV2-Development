from dataclasses import replace
from datetime import datetime, timezone, timedelta
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import app
from repository import FixtureRepository, ListingRecord, ResourceRecord

@pytest.mark.parametrize('visibility', ['private', 'restricted', 'invitation_only', None, 'unknown'])
def test_nonpublic_exact_prefix_do_not_disclose(monkeypatch, visibility):
    hidden = ListingRecord('1','529',None,'Hidden synthetic name','business','basic',
        resources=(ResourceRecord('web','web','https://hidden.example/destination'),),
        visibility=visibility)
    public = replace(hidden, list_number='5290', display_name='Public synthetic',
        resources=(), visibility='public')
    monkeypatch.setattr(app, 'repository', FixtureRepository([hidden,public]))
    client = TestClient(app.app)
    exact = client.get('/v1/resolve', params={'input':'529','country':'1'})
    prefix = client.get('/v1/prefix', params={'input':'529','country':'1'})
    assert exact.status_code == prefix.status_code == 200
    assert exact.json()['status'] == 'not_found'
    for response in (exact,prefix):
        assert 'Hidden synthetic name' not in response.text
        assert 'hidden.example' not in response.text
    assert [r['display_name'] for r in prefix.json()['matches']] == ['Public synthetic']


def test_fixture_time_and_state_boundaries():
    now=datetime.now(timezone.utc)
    public=ListingRecord('1','529',None,'Public','business','basic')
    eligible=FixtureRepository._eligible
    assert eligible(public,now)
    assert not eligible(replace(public,starts_at=now+timedelta(seconds=1)),now)
    assert eligible(replace(public,starts_at=now,expires_at=now+timedelta(seconds=1)),now)
    assert not eligible(replace(public,expires_at=now),now)
    assert not eligible(replace(public,expires_at=now-timedelta(seconds=1)),now)
    for state in ('draft','suspended','retired'):
        assert not eligible(replace(public,resolution_state=state),now)
