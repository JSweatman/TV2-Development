# Local-only 24-hour expiry proposal

Review checkpoint only. No hosted operation, automatic migration, app import,
shared route change, deployment or real content. Isolated branch
`dot/local-expiry-proof`, based on a2e3ff2; existing drafts are untouched.

## Database contract

`proposal.sql` adds nullable `listings.expires_at timestamptz` without a default.
Null preserves permanent rows. The repository's actual Supabase exact and prefix
RPC bodies/signatures retain their response shapes and active-state checks, with
`expires_at IS NULL OR expires_at > statement_timestamp()` added before selection,
ordering and limiting. A single authoritative database request timestamp is used;
clients cannot submit their clock. At equality the row is hidden. Setting an
activation timestamp and adding **interval '24 hours'** (not a calendar day)
produces an 86,400-second window, independent of daylight-saving transitions.

This is a review SQL proposal, deliberately outside auto-applied migrations.
Its functions come from backend/sql/003_supabase_transition.sql, not a fresh
export of hosted definitions. Before rollout, compare against the live function
bodies, signatures, ownership and grants and preserve all existing guards. The
checked-in snapshot has double-escaped LIKE literals incompatible with standard
PostgreSQL string settings; this proposal normalizes those literals to single
backslashes. Local tests run with standard_conforming_strings=on. Prefer the
already-correct live prefix expression when preparing a hosted migration.
Existing SECURITY DEFINER/search_path behavior is inherited, not newly granted;
no ACL/RLS/security change is proposed. CREATE OR REPLACE preserves existing
function grants. A new nullable field does require a schema rollout approval.

## Request-time landing/media gate

`gateway.py` is a separately constructed, loopback-only proof, never mounted by
the deployed backend. Every landing GET/HEAD and media GET/HEAD (including Range,
conditional and resumed requests) consults the same exact RPC before responding.
Expiry yields empty 404, including for known direct media paths. Backend failures
fail closed with 503. All responses carry `Cache-Control: no-store, max-age=0`;
no ETags, 304 path, redirects, public storage URL, static mount or browser clock
can bypass the gate. The synthetic media bytes are supplied in memory only.
The actual public backend currently is NOT changed to add these headers/routes.

This enforces new-request availability, not erasure: already downloaded content,
already-rendered UI, screenshots or an in-flight pre-expiry response cannot be
recalled. Clients with cached/saved listing data may still display old identity
text; all content fetches must go through the gate. Strict termination of ongoing
streams or clearing open tabs at the deadline would be additional work. External
YouTube/provider links remain under provider control and cannot be made private
by expiring a TV2 listing. Do not advertise those as expiring media.

## Verification

Used the already-cached postgres:15-alpine image, isolated `--network none`, no
published ports, no volume and disposable trust auth internal to this container.
No connected Supabase project, Auth, Storage, Render or security setting touched.

```
docker run -d --rm --name tv2-expiry-proof --network none \
  -e POSTGRES_HOST_AUTH_METHOD=trust postgres:15-alpine
# wait for local pg_isready if necessary
/workspace/media-test-venv/bin/python backend/expiry_proof/verify.py
docker stop tv2-expiry-proof
```

The verification script creates/truncates ONLY this named disposable container's
synthetic tables. It loads the repository schema and proposal RPCs, then uses a
single DO statement's fixed statement_timestamp to assert one microsecond before,
exact equality and one microsecond after. Both exact and prefix RPCs, permanent
null rows and draft rows are covered. It generates a tiny blue H.264 MP4 using
existing ffmpeg; no private or externally fetched media is involved.

Observed results:
- PASS SQL RPC exact/prefix: before, equal, after; permanent and draft unchanged.
- PASS 112 direct/range/HEAD/conditional HTTP checks + resolver and fail-closed checks.

HTTP checks use FastAPI/Starlette's ASGI TestClient and actual local PostgreSQL
RPC calls via docker exec. These are not browser, live PostgREST, CDN, TLS or
physical-device tests. There is no clock injection into production signatures.
Boundary equality is proven in PostgreSQL; HTTP routes consume that decision.
The existing backend regression suite passed: 37 tests plus 12 subtests (four inherited deprecation warnings). The disposable container was stopped after validation.

## Minimum rollout requiring explicit approval

1. Review live RPC definitions and existing grants; approve the nullable column
   and narrowly revised exact/prefix queries (schema/code change, not listing-only
   authorization). Keep all permanent rows NULL. No broad permission changes.
2. Approve deploying a server request gate for the one demo landing and media
   path on existing infrastructure, with private media reachable only through
   that gate. Ensure no raw object/CDN/static alternate path remains public.
   Serve resolver responses no-store too; verify proxy/CDN/service-worker bypass
   of caches for these routes. Do not deploy or activate just the listing first.
3. Validate hosted before/equal/after behavior, direct/range requests and failure
   behavior using synthetic content. Establish server clock and monitoring.
4. Separately approve exact listing identity, content and activation instant.
   Atomically activate the approved row and set expiry = recorded activation
   + interval '24 hours'. Record UTC deadline. No number is assigned here and
   no real JOYFUL/Maureen content/contact is included. Expiration needs no cron;
   optional later cleanup is not the enforcement mechanism.

If approval is limited to a listing write, current hosting is a **no-go** for a
truthful strict 24-hour public availability promise: the required request-time
code/schema gates do not yet exist there. This local test grants no rollout
permission. Native app changes, APK, new paid infrastructure and dependencies
are unnecessary for this proof and were not performed.

References consulted: [PostgreSQL time functions](https://www.postgresql.org/docs/current/functions-datetime.html)
(statement_timestamp versus transaction time) and [Supabase changelog](https://supabase.com/changelog.md).
No Supabase SDK/CLI upgrades were made; the relevant recent CLI and Flutter
breaking changes do not affect these local PostgreSQL/ASGI tests.
