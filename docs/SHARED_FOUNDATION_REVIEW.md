# Shared foundation integration — staging decision

Exact inputs: #66 e47aa1d5bedb59185f17fa99c960112763eacbc2 and
#68 ae420384d8fb82c09d68bb95d3c2ed2c7bf0c300 (includes #67).
They merged without conflicts at bb21fa84ae6230a1fa1929864b1c06ca68bb45cb.
Existing drafts are unchanged. This branch is for review, not a deployment.

## Reproduce the actual normal-entrypoint proof

Use the existing declared backend requirements plus the local QA environment's
Playwright and system Chromium; no new application dependency is added.

```
cd TV2_flutter
flutter pub get
flutter create . --platforms web --project-name tv2 --no-pub
flutter build web --release --no-web-resources-cdn \
  --dart-define=TV2_LOCAL_FIXTURE=true \
  --dart-define=TV2_API_BASE_URL=http://127.0.0.1:54335
cd ..
python scripts/shared_foundation_browser.py --web TV2_flutter/build/web \
  --output /tmp/new-foundation-evidence
python scripts/test_disposable_bootstrap.py
```

The browser harness uses the cached pinned Postgres image; a disposable local
container exposes only a randomly assigned loopback DB port and is removed with
its volume afterward. Only synthetic test data is inserted. A minimal synthetic
country directory is added to the proof DB (no country seed or hosted data).
Actual FastAPI runs in postgres mode via psycopg and serves the generated Flutter
index.html on the same loopback origin. Root `/` remains the API information
route. No HTTP interception, repository mock, resolver shim, alternate Flutter
entrypoint, contact action or hosted request is used. Service workers are blocked
in a fresh headless Chromium profile; this is not installed-PWA/device evidence.

The recorded run reused #66's local-fixture release bundle after confirming the
integrated lib/ tree is identical. Its main.dart.js SHA256 is
bbabe2a346f3b4d8b2e2bea0de8e974faa8730b1fa4f99fbd309e07a6701b6e7.
This is a tested actual release build with the exact same Dart source, not a
claim that CI artifacts or hosted contents have changed. Default canonical and
fixture builds were separately verified for #66; no new default build is implied.

## Verification and boundaries

- Combined Flutter suite: 70 tests; backend: 38 tests + 12 subtests.
- Browser: +1/529 and +91/529 open distinct synthetic listings in the real UI.
  Private/restricted/invitation-only and expired records produce empty prefix /
  missing exact responses; fresh keypad lookups expose no hidden names and ENTER
  is disabled. The active public control opens normally.
- A duplicate whole identity fails the actual DB unique index. Public-to-private
  change takes effect on the next exact/prefix API request, without resolver
  restart. This does not erase already displayed/cached visitor content.
- Disposable SQL proof tests fresh/rerun, national/global/suffix identity,
  active/state/time behavior, inclusive start/exclusive expiry, and actual
  direct-repository queries. These are local owner-role SQL results, not
  PostgREST/publishable-key/RLS results.
- Read-only hosted function metadata on 2026-11-26 still matches the prepared
  patch's signatures, STABLE/SECURITY DEFINER flags, one resolution predicate
  per function and window-gate-v2 marker. Both lack the new visibility marker;
  ACLs remain postgres/anon/authenticated/service_role EXECUTE. This supports
  review compatibility, not permission to apply SQL or proof of application.
- No cached PostgREST image exists; cached GoTrue/Storage alone cannot prove
  Supabase RPC role behavior. No new stack/image/service was provisioned.

## Recommendation

**GO for code review and a separately authorized isolated synthetic staging
rehearsal. NO-GO for activating against the shared live database or for a live
editor on this evidence alone.**

Required next verification/approval:
1. Approve an explicitly isolated staging target or a tightly scoped shared
   production change; the current canonical DB is shared, not disposable staging.
2. Before any SQL application, recheck complete function definitions, signatures,
   owner/ACL and time gates. Approve the exact guarded visibility transaction and
   its fail-closed recovery plan. Keep current grants; no private-access pathway.
3. In isolated Supabase/PostgREST (or separately approved synthetic hosted canary),
   exercise exact/prefix with the actual publishable/anon role, public/nonpublic,
   state/time cases and resource exclusion; confirm ACLs unchanged and no broader
   table access. No credentials or private rows belong in evidence.
4. Verify the built canonical client against the approved resolver origin/CORS
   and deploy records only after explicit rollout approval. Native/device and
   installation acceptance remain separate; original Android and APK hold stay.
5. This integration intentionally excludes #64. Main's known cached ENTER /
   country-switch freshness gap remains: API filtering cannot revoke a previously
   cached listing. Integrate/reverify the reviewed #64 behavior before claiming
   fresh-at-ENTER visitor availability or timed revocation in the shared candidate.
6. The minimal DB proof omits Auth/legacy write-column synchronization and full
   schema restoration. Resolve those before editor writes. Desiree Bodio (Des)
   is the named next-phase spreadsheet editor; no editor, PIN, phone verification,
   RTA or billing feature is implemented or published by this work.
