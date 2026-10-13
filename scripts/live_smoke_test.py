#!/usr/bin/env python3
"""Live TV2 resolver smoke test.

Exercises the deployed Render API against the Supabase-backed resolver using
public fixture records. This is an end-to-end deployment check, not a unit test.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://tv2-development.onrender.com"


def get(path: str, **query):
    url = BASE + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"{url} returned HTTP {response.status}")
        return json.load(response)


def main() -> int:
    root = get("/")
    assert root["status"] == "online"
    assert root["country_context"] == "client-selected"

    health = get("/health")
    assert health["status"] == "ok"

    ready = get("/ready")
    assert ready["status"] == "ready"

    countries = get("/v1/countries")
    by_iso2 = {row["iso2"]: row for row in countries}
    assert by_iso2["US"]["nid"] == "1"
    assert by_iso2["JP"]["nid"] == "81"
    assert by_iso2["FR"]["nid"] == "33"
    assert by_iso2["IN"]["nid"] == "91"

    us = get("/v1/resolve", input="529", country="1")
    india = get("/v1/resolve", input="529", country="91")
    global_code = get("/v1/resolve", input="*529", country="1")

    assert us["status"] == "resolved"
    assert india["status"] == "resolved"
    assert global_code["status"] == "resolved"
    assert us["listing"]["display_name"] == "TV2 Fixture Alpha"
    assert india["listing"]["display_name"] == "TV2 Fixture India Namespace"
    assert global_code["listing"]["display_name"] == "TV2 Global Fixture"

    assert us["listing"]["country_code"] == "1"
    assert india["listing"]["country_code"] == "91"
    assert global_code["listing"]["country_code"] is None

    prefix = get("/v1/prefix", input="529", country="1", limit="10")
    assert any(row["exact"] for row in prefix["matches"])
    assert any(row["list_number"] == "5291" for row in prefix["matches"])

    print("TV2 live smoke test passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, RuntimeError, urllib.error.URLError) as exc:
        print(f"TV2 live smoke test failed: {exc}", file=sys.stderr)
        raise
