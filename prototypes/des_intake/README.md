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
