# Des synthetic intake — unpublished local prototype

Base: #69 `22aa61dcd344d1622cde85133117c86834c416e3`.
This directory is not imported by normal Flutter, the resolver, release workflows,
or Render configuration. No Site/project has been created. Do not deploy it.

## What works

A responsive worksheet captures complete qualified List Number, fictional Display
Name, sample business/10E type, RTA Y/N, website, registration phone, optional text
number, video reference and four social references. Native labeled controls,
visible keyboard focus, inline validation and an announced save result are provided.

Only `https://example.test/path` links and two reserved synthetic phone choices
are accepted. Links are text only: no fetch, preview, playback or contact handler.
Display names must start with Sample. Never enter personal information.

The displayed 2468 challenge is a deliberately public rehearsal code, not a PIN
or authentication mechanism. Its input is cleared after checking; no challenge
value is sent to the server, persisted, or logged. The request contains only a
boolean simulated_approval. That boolean is trivially forgeable and MUST NOT be
used as real authorization. There is no account, permission grant, verification,
SMS, billing, location or publishing capability.

RTA Yes is rejected for 10E/free. RTA No requires acknowledgment of visibly marked
DRAFT product wording, not legal terms. All successful saves remain
phone_verification_required: they never become public listings or verified phones.

## Local persistence and identity

Python standard-library SQLite stores only this prototype's synthetic intake.
The default server creates a temporary database and removes it on shutdown.
An explicit --db path can retain isolated test data across local restarts; keep
that file outside the repository. This is not Supabase, a production enrollment
repository, a vendor integration, or a database migration.

The existing backend parser produces the full (country_code, base, tldx) tuple,
serialized as a non-null SQLite primary key. `.canonical` alone is NOT used.
Whitespace outside the complete number is trimmed; existing country, base,
global and suffix parsing semantics are unchanged. Validation provides early
feedback; final INSERT is atomic. Duplicate errors do not replace existing rows.
Synthetic 1*700001 (draft) and 1*700002 (expired) stay occupied.

## Run and checks

Managed cloud preview: `sites-preview start <checkout>/prototypes/des_intake`.
The dev command uses the managed port, binds only 127.0.0.1 and adds no hosting manifest.
For a separately permitted local workstation: `python3 server.py --port 5173`.
No network or application dependencies are added. The tests use the existing pytest.

```
python -m pytest -q prototypes/des_intake/test_intake.py
node --check prototypes/des_intake/web/app.js
```

Five tests passed: reserved and normalized/cross-country/global/suffix identity;
RTA/phone/URL/approval gates and secret exclusion; persistence across repository
reopening; two concurrent successful preflights resulting in one 201 and one 409;
malformed data; all optional cells persist without activation. Existing backend tests are run separately for parser regressions.

## Browser acceptance still blocked

2026-11-26: managed preview accepted the application command after adding its
required --host/--strictPort arguments, but failed with:
`relay could not open browser port 4173: timed out waiting for relay readiness`.
`sites-preview status` reported stopped. No alternate route or environment change
was attempted. Actual browser screenshots, keyboard traversal, compact layout,
cell feedback and error presentation are UNVERIFIED. No human handoff yet.

After supported relay recovery, test: 390px and laptop layout; Tab through fields;
occupied identity feedback; 10E + Yes rejection; No without acknowledgment;
wrong then correct demo challenge; save + reload and phone-verification state;
same digits in +1/+81; duplicate save; simulate network loss and verify error text.
Inspect network bodies to confirm no challenge value or external requests.

Before any real use: separately approved identity/owner authorization, verified
phone workflow, reviewed RTA product/legal text, canonical write contract,
hosted access and retention design are required. None is simulated as completed.

## HTTP follow-up and private-route decision

Follow-up starts from 7373bdade9c15b73e3f4d62bd6ee4c28f9dc7c94.
Eight tests now pass (five repository + three real HTTP integration tests).
`test_http.py` runs the actual server handler on an OS-assigned loopback port for
assertions only, then shuts it down. This is not an alternative preview server,
port exposure, browser transport or relay bypass.

Observed HTTP: worksheet markup and local JS/CSS delivered; no-store and CSP
restrict connect to self, disable media/frames/images and form submission;
complete qualified identity checks; duplicate/draft/expired occupation;
10E/RTA-No/phone/approval failures; distinct country saves; pending verification;
8 KiB request cap; malformed JSON/type/unknown fields rejected; foreign Origin
rejected; no publishing endpoint. Sent challenge-marker field is rejected and
absent from the DB and request logs. JS source builds payloads without the PIN
and clears it on check. These source/HTTP assertions do not establish actual
browser CSP enforcement, network trace, keyboard operation or challenge lifetime.

Managed diagnostic follow-up: `sites-preview status` still reports stopped.
`sites-preview --help` exposes start/status/stop only. There is no new recovery
signal, so no retry was made after the prior relay readiness failure. Browser
end-to-end QA remains a handoff gate.

### Recommended candidate route, conditional — no resources created

For an eventual synthetic-only owner review, use a NEW owner-private Sites Worker
and dedicated D1 database, not an existing TV2 Site or shared resolver database.
The Sites skill supports Worker ESM and per-Site D1 bindings; private access is
owned by Sites and must be verified before release. Require identity/owner access
for every API operation, no public write endpoint, no app connectors or tunnels.
Keep demo challenge explicitly non-authenticating behind that real access gate.

Required adaptation (NOT implemented here): a separately labeled JavaScript
sandbox adapter with the same validation and tuple-key uniqueness in D1, schema
migration + synthetic seed, parity tests against this Python reference, restart
persistence and owner-only denied-access tests. This is a review sandbox only:
Python/Postgres remains the actual product architecture and no code is swapped
into its normal app/resolver. A static mockup is not an acceptable substitute.
The current Python stdlib server/SQLite file cannot simply be uploaded and run
as a Sites Worker; do not claim portable hosting without that adaptation.

Official included-use documentation:
https://help.openai.com/en/articles/20001339-creating-and-using-chatgpt-sites
states hosting is currently included with Plus/Pro, Enterprise hosting charges
are currently waived, and usage/storage limits apply. This does not verify this
account's plan, current allowance or Business billing terms. Confirm the actual
account's included allowance and owner-private access before any create/publish;
stop if extra cost or uncertain entitlement. Building also consumes Codex usage.
No deployment, Site creation, D1 provisioning, live data, shared grants, existing
Render change or owner link has occurred.
