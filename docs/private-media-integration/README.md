# Private owner-media integration gate (local only)

Independent branch based on #45 `c154ff2a78c9be14ab1eb70ef0c4821b5e24f8a7`.
No existing draft, deployed source, resolver route, URL validator, Flutter UI or
five-number kit was changed. This package is absent from the backend Dockerfile's
`src/` copy and is never imported by the deployed resolver. `create_app()` without
explicit `enabled=True` exposes no routes and performs no provider/DB work.

## What was proved

Real disposable GoTrue password sign-in verifies three synthetic identities.
The server calls GoTrue `/user` for every operation and rejects anonymous users;
client-editable user metadata is never an authorization source. Fixture ownership
and viewer grants are seeded administratively in a separate local SQLite store,
with no HTTP endpoint for assigning ownership or grants.

An exact `1*73141` owner uploads a generated two-second blue H.264 MP4 (2,962 bytes).
The service checks ownership before reading media and again in the metadata
transaction after ingest. MIME, declared/actual bytes, MP4 structure, codec,
dimensions and duration are bounded (5 MiB, 30 seconds, H.264/AAC, 1920×1080).
The object gets an opaque server-generated UUID in a **real private Supabase
Storage bucket**. Upload does not publish. A separate owner-only publication
operation verifies object integrity and binds the draft to the same exact listing
and owner. No arbitrary playback URL is accepted.

A different signed-in, explicitly granted viewer streams the published reference
through the private service. The server-side Storage credential never reaches the
viewer. Authenticated users (including the owner) cannot directly read/write the
bucket: RLS remains enabled with no user object policies. Anonymous public-bucket
access is denied. Revoking the viewer grant blocks subsequent requests.

Both the private service and actual Storage container were restarted. The
published reference and byte-identical clip survived. Chromium 156 played the
clip after an explicit Play action in a separately authenticated viewer context.
This is a clearly labeled HTML integration harness, **not a new Flutter sign-in
or upload interface**, a phone test, or staging readiness.

## Reproduce safely

Existing tools: Docker, Python FastAPI/httpx/uvicorn, ffmpeg/ffprobe, Chromium,
Playwright. No app dependency or paid service is added. Run from `backend/`:

```sh
TV2_REPOSITORY=fixture python -m private_media_lab.local_stack --run-local /absolute/new-evidence-directory
TV2_REPOSITORY=fixture pytest -q tests
```

The explicit flag is mandatory. Three official images are pinned by digest in
`local_stack.py`. Ports 54327–54329 bind only `127.0.0.1`; Postgres has no host
port. The runner refuses preexisting resources with its names, creates only its
own local network/volumes, and removes those resources in `finally`. Generated
passwords, JWT secrets and service credentials stay in memory/container config;
no connected project keys are read. Synthetic users use `example.invalid` and
local auto-confirmation: email deliverability/verification is **not** tested.
The evidence directory retains only synthetic video, screenshot and result JSON;
identity/grant metadata is deleted after the test. A hard process kill may require
manual cleanup of those exact disposable Docker names before another run.

CLI 3.2.0 could not start (`EROFS`, mkdir `/home/agent/.supabase`). The successful
path uses direct disposable containers instead of changing that filesystem or
using a connected Supabase project. The reduced local setup uses real Auth and
Storage services plus Postgres; it does not run Studio, Kong or PostgREST.

## Trust boundary and remaining activation gates

- The service-role credential intentionally belongs only to the trusted media
  gateway. This is **not** a proposed direct browser upload policy. Storage
  permissions cannot substitute for exact-listing gateway authorization.
- SQLite ownership/publication state is a durable local control fixture. Before
  staging, root must approve genuine owner enrollment, authoritative listing-ID
  ownership binding and transactional server-side publication in the existing
  database. No ownership claims are derived from display names or user metadata.
- Root must approve a private bucket, tightly scoped server secrets, TLS, private
  access to the gateway and authenticated viewer policy. Both existing preview
  endpoints are internet-facing; this code must not be mounted there as-is.
- Fresh `/user` validation checks identity, but this does not establish immediate
  revocation of every still-valid access JWT after logout. A production session
  revocation policy and tests remain required.
- Single-process bounded ffprobe validation is sufficient for synthetic local
  clips only. Production needs isolated decoding/transcoding, rate/quota limits,
  scanning policy, orphan reconciliation after uncertain storage failures,
  retention/deletion and backup/restore validation. No automatic overwrite/upsert
  is exposed; failed ingest never creates a publication. Old drafts are retained
  only within the disposable run.
- No public resolver playback resource is emitted. A private reference requires
  an authenticated fetch path; future Flutter/PWA/native token handling and
  owner UI must be designed without weakening the existing HTTPS-only public
  resource validation. No Android/iOS device behavior is claimed.

The separate `DiskPrivateStore` supplies restart/failure unit tests. Actual proof
uses `SupabasePrivateStore`, verifies bucket privacy/limits at startup, and uses
real REST calls without request interception. Neither adapter permits remote
provider origins in this experiment.

## Evidence and references

[evidence/result.json](evidence/result.json) records upload/publication denials,
restart integrity, Range support and observed browser playback.
[evidence/authorized-viewer.png](evidence/authorized-viewer.png) shows the decoded
synthetic clip; its pixels were inspected. Local tests additionally cover invalid
media, wrong namespaces, cross-listing publication, owner transfer during ingest,
corruption, missing media, provider failure, revoked viewers and disabled mode.

Official sources consulted November 17, 2026:
- [Supabase changelog](https://supabase.com/changelog.md) (CLI v3 changes; no SDK upgrade).
- [Local CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started).
- [Server-verified getUser](https://supabase.com/docs/reference/javascript/auth-getuser).
- [Private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals).
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
- [Official self-hosted compose](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml)
  supplied the Storage image/environment contract; exact tested digests are pinned.

No remote configuration, account, DB, storage, ACL, deployment, APK or production
change was made. Infrastructure activation remains for root after review.

Final verification: **54 backend tests and 12 subtests passed** (four existing
framework/deprecation warnings). The complete disposable provider run passed
again from an empty local stack and removed its containers, network and volumes.
Flutter source was unchanged; no new Flutter/platform-build claim is made.
The five-number branch remains at `359310ce592b69158a2d5fe923e555f893f4fd65`;
#44/#45 remain at their original verified heads. This commit is local/unpublished.
