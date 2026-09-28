# List Number TV2 Resolver — v0.3

This service is the narrow public identity-resolution layer for TV2. It resolves an existing List Number to its public listing metadata and configured public capabilities. It does **not** own enrollment policy, CDD, consent, analytics, AI, or communications routing.

## Current API
- `GET /health` — process health only.
- `GET /ready` — repository readiness.
- `GET /v1/prefix?country=1&input=529` — bounded progressive matches; display metadata only.
- `GET /v1/resolve?country=1&input=529` — exact listing and configured public resources.
- `GET /openapi.json` — machine-readable contract.

## Local fixture mode — verified in this engineering environment
From `backend/`:

```bash
TV2_REPOSITORY=fixture PYTHONPATH=src uvicorn app:app --host 127.0.0.1 --port 8000
```

Fixture mode uses `fixtures/resolver_records.json`. These records exist only to exercise namespace, prefix, TLDx, symbol, resource, and missing-resource behavior. No business example is part of resolver logic.

## PostgreSQL mode
Install requirements and create the schema from `sql/`. Then:

```bash
export TV2_REPOSITORY=postgres
export DATABASE_URL='postgresql://tv2:YOUR_LOCAL_PASSWORD@localhost:5432/tv2'
export PYTHONPATH=src
uvicorn app:app --host 127.0.0.1 --port 8000
```

A development Compose file is provided for the next environment that has Docker. It has **not** been executed in the present environment.

## Test

```bash
python -m pytest -q
```

Recorded checkpoint on 2026-09-25: `25 passed, 12 subtests passed`. See `../ENGINEERING_STATUS.md` for what this does and does not prove.

## Security boundary
Public resolver responses deliberately exclude CDD, consent records, credentials, private WebRTC/SIP destinations, and other provider routes. Communications resources expose only that a capability is configured. Session authorization/routing belongs to the communications service.
