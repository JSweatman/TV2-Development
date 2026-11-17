# Root-coordinated limited rollout package

## Current v2 scheduled window — supersedes immediate activation below

Use `backend/expiry_proof/guarded_migration.sql` at the current PR head. It adds
nullable `starts_at` AND `expires_at`, with request-time predicates `starts_at IS
NULL OR starts_at <= statement_timestamp()` and `expires_at IS NULL OR expires_at
> statement_timestamp()` in both RPCs. Null/null permanent rows are unchanged.
The transaction sets `lock_timeout='5s'` and `statement_timeout='30s'`; contention
or an unexpected catalog/column/function shape aborts without partial changes.
Repeat execution validates the exact canonical predicate, not merely a version
tag. Prior v1-only expiry logic is intentionally rejected for manual review;
root confirms hosted RPCs currently have no clock columns/logic.

After hosted synthetic tests pass, choose one FUTURE UTC opening S and closing
E = S + exactly 24 hours. Provision the Sites request-time gates with those exact
instants, then in advance set the exact resolver row active with starts_at=S and
expires_at=E in one transaction. Verify both services deny before S. Neither
service needs a mutation at S or E. If preparation cannot finish before S,
suspend the row/disable the site and coordinate a new future window; do not
silently shorten the promised window. Verify the Sites gate uses inclusive open
and exclusive close, including direct media/ranges, and preserve millisecond
precision and explicit UTC. This PR does not modify Sites or real data.

Rollback/disable remains fail-closed: FIRST suspend the exact row and set expiry
in the past, then disable Sites/direct media and the optional server gate. Keep
both nullable clock columns and filters; never null them/reactivate as rollback.
Old RPCs still respect suspended state. Restore prior definitions only if needed
while suspended; never assume app rollback reverses database writes. Existing
optional Python gate calls the exact RPC, so its lower bound is enforced there;
its configured NOT_AFTER remains an additional upper cap.

One-shot Sites canary workflow is DISARMED (`UNSET`) before this push. The earlier
successful hosted canary remains evidence for its prior window only.


This package is generic. No real listing identity, contact, artwork or media is
included. Founder approval is recorded in the parent task; root alone performs
hosted mutations, deploys, canary writes and final activation. Do not auto-merge.
Original proof: 4963fe23d8b4ed4ffa77d9f5e106fc601673e648. This draft is independently
based on origin/main 9f8e7a3cb325a20abb0c2e1ade60da16c4e80392, not stacked on the
unmerged theme/owner drafts. No existing draft is modified.

## Exact artifacts

- `guarded_migration.sql`: preferred deployable transaction. Adds nullable expiry,
  reads the two existing pg_get_functiondef definitions, inserts the time predicate
  after exactly one active-state WHERE, then asserts unchanged owner, ACL,
  SECURITY DEFINER, search_path/config, volatility and return type. Missing RPC,
  unexpected shape, unrecognized prior expiry logic or column type/default aborts
  the whole transaction. A tagged second run is a no-op. No GRANT/REVOKE, RLS or
  security setting modification. Root must still inspect/diff the hosted definitions
  before execution, especially tagged definitions on any subsequent deployment.
  `proposal.sql` remains historical reference only, NOT the rollout migration.
- `backend/src/expiry_app.py`: optional explicit entrypoint, reuses current
  app/repository and adds no-store to resolver responses. Default `app:app` is
  unchanged. `uvicorn expiry_app:app --app-dir src --host 0.0.0.0 --port $PORT`
  runs from existing backend root. No new dependency or service.
- `backend/src/expiry_gate.py`: same-request exact RPC for landing/media GET/HEAD,
  Range and conditional requests; 404 when disabled/expired, 503 on backend
  failure, no-store. No public static mount or redirects. No browser clock.
- `verify.py`, `backend/tests/test_expiry_gate.py`: isolated SQL and ASGI tests.

Explicit configuration (no defaults that activate):
`TV2_LIMITED_ENABLED=true`, `TV2_LIMITED_COUNTRY`, `TV2_LIMITED_NUMBER`, and
`TV2_LIMITED_NOT_AFTER` (timezone-aware ISO UTC hard maximum).
Optional `TV2_LIMITED_MP4_FILE` is an absolute read-only server-private approved
MP4 file, <=5 MiB. Missing media gives a plain no-media landing and media 404;
invalid configuration/file disables the surface. This is trusted content packaging,
not an upload/ingest validator: header checks are not proof of safe untrusted media.
Only the Supabase repository is accepted, never fixture resolution.

Routes: `/limited/listing/<number>` and `/limited/media/<number>`. Only the exact
configured country/number with no suffix is allowed. Effective cutoff is the
EARLIER of database expiry and environment hard maximum. Configure that maximum
so it cannot truncate the intended 24-hour window; it is a backstop, not the
activation timestamp. No new UI/theme is bundled: landing is deliberately generic
text/video. Parent must supply/review final content treatment before claiming
this is the finished branded demo.

## Existing hosting recommendation and verification limit

Prefer the EXISTING Python resolver web service: change only its reviewed code
and explicit entrypoint/config. `render.yaml` already declares free Python,
backend root, uvicorn, /health, and Supabase publishable-key configuration. No
new web service, storage bucket, paid disk, Edge Function or SDK is needed for a
no-media canary. A static PWA site cannot execute the gate on each request.

Read current official [deploy](https://render.com/docs/deploys.md),
[health check](https://render.com/docs/health-checks.md),
[free service](https://render.com/docs/free.md) and
[rollback](https://render.com/docs/rollbacks.md) documentation. Free web services
support managed TLS but can sleep after idle and lose runtime file writes; they
have bandwidth/build quotas and are not an uptime guarantee. No paid pre-deploy
hook or persistent disk is assumed. Apply SQL separately under root coordination.
Do not promise zero costs until parent verifies included-usage headroom and that
no overage/upgrade will occur. Existing service reuse avoids added infrastructure,
not necessarily all usage charges.

READ-ONLY ENVIRONMENT BLOCKER: Render connector list_services returned
`no workspace selected`. No workspace was selected or settings inspected here.
Parent must verify correct service ID, plan/quotas, root/build/start commands,
auto-deploy branch and current deployed SHA, environment and any cache rules.
Parent previously reported active resolver auto-deploys main; this package does
not change that. A manual older commit may later be overwritten by autodeploy.

Approved runtime media packaging remains unverified: free service runtime writes
are not durable. Root must provide a private build-time/runtime source available
on every restart (not a public/static raw URL or newly paid storage). No approved
media has been copied or transferred. If this cannot be done without new cost or
public bypass, keep media unavailable and pause actual-demo activation. No
YouTube/external provider link can promise expiry at the provider itself.

## Gated order (root only)

1. Record exact service/deploy, verify plan/quotas, capture current RPC definitions
   and ACL/security attributes, confirm no grants to direct table/resource paths
   allow bypass. Freeze the target listing as non-active; do not publish first.
2. Review and run guarded_migration.sql transaction. Verify null permanent rows
   unchanged and actual hosted exact/prefix results. Add no public policies.
3. Deploy reviewed exact generic commit with gate disabled; confirm live status,
   /health and ordinary resolver behavior. Confirm default listing unavailable.
4. With approved synthetic canary identity only, enable the exact configured gate
   and set a short canary database expiry plus a hard maximum. Use generic page,
   then a tiny synthetic approved private MP4 if provisioning is verified. Record
   hosted exact/prefix, direct landing/media, range/HEAD and no-store before,
   at/after expiry, wrong identity, permanent row and backend failure behavior.
   Check reverse-proxy/CDN/service-worker behavior and public raw-media bypass.
   Local ASGI tests do not establish hosted TLS/cache/PostgREST behavior.
5. Disable/retire canary. Only after hosted acceptance configure the approved real
   identity/content and hard maximum. Atomically set resolution_state='active'
   and expires_at = one captured database clock_timestamp() + interval '24 hours'
   for exactly the reviewed row; record the same captured activation UTC instant
   and returned deadline. Use row UUID and exact namespace predicates, assert
   affected-row count=1, avoid an upsert/broad update. Gate must already be ready.
6. Verify publicly, record deadline, and confirm fresh requests deny at cutoff.
   No cron needed. Copies/downloads/in-flight responses cannot be recalled;
   stale saved identity text may remain on clients. These are availability gates.

## Fail-closed emergency disable and rollback

FIRST suspend the exact row and set expires_at to a past database time in one
transaction, asserting its UUID/namespace and affected-row count. Confirm both
RPCs no longer return it. This works even if rollback restores the old RPCs,
which still filter resolution_state. Do not null expiry or reactivate.

Set TV2_LIMITED_ENABLED=false and deploy that disabled state; independently verify
both direct routes (including cached/range/HEAD) deny. Preserve inaccessible media
packaging, remove any raw public bypass. If database access fails, immediately
disable the served gate/config through the parent-coordinated service operation;
never serve cached last-known content. Our gate returns 503 on RPC failure.

Only THEN roll back application code if needed. Keep nullable column and expiry
predicate in place; rollback does NOT require dropping them. If rollback of RPC
bodies is essential, keep affected row suspended and restore captured original
bodies/attributes transactionally; verify permanent rows and denial again.
Render rollback restores old build/start/env values and does not reverse database
writes; an older artifact can re-enable a gate, so the DB suspension is the first
barrier. API rollback does not disable auto-deploy; Dashboard rollback does.
Parent must verify resulting auto-deploy behavior, not assume it. No automatic
rollback/activation scripts are executed by this package.

## Verified here

- Guarded migration executed on disposable network-isolated PostgreSQL 15; second
  run succeeds, revoked PUBLIC exact-RPC grant stays revoked, catalog security
  comparisons pass.
- SQL exact/prefix before/equal/after boundary and permanent/draft checks pass.
- 112 ASGI direct/range/HEAD/conditional checks pass with real local SQL RPCs.
- Independent deployable gate boundary/config/identity/no-media tests pass.
- On main-based tree: 31 tests + 12 subtests pass (four deprecation warnings).
  Earlier proof's 37-test count included unmerged draft tests not in main.
- No new dependencies, real payloads, hosted writes, deploy or media transfer.

## Optional public synthetic Sites canary CI

`.github/workflows/timed-canary-smoke.yml` uses the existing GitHub-hosted Ubuntu
runner pattern with contents:read only. It is UNARMED; a green unarmed job is NOT
canary evidence. Parent must reset the synthetic endpoint deadline with enough
queue headroom, then replace UNSET with the exact returned UTC deadline in this
PR branch. Script requires 30–480 seconds remaining on job start; if queue delay
exceeds this, fail and coordinate another window, do not assert success. Prefer
an eight-minute window and arm immediately. No workflow-dispatch/default-branch
change, secrets or added permissions. Existing runner quota must suffice.

`scripts/timed_canary_smoke.py` fetches status/headers only and does not read or
archive bodies: HTML200 + no-store and MP4 Range206 + Content-Range while active;
page, media and range-media410 + no-store on the first requests after expiry.
No redirects, auth, TLS changes or retries around a network denial. Network
latency means this demonstrates after-cutoff behavior, not exact equality; exact
boundary remains covered by database tests. This separately hosted synthetic
canary is not evidence that the resolver migration or final content is deployed.
The managed local egress block has not been probed or bypassed.
