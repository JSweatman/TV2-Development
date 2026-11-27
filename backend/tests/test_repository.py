import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from repository import FixtureRepository


def repo():
    return FixtureRepository.from_json_file(ROOT / "fixtures" / "resolver_records.json")


def test_exact_namespace_isolation():
    r = repo()
    assert r.get_listing("1", "529", None).display_name == "TV2 Fixture Alpha"
    assert r.get_listing("91", "529", None).display_name == "TV2 Fixture India Namespace"
    assert r.get_listing(None, "529", None).display_name == "TV2 Global Fixture"


def test_resources_are_configured_per_listing_and_no_private_route_is_present():
    listing = repo().get_listing("1", "529", None)
    resources = {r.key: r for r in listing.resources}
    assert set(resources) == {"web", "call", "text", "video_call"}
    assert resources["web"].uri == "https://example.com/alpha"
    assert resources["call"].uri is None
    assert resources["text"].uri is None
    assert not hasattr(listing, "cdd")
    assert not hasattr(listing, "web_rtc_destination")


def test_prefix_only_returns_actual_records():
    matches = repo().prefix("1", "529", None, 10)
    assert [(m.list_number, m.tldx) for m in matches] == [
        ("529", None), ("529", "411"), ("5291", None)
    ]


def test_tldx_progressive_search_is_scoped_to_exact_base():
    matches = repo().prefix("1", "529", "4", 10)
    assert [(m.list_number, m.tldx) for m in matches] == [("529", "411")]


def test_empty_prefix_does_not_enumerate_namespace():
    assert repo().prefix("1", "", None, 10) == []


def test_unconfigured_backend_never_silently_serves_fixtures(monkeypatch):
    import pytest
    from repository import build_repository
    for name in ('TV2_REPOSITORY', 'SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'):
        monkeypatch.delenv(name, raising=False)
    with pytest.raises(RuntimeError, match='required in supabase mode'):
        build_repository()
    monkeypatch.setenv('TV2_REPOSITORY', 'fixture')
    assert isinstance(build_repository(), FixtureRepository)


def test_supabase_exact_and_prefix_share_rpc_origin_and_identity(monkeypatch):
    import httpx
    from repository import SupabaseResolverRepository
    calls = []
    def post(url, *, headers, json, timeout):
        calls.append((url, json))
        row = dict(country_code=json['p_country_code'], list_number='529',
                   tldx=json.get('p_tldx', json.get('p_tldx_prefix')),
                   display_name='Synthetic', entity_type='business')
        data = [row] if url.endswith('/resolver_prefix') else row
        return httpx.Response(200, json=data, request=httpx.Request('POST', url))
    monkeypatch.setattr(httpx, 'post', post)
    repository = SupabaseResolverRepository('https://fixture.example', 'synthetic-not-a-key')
    for country in ('1', '91', None):
        exact = repository.get_listing(country, '529', 'news')
        prefix = repository.prefix(country, '529', 'news', 10)
        assert (exact.country_code, exact.list_number, exact.tldx) == (country, '529', 'news')
        assert (prefix[0].country_code, prefix[0].list_number, prefix[0].tldx) == (country, '529', 'news')
    assert [url for url, _ in calls] == [
        'https://fixture.example/rest/v1/rpc/' + function
        for _ in range(3) for function in ('resolver_get_listing', 'resolver_prefix')]


def test_supabase_configuration_rejects_an_independent_database(monkeypatch):
    import pytest
    from repository import build_repository, CANONICAL_SUPABASE_URL, SupabaseResolverRepository
    monkeypatch.setenv('TV2_REPOSITORY', 'supabase')
    monkeypatch.setenv('SUPABASE_PUBLISHABLE_KEY', 'synthetic-not-a-key')
    monkeypatch.setenv('SUPABASE_URL', 'https://independent.example')
    with pytest.raises(RuntimeError, match='canonical List Number TV2 project'):
        build_repository()
    monkeypatch.setenv('SUPABASE_URL', CANONICAL_SUPABASE_URL)
    assert isinstance(build_repository(), SupabaseResolverRepository)
