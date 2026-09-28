"""API contract tests with deterministic fixture repository; no PostgreSQL implied."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fastapi.testclient import TestClient
import app as service
from repository import FixtureRepository

service.repository = FixtureRepository.from_json_file(ROOT / "fixtures" / "resolver_records.json")
client = TestClient(service.app)


def test_invalid_identity_rejected():
    for value in ["123**45", "12A45", "123.", "123@#45"]:
        assert client.get("/v1/resolve", params={"input": value}).status_code == 400


def test_exact_namespace_and_global_resolution():
    local = client.get("/v1/resolve", params={"input": "529"}).json()
    india = client.get("/v1/resolve", params={"input": "91*529"}).json()
    global_ = client.get("/v1/resolve", params={"input": "*529"}).json()
    assert local["listing"]["display_name"] == "TV2 Fixture Alpha"
    assert india["listing"]["display_name"] == "TV2 Fixture India Namespace"
    assert global_["country_context"] is None
    assert global_["listing"]["display_name"] == "TV2 Global Fixture"


def test_missing_returns_not_found_without_fabrication():
    body = client.get("/v1/resolve", params={"input": "999"}).json()
    assert body == {"status": "not_found", "country_context": "1", "input": "999", "listing": None}


def test_exact_response_exposes_configured_public_capabilities_only():
    body = client.get("/v1/resolve", params={"input": "529"}).json()["listing"]
    keys = {r["key"] for r in body["resources"]}
    assert keys == {"web", "call", "text", "video_call"}
    encoded = str(body).lower()
    assert "cdd" not in encoded
    assert "webrtc_destination" not in encoded
    assert "credential" not in encoded


def test_prefix_exact_and_limit():
    response = client.get("/v1/prefix", params={"input": "529", "limit": 2})
    assert response.status_code == 200
    body = response.json()
    assert body["matches"][0]["exact"] is True
    assert len(body["matches"]) == 2
    assert body["has_more"] is True
    assert client.get("/v1/prefix", params={"input": "529", "limit": 21}).status_code == 422


def test_prefix_accepts_tldx_transitional_input():
    response = client.get("/v1/prefix", params={"input": "529."})
    assert response.status_code == 200
    matches = response.json()["matches"]
    assert [(m["list_number"], m["tldx"]) for m in matches] == [("529", "411")]
    assert matches[0]["exact"] is False


def test_prefix_does_not_enumerate_namespace_on_marker_only():
    assert client.get("/v1/prefix", params={"input": "1*"}).json()["matches"] == []
    assert client.get("/v1/prefix", params={"input": "*"}).json()["matches"] == []


def test_health_and_readiness():
    assert client.get("/health").status_code == 200
    assert client.get("/ready").status_code == 200


def test_openapi_does_not_publish_protected_cdd_model():
    schemas = client.get("/openapi.json").json()["components"]["schemas"]
    assert all("cdd" not in name.lower() for name in schemas)
