"""Resolver repository boundary.

Only public/resolver-safe listing metadata crosses this boundary. Protected CDD,
consent records, private communications routes, credentials, and internal provider
addresses are deliberately excluded.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import json
import os
from pathlib import Path
from typing import Any, Protocol

import httpx

try:
    import psycopg
except ImportError:  # local fixture/API tests do not require PostgreSQL
    psycopg = None


@dataclass(frozen=True)
class ResourceRecord:
    key: str
    type: str
    uri: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class ButtonRecord:
    slot: int
    label: str | None
    resource_key: str


@dataclass(frozen=True)
class ListingRecord:
    country_code: str | None
    list_number: str
    tldx: str | None
    display_name: str
    entity_type: str
    template_key: str
    resources: tuple[ResourceRecord, ...] = ()
    buttons: tuple[ButtonRecord, ...] = ()


@dataclass(frozen=True)
class PrefixRecord:
    country_code: str | None
    list_number: str
    tldx: str | None
    display_name: str
    entity_type: str


@dataclass(frozen=True)
class CountryNamespaceRecord:
    iso2: str
    country_name: str
    nid: str
    default_language_tag: str | None = None


class ResolverRepository(Protocol):
    def get_listing(self, country_code: str | None, base: str, tldx: str | None) -> ListingRecord | None: ...
    def prefix(self, country_code: str | None, base: str, tldx_prefix: str | None, limit: int) -> list[PrefixRecord]: ...
    def countries(self) -> list[CountryNamespaceRecord]: ...
    def health(self) -> bool: ...


class FixtureRepository:
    """Local deterministic repository used only for development and contract tests."""

    def __init__(self, listings: list[ListingRecord]):
        self._listings = tuple(listings)

    @classmethod
    def from_json_file(cls, path: str | Path) -> "FixtureRepository":
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        listings: list[ListingRecord] = []
        for item in payload:
            resources = tuple(ResourceRecord(**r) for r in item.get("resources", []))
            buttons = tuple(ButtonRecord(**b) for b in item.get("buttons", []))
            listings.append(ListingRecord(
                country_code=item.get("country_code"),
                list_number=item["list_number"],
                tldx=item.get("tldx"),
                display_name=item["display_name"],
                entity_type=item.get("entity_type", "test"),
                template_key=item.get("template_key", "default"),
                resources=resources,
                buttons=buttons,
            ))
        return cls(listings)

    def get_listing(self, country_code: str | None, base: str, tldx: str | None) -> ListingRecord | None:
        for item in self._listings:
            if (item.country_code, item.list_number, item.tldx) == (country_code, base, tldx):
                return item
        return None

    def prefix(self, country_code: str | None, base: str, tldx_prefix: str | None, limit: int) -> list[PrefixRecord]:
        if not base:
            return []
        rows: list[ListingRecord] = []
        for item in self._listings:
            if item.country_code != country_code or not item.list_number.startswith(base):
                continue
            if tldx_prefix is not None:
                if item.list_number != base:
                    continue
                if item.tldx is None or not item.tldx.startswith(tldx_prefix):
                    continue
            rows.append(item)
        rows.sort(key=lambda item: (
            not (item.list_number == base and item.tldx == (tldx_prefix if tldx_prefix not in ("", None) else None)),
            len(item.list_number), item.list_number, item.tldx or "", item.display_name,
        ))
        return [PrefixRecord(r.country_code, r.list_number, r.tldx, r.display_name, r.entity_type) for r in rows[: limit + 1]]

    def countries(self) -> list[CountryNamespaceRecord]:
        return [
            CountryNamespaceRecord("US", "United States", "1", "en-US"),
            CountryNamespaceRecord("CA", "Canada", "1", "en-CA"),
            CountryNamespaceRecord("FR", "France", "33", "fr-FR"),
            CountryNamespaceRecord("JP", "Japan", "81", "ja-JP"),
            CountryNamespaceRecord("IN", "India", "91", "en-IN"),
        ]

    def health(self) -> bool:
        return True


class SupabaseResolverRepository:
    """Public resolver read path through narrow Supabase RPC functions.

    This intentionally uses only a publishable key. The RPC functions expose
    resolver-safe public metadata and do not permit arbitrary table access.
    """

    def __init__(self, base_url: str, publishable_key: str, timeout: float = 5.0):
        self.base_url = base_url.rstrip("/")
        self.publishable_key = publishable_key
        self.timeout = timeout

    @property
    def _headers(self) -> dict[str, str]:
        return {
            "apikey": self.publishable_key,
            "Authorization": f"Bearer {self.publishable_key}",
            "Content-Type": "application/json",
        }

    def _rpc(self, name: str, payload: dict[str, Any]) -> Any:
        response = httpx.post(
            f"{self.base_url}/rest/v1/rpc/{name}",
            headers=self._headers,
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def get_listing(self, country_code: str | None, base: str, tldx: str | None) -> ListingRecord | None:
        item = self._rpc("resolver_get_listing", {
            "p_country_code": country_code,
            "p_base": base,
            "p_tldx": tldx,
        })
        if item is None:
            return None
        resources = tuple(
            ResourceRecord(
                key=r["key"],
                type=r["type"],
                uri=r.get("uri"),
                metadata=r.get("metadata") or {},
            )
            for r in item.get("resources", [])
        )
        buttons = tuple(
            ButtonRecord(
                slot=b["slot"],
                label=b.get("label"),
                resource_key=b["resource_key"],
            )
            for b in item.get("buttons", [])
        )
        return ListingRecord(
            country_code=item.get("country_code"),
            list_number=item["list_number"],
            tldx=item.get("tldx"),
            display_name=item["display_name"],
            entity_type=item["entity_type"],
            template_key=item.get("template_key", "basic"),
            resources=resources,
            buttons=buttons,
        )

    def prefix(self, country_code: str | None, base: str, tldx_prefix: str | None, limit: int) -> list[PrefixRecord]:
        if not base:
            return []
        rows = self._rpc("resolver_prefix", {
            "p_country_code": country_code,
            "p_base": base,
            "p_tldx_prefix": tldx_prefix,
            "p_limit": limit,
        })
        return [
            PrefixRecord(
                country_code=r.get("country_code"),
                list_number=r["list_number"],
                tldx=r.get("tldx"),
                display_name=r["display_name"],
                entity_type=r["entity_type"],
            )
            for r in (rows or [])
        ]

    def countries(self) -> list[CountryNamespaceRecord]:
        response = httpx.get(
            f"{self.base_url}/rest/v1/country_namespaces",
            headers=self._headers,
            params={
                "select": "iso2,country_name,nid,default_language_tag",
                "active": "eq.true",
                "order": "country_name.asc",
            },
            timeout=self.timeout,
        )
        response.raise_for_status()
        return [
            CountryNamespaceRecord(
                iso2=row["iso2"],
                country_name=row["country_name"],
                nid=row["nid"],
                default_language_tag=row.get("default_language_tag"),
            )
            for row in response.json()
        ]

    def health(self) -> bool:
        try:
            response = httpx.get(
                f"{self.base_url}/rest/v1/country_namespaces",
                headers=self._headers,
                params={"select": "iso2", "limit": "1"},
                timeout=self.timeout,
            )
            return response.status_code == 200
        except Exception:
            return False


class PostgresResolverRepository:
    """PostgreSQL implementation retained for portability and local use."""

    def __init__(self, database_url: str):
        self.database_url = database_url

    def _connect(self):
        if psycopg is None:
            raise RuntimeError("psycopg is required for PostgreSQL repository mode")
        return psycopg.connect(self.database_url)

    def get_listing(self, country_code: str | None, base: str, tldx: str | None) -> ListingRecord | None:
        with self._connect() as conn, conn.cursor() as cur:
            cur.execute(
                """SELECT id,country_code,list_number,tldx,display_name,entity_type,template_key
                   FROM listings
                   WHERE resolution_state='active'
                     AND country_code IS NOT DISTINCT FROM %s
                     AND list_number=%s
                     AND tldx IS NOT DISTINCT FROM %s
                   LIMIT 1""",
                (country_code, base, tldx),
            )
            row = cur.fetchone()
            if row is None:
                return None
            listing_id = row[0]
            cur.execute(
                """SELECT resource_key,resource_type,public_uri,public_metadata
                   FROM listing_resources
                   WHERE listing_id=%s AND enabled=TRUE
                   ORDER BY resource_key""",
                (listing_id,),
            )
            resources = tuple(ResourceRecord(r[0], r[1], r[2], r[3] or {}) for r in cur.fetchall())
            cur.execute(
                """SELECT b.slot,b.label,r.resource_key
                   FROM listing_buttons b
                   JOIN listing_resources r ON r.id=b.resource_id AND r.enabled=TRUE
                   WHERE b.listing_id=%s
                   ORDER BY b.slot""",
                (listing_id,),
            )
            buttons = tuple(ButtonRecord(r[0], r[1], r[2]) for r in cur.fetchall())
            return ListingRecord(row[1], row[2], row[3], row[4], row[5], row[6], resources, buttons)

    def prefix(self, country_code: str | None, base: str, tldx_prefix: str | None, limit: int) -> list[PrefixRecord]:
        if not base:
            return []
        escaped_base = _escape_like(base) + "%"
        escaped_tldx = None if tldx_prefix is None else _escape_like(tldx_prefix) + "%"
        with self._connect() as conn, conn.cursor() as cur:
            if tldx_prefix is None:
                cur.execute(
                    """SELECT country_code,list_number,tldx,display_name,entity_type
                       FROM listings
                       WHERE resolution_state='active'
                         AND country_code IS NOT DISTINCT FROM %s
                         AND list_number LIKE %s ESCAPE '\\'
                       ORDER BY (list_number=%s AND tldx IS NULL) DESC,
                                char_length(list_number),list_number,tldx NULLS FIRST,id
                       LIMIT %s""",
                    (country_code, escaped_base, base, limit + 1),
                )
            else:
                cur.execute(
                    """SELECT country_code,list_number,tldx,display_name,entity_type
                       FROM listings
                       WHERE resolution_state='active'
                         AND country_code IS NOT DISTINCT FROM %s
                         AND list_number=%s
                         AND tldx LIKE %s ESCAPE '\\'
                       ORDER BY (tldx=%s) DESC,char_length(tldx),tldx,id
                       LIMIT %s""",
                    (country_code, base, escaped_tldx, tldx_prefix, limit + 1),
                )
            return [PrefixRecord(*r) for r in cur.fetchall()]

    def countries(self) -> list[CountryNamespaceRecord]:
        with self._connect() as conn, conn.cursor() as cur:
            cur.execute(
                """SELECT iso2,country_name,nid,default_language_tag
                   FROM country_namespaces
                   WHERE active=TRUE
                   ORDER BY country_name"""
            )
            return [CountryNamespaceRecord(*row) for row in cur.fetchall()]

    def health(self) -> bool:
        try:
            with self._connect() as conn, conn.cursor() as cur:
                cur.execute("SELECT 1")
                return cur.fetchone() == (1,)
        except Exception:
            return False


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def build_repository() -> ResolverRepository:
    mode = os.getenv("TV2_REPOSITORY", "fixture").strip().lower()
    if mode == "fixture":
        default = Path(__file__).resolve().parents[1] / "fixtures" / "resolver_records.json"
        path = os.getenv("TV2_FIXTURE_FILE", str(default))
        return FixtureRepository.from_json_file(path)
    if mode == "supabase":
        base_url = os.getenv("SUPABASE_URL", "").strip()
        publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip()
        if not base_url or not publishable_key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required in supabase mode")
        return SupabaseResolverRepository(base_url, publishable_key)
    if mode == "postgres":
        database_url = os.getenv("DATABASE_URL", "").strip()
        if not database_url:
            raise RuntimeError("DATABASE_URL is required in postgres mode")
        return PostgresResolverRepository(database_url)
    raise RuntimeError(f"Unsupported TV2_REPOSITORY mode: {mode}")
