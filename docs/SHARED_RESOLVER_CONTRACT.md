# One TV2 resolver and database

Normal Android, iOS and PWA use `lib/main.dart`, `configuredResolverOrigin()` and
one `HttpResolverApi`: `https://tv2-development.onrender.com`. Countries, prefix
and exact lookup share that client (`/v1/countries`, `/v1/prefix`, `/v1/resolve`).
No platform-specific database client or credentials are added.

The existing resolver uses the canonical List Number TV2 Supabase project,
`https://wzfvdkcqpanekotfwcbm.supabase.co`, through `resolver_get_listing` and
`resolver_prefix`. The founder/parent verified the live PWA/resolver wiring;
this change does not independently attest current hosted settings. Supabase
mode now rejects a different project URL. An unset repository mode defaults to
Supabase and fails without its required configuration, never silently serving
fixture listings. Existing Render configuration already selects Supabase.
No new database, migration, seed, permission, or hosted setting is required.

## Normal builds and explicit local proofs

Normal build commands remain `flutter build apk`, `flutter build ios`, and
`flutter build web`; do not set `TV2_API_BASE_URL`. All build modes use the same
validation, including release (not Dart assertions). An alternate origin fails
closed at app startup; a successful compiler invocation alone does not prove
valid runtime configuration. Existing CI runs the config tests with normal
builds. This is a source/runtime guard, not a claim that arbitrary altered source
cannot be built or that already-distributed binaries have changed.

For a deliberate disposable normal-entrypoint fixture build only:

```
flutter build web --release --no-web-resources-cdn \
  --dart-define=TV2_LOCAL_FIXTURE=true \
  --dart-define=TV2_API_BASE_URL=http://127.0.0.1:54335
```

Both defines are required for an alternate origin. Only loopback origins are
accepted; no credentials, paths, query or fragments. These fixture builds must
not be delivered as canonical builds. Test constructors/injected ResolverApi
and separately named tool entrypoints remain test facilities, not release paths.
Local backend fixtures require `TV2_REPOSITORY=fixture`; disposable Postgres
requires explicit `TV2_REPOSITORY=postgres`. Neither mode is a hosted rollout.

## Identity and database readiness

Identity remains `(country_code, list_number, tldx)`, with NULL country meaning
global and NULL suffix distinct from a real suffix. Explicit qualified input
wins over the selected default namespace. Existing parser and API tests cover
these rules; RPC adapter tests exercise national/global/suffix parameters at one
origin without sending network requests.

Disposable Postgres 15 verification of `001_schema.sql`: separate +1, +91,
global and suffixed synthetic identities insert; duplicate national and global
identities are rejected by `uq_listing_namespace`. No private rows were read.

**Migration gap:** `003_supabase_transition.sql` is a transition from a legacy
Supabase schema, not a fresh sequential migration after 001. Applying it to a
fresh 001 database fails because `nid` does not exist. It also assumes legacy
UUID IDs, while 001 uses bigint IDs. Do not replay 003 on the canonical database
or assume these scripts reconstruct it. A future editor requires a reviewed
canonical schema baseline and read-only verification of actual constraints/RPCs,
including separately applied timed-listing gates. No migration is applied here.
The country seed remains a separate approved action.

## OPERATOR gap

In main and reviewed #64, the zero key's `OPER` is a visual legend only; pressing
it enters 0. There is no implemented speech/operator resolution path to verify.
Any future OPERATOR must submit to the same HttpResolverApi/HTTP contract,
not read another database or maintain a private identity map. This work does
not implement voice, PIN, editor, phone verification, RTA or billing.

## Evidence boundaries

Based on main 9f8e7a3cb325a20abb0c2e1ade60da16c4e80392; inspected #64 at
d6a28e6b460be5c780d8abeb092ef31e63a9f5b8 without changing it. #64's keypad,
caption and freshness fixes are separate and not implicitly included here.
Main's known country-switch stale-preview race is not fixed by a backend config
guard; this browser proof waits for the new exact preview before ENTER.
Platform CI compiles are distinct from hosted wiring, installation or device
proof. No APK is handed off and the original installation stays untouched.

Local results for this candidate: 70 Flutter tests; 32 backend tests plus 12
subtests; normal-default and explicitly configured fixture release web builds
passed. Chromium 156 at 390x844 exercised normal main against actual FastAPI
routes backed by two synthetic fixture records: +1/529 -> Synthetic One,
+91/529 -> Synthetic India, then explicit 1*529 while +91 remains selected ->
Synthetic One. Prefix/exact HTTP requests and visible listing identities were
verified. No browser interception, real listing, contact action or hosted request.
The fixture server used loopback HTTP; this does not verify hosted TLS, CORS or
Supabase RPC execution. RPC serialization was separately tested with an HTTP
stub, and SQL uniqueness with real disposable Postgres. No device result claimed.
