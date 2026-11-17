"""Explicit opt-in entrypoint; existing app:app and repository selection unchanged.

Run from backend with uvicorn expiry_app:app --app-dir src. No default content.
Uses the existing publishable-key RPC; no new keys or privileged DB access.
"""
from datetime import datetime, timezone
import os
from pathlib import Path
import re

from fastapi import HTTPException
from app import app, repository
from expiry_gate import create_gate
from repository import SupabaseResolverRepository


def configured_gate(env, repository, now=lambda: datetime.now(timezone.utc)):
    # Invalid/missing configuration makes only this limited surface unavailable.
    enabled = env.get('TV2_LIMITED_ENABLED') == 'true'
    country = env.get('TV2_LIMITED_COUNTRY', '')
    number = env.get('TV2_LIMITED_NUMBER', '')
    cutoff = None
    clip = b''
    try:
        cutoff = datetime.fromisoformat(env.get('TV2_LIMITED_NOT_AFTER', '').replace('Z', '+00:00'))
        if cutoff.tzinfo is None or not re.fullmatch(r'[0-9]{1,3}', country) or not re.fullmatch(r'[0-9]{1,15}', number):
            raise ValueError('Invalid gate configuration')
        # Optional approved read-only runtime file, never a public static mount.
        path = env.get('TV2_LIMITED_MP4_FILE')
        if path:
            p = Path(path)
            if not p.is_absolute() or p.is_symlink() or not p.is_file() or not 0 < p.stat().st_size <= 5*1024*1024:
                raise ValueError('Invalid media source')
            clip = p.read_bytes()
            if len(clip)>5*1024*1024 or clip[4:8]!=b'ftyp':
                raise ValueError('Invalid media source')
    except (ValueError, OSError):
        enabled = False

    def exact(requested):
        if not enabled or requested != number or cutoff is None or now() >= cutoff:
            return None
        # Re-check active state and DB expiry on every request, never memoize.
        # Supabase is mandatory: fixtures could ignore expiry.
        if not isinstance(repository, SupabaseResolverRepository):
            raise HTTPException(503)
        return repository.get_listing(country, number, None)
    return create_gate(exact, clip)


@app.middleware('http')
async def resolver_no_store(request, call_next):
    response = await call_next(request)
    if request.url.path in ('/v1/resolve', '/v1/prefix'):
        response.headers['Cache-Control'] = 'no-store, max-age=0'
    return response

app.mount('/limited', configured_gate(os.environ, repository))
