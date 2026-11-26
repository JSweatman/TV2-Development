# Local shared resolver and withdrawal integration

Review only: branch `local/shared-withdrawal-integration`. No push, deployment,
hosted request, migration, grant change, Des edit or installation action.

## Inputs and integration

Verified open draft heads through GitHub before combining:
- #69 `22aa61dcd344d1622cde85133117c86834c416e3`
- #71 `632ee7a620d900722283050c2ac400d584fd96b9`
- #73 `3f57414e8a235ba357766ce633ccd3c501c936c6` (includes #71)
- #72 `5699f26439dd2af8810eb72d92c882b1d2f459d2`

Started at #73, merged #72 locally at ab99553, then #69 at
`b267c4feb04eef9fdf21045f9f29a24b0eae2326`. All four are ancestors.
Only conflict: main.dart imports. Retained resolver_config and
saved_title_resolver. Normal main uses canonical resolver configuration and wraps
it once with SavedTitleResolver before passing it to HomeScreen, listing action
gates and keypad CALL. Preserved #64 tutorial/keypad source inherited from #71.
#65 cc82001 is not an ancestor; no new country seed was included.

The final local commit adds only this record and integration assertions in the
existing CALL tests: national/global definitive withdrawal clears a saved
publisher title, while transport failure and other outcomes retain it and the
qualified reference. Existing branches remain unchanged.

## Local checks

- Flutter 3.50.0 / Dart 3.14.0 full suite: 169 passed. Enhanced CALL suite: 13 passed afterward.
- Backend pytest, TV2_REPOSITORY=fixture: 47 passed plus 12 subtests.
  An initial invocation without this explicit fixture mode failed closed because
  production Supabase configuration was absent; no credentials were supplied.
- scripts/test_disposable_bootstrap.py passed fresh/rerun, identity collisions,
  exact/prefix visibility/time cases, draft/expired reservation, overlapping
  transactions (one commit, one 23505), and wrong-database guard.
- Real disposable PostgREST transport proof passed with integrated repository:
  anon RPC, namespace pair, public/nonpublic/time/state filtering, restricted
  fields, immediate exclusion and denied raw table reads/writes. Local roles and
  RLS are representative only, not a claim about hosted configuration.
- Normal lib/main.dart default and loopback fixture release web builds passed.
- Analysis completed: 41 findings, no errors (four existing warnings; remainder
  deprecation infos). Warnings concern SavedCollections non-null assertion and
  protected notifyListeners invocation, and unused CALL-test material import.
  Analyzer cache used ANALYZER_STATE_LOCATION_OVERRIDE under the workspace.

Build commands (existing SDK/dependencies):

```sh
flutter create . --platforms web --project-name tv2 --no-pub
flutter build web --release --no-web-resources-cdn
flutter build web --release --no-web-resources-cdn \
  --dart-define=TV2_LOCAL_FIXTURE=true \
  --dart-define=TV2_API_BASE_URL=http://127.0.0.1:54335
```

Generated runner/template files are untracked, not candidate source.
Runtime compiled at b267c4f; later changes are test/documentation only.
Default main.dart.js SHA256:
`d8c8545d2a0c34f0e9da196df12eba3df03688206057af0b60540b9aad79827e`.
Fixture main.dart.js SHA256:
`04a6a6b7b148f528356724564d7b9b868270c14d883a8258f3341161f29523b8`.

## Browser evidence and limits

Evidence and adapted prior harnesses are local at
/workspace/tv2-local-integration-evidence. Normal main, Chromium 156,
390x844, fresh profiles, service workers blocked, real loopback FastAPI and
Postgres. Inert example destinations and synthetic MP4 responses are locally
intercepted; resolver requests are not intercepted.

Global proof: active *529 opens its global destination after Continue; suspending
only global makes exact/prefix unavailable and blocks the next Website action;
same-base 1*529 still opens its distinct national destination.
Listing gate proof: active Website/Load/Play work after the explicit Continue
step and video time advances. Withdrawn Website and Load are blocked with no new
resource request; app-owned details/video disappear. Transport failure displays
reconnect/retry separately. Withdrawn-state screenshot inspected.

Saved-title browser proof passed in saved-awaited/result.json: actual UI Save
in Bookmarks and Address Book, then suspended qualified ENTER; after its completed
exact response and persisted title removal, reload preserves alias, both folders
and 1*529 while showing Listing unavailable for the default title. Screenshot
inspected. Earlier harness attempts reloaded on a prefix no-match message before
the exact result completed; they did not establish a completed withdrawal check.
Corrected harness waits for persistence, uses the exposed saved-row button and
settles text-field focus. Before a completed recheck, cached titles can remain.

CALL is tested with the actual Flutter widget entry point and injected launcher,
not a browser tel handler or real call. Resume/generation behavior is covered by
widgets, not an assurance that every hidden tab or OS reports resume. No recall
of already fetched media or external destinations is possible or claimed.

Parent reports hosted visibility version 20261126225859 already verified;
this task did not query/apply it. Older foundation review notes predate that
report. This candidate does not establish deployed content, native builds,
physical devices, installed PWA lifecycle, or hosted permissions. No exact-head
GitHub CI was triggered because this is local only. Remaining review warnings,
platform build/device acceptance and separately approved release/deployment are
still gates. Country expansion remains separate.
