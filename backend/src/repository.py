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


class ResolverRepository(Protocol):
    def get_listing(self, country_code: str | None, base: str, tldx: str | None) -> ListingRecord | None: ...
    def prefix(self, country_code: str | None, base: str, tldx_prefix: str | None, limit: int) -> list[PrefixRecord]: ...
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
            return []  # never enumerate an entire country/global namespace
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

    def health(self) -> bool:
        return True


class PostgresResolverRepository:
    """PostgreSQL implementation for the public resolver read path."""

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
    mode = os.getenv("TV2_REPOSITORY", "postgres").strip().lower()
    if mode == "fixture":
        default = Path(__file__).resolve().parents[1] / "fixtures" / "resolver_records.json"
        path = os.getenv("TV2_FIXTURE_FILE", str(default))
        return FixtureRepository.from_json_file(path)
    if mode != "postgres":
        raise RuntimeError(f"Unsupported TV2_REPOSITORY mode: {mode}")
    database_url = os.getenv("DATABASE_URL", "postgresql://tv2:tv2@localhost:5432/tv2")
    return PostgresResolverRepository(database_url)
