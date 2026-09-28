"""List Number TV2 public identity resolver API.

This service is intentionally narrow: resolve identity metadata and configured
public capabilities. It never reads protected CDD, consent records, credentials,
or private communications routing data.
"""
from __future__ import annotations
import os
from typing import Any
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from identity_rules import InvalidIdentity, parse_identity, parse_prefix
from repository import ListingRecord, ResolverRepository, build_repository

app = FastAPI(title="List Number TV2 Resolver", version="0.3.0")
DEFAULT_COUNTRY_CODE = os.getenv("DEFAULT_COUNTRY_CODE", "1")
MAX_PREFIX_RESULTS = 20
repository: ResolverRepository = build_repository()


class Resource(BaseModel):
    key: str
    type: str
    uri: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class Button(BaseModel):
    slot: int
    label: str | None = None
    resource_key: str


class Listing(BaseModel):
    country_code: str | None
    list_number: str
    tldx: str | None
    display_name: str
    entity_type: str
    template_key: str
    resources: list[Resource] = Field(default_factory=list)
    buttons: list[Button] = Field(default_factory=list)


class ResolveResponse(BaseModel):
    status: str
    country_context: str | None
    input: str
    listing: Listing | None = None


class Match(BaseModel):
    country_code: str | None
    list_number: str
    tldx: str | None
    display_name: str
    entity_type: str
    qualified_input: str
    exact: bool


class PrefixResponse(BaseModel):
    country_context: str | None
    input: str
    matches: list[Match]
    limit: int
    has_more: bool


def _strict_identity(raw: str, country: str | None):
    try:
        return parse_identity(raw, country if country is not None else DEFAULT_COUNTRY_CODE)
    except InvalidIdentity as exc:
        raise HTTPException(400, str(exc)) from exc


def _prefix_identity(raw: str, country: str | None):
    try:
        return parse_prefix(raw, country if country is not None else DEFAULT_COUNTRY_CODE)
    except InvalidIdentity as exc:
        raise HTTPException(400, str(exc)) from exc


def _listing_payload(record: ListingRecord) -> dict[str, Any]:
    return {
        "country_code": record.country_code,
        "list_number": record.list_number,
        "tldx": record.tldx,
        "display_name": record.display_name,
        "entity_type": record.entity_type,
        "template_key": record.template_key,
        "resources": [
            {"key": r.key, "type": r.type, "uri": r.uri, "metadata": r.metadata}
            for r in record.resources
        ],
        "buttons": [
            {"slot": b.slot, "label": b.label, "resource_key": b.resource_key}
            for b in record.buttons
        ],
    }


@app.get("/health")
def health():
    return {"status": "ok", "service": "tv2-resolver"}


@app.get("/ready")
def ready():
    if not repository.health():
        raise HTTPException(503, "Resolver repository is unavailable.")
    return {"status": "ready", "service": "tv2-resolver"}


@app.get("/v1/resolve", response_model=ResolveResponse)
def resolve(
    input: str = Query(min_length=1, max_length=64),
    country: str | None = Query(default=None, min_length=1, max_length=32),
):
    identity = _strict_identity(input, country)
    listing = repository.get_listing(identity.country_code, identity.base, identity.tldx)
    return {
        "status": "resolved" if listing else "not_found",
        "country_context": identity.country_code,
        "input": input,
        "listing": None if listing is None else _listing_payload(listing),
    }


@app.get("/v1/prefix", response_model=PrefixResponse)
def prefix(
    input: str = Query(min_length=1, max_length=64),
    country: str | None = Query(default=None, min_length=1, max_length=32),
    limit: int = Query(default=10, ge=1, le=MAX_PREFIX_RESULTS),
):
    identity = _prefix_identity(input, country)
    rows = repository.prefix(identity.country_code, identity.base, identity.tldx, limit)
    matches = [
        {
            "country_code": row.country_code,
            "list_number": row.list_number,
            "tldx": row.tldx,
            "display_name": row.display_name,
            "entity_type": row.entity_type,
            "qualified_input": ("*" if row.country_code is None else f"{row.country_code}*") + row.list_number + ("" if row.tldx is None else f".{row.tldx}"),
            "exact": row.list_number == identity.base and row.tldx == identity.tldx,
        }
        for row in rows[:limit]
    ]
    return {
        "country_context": identity.country_code,
        "input": input,
        "matches": matches,
        "limit": limit,
        "has_more": len(rows) > limit,
    }
