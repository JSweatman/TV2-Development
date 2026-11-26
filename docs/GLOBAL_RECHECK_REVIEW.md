# Explicit global action recheck

Baseline draft #71: cd47c6c4cd929c3ee5eda4ffa21df8554daa9806.
The gate formats the qualified identity as `*529` and passes an empty default
country for a global listing. HttpResolverApi previously serialized that empty
value. FastAPI's optional country parameter has min_length=1, so a present empty
country fails validation (422) before the identity parser runs.

The client now omits empty default country parameters for exact and prefix.
Qualified input and nonempty national defaults remain unchanged. No server
validation, fallback, identity rules or gate lifecycle changes.

## Verification

- HTTP-backed widget tests use actual HttpResolverApi and gate: global/national
  exact action check, explicit Continue, then reported resume with not_found
  hides actions without launching again. Prefix checks omitted empty country.
- Real normal lib/main.dart release web build, Chromium 156.0.8078.79 at 390x844,
  loopback FastAPI/PostgresResolverRepository from shared foundation
  22aa61dcd344d1622cde85133117c86834c416e3 and disposable Postgres 15 schema.
  Resolver requests were not intercepted. Only inert synthetic HTTPS Website
  destinations were fulfilled locally by the browser harness.
- Baseline: choose +1, keypad *529, ENTER opens Synthetic Global. WEBSITE sends
  empty country, gets 422 and shows reconnect; no destination opens.
- Fixed: same UI journey, WEBSITE + Continue opens /global. Suspend only the
  global row: exact/prefix exclude it; next WEBSITE blocks with unavailable and
  no further handoff. Return, Clear, enter 529: national same-base listing remains
  active and opens /national after Continue.
- Physical/hidden-tab resume is unverified; lifecycle coverage is widget-only.
  No hosted rows, deployment, or physical device touched.

Commands: `flutter test` and
`flutter build web --release --no-web-resources-cdn --dart-define=TV2_API_BASE_URL=http://127.0.0.1:54335`.
The define is local verification only, not a committed runtime/default change.
