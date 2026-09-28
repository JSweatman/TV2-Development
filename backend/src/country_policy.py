"""Country policy interface for TV2.

The resolver knows *that* country policy exists, but it does not own enrollment
policy. This module creates a stable socket for founder-approved country rules
without hard-coding unresolved numbering-plan or language assumptions.
"""
from __future__ import annotations
from dataclasses import dataclass
import json
from pathlib import Path
from typing import Mapping


@dataclass(frozen=True)
class CountryPolicy:
    country_code: str
    base_min_length: int | None = None
    base_max_length: int | None = None
    initial_language: str | None = None
    initial_locale: str | None = None
    telephone_namespace_rule: str | None = None


class CountryPolicyCatalog:
    def __init__(self, policies: Mapping[str, CountryPolicy] | None = None):
        self._policies = dict(policies or {})

    def get(self, country_code: str | None) -> CountryPolicy | None:
        if country_code is None:
            return None
        return self._policies.get(country_code)

    @classmethod
    def from_json_file(cls, path: str | Path) -> "CountryPolicyCatalog":
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        policies: dict[str, CountryPolicy] = {}
        for code, item in payload.items():
            policies[str(code)] = CountryPolicy(country_code=str(code), **item)
        return cls(policies)


EMPTY_COUNTRY_POLICIES = CountryPolicyCatalog()
