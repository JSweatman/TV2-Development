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
