# List Number TV2 — engineering checkpoint

TV2 is a Flutter mobile client connected to the FastAPI List Number resolver on Render, with Supabase-backed identity records. The repository is a **development/test system**, not a release-ready mobile application.

## Resolver and country context

- API base URL defaults to `https://tv2-development.onrender.com` in `TV2_flutter/lib/main.dart`.
- Set another endpoint at build/run time using `--dart-define=TV2_API_BASE_URL=...`.
- The client loads available country codes/NIDs from `GET /v1/countries`.
- **There is no automatic country code 1.** Users must select a country; that NID is stored on the device and remains selected until changed.
- Prefix search and exact resolution use the selected NID, except when a separately qualified/global List Number is supplied.
- Country namespaces are independent: the same base number can identify different resources in different countries.

## Implemented checkpoints

- Fixed 16-key keypad; 250-ms debounced progressive lookup with stale-response protection.
- Country/NID selector with persistent local setting and no implicit `1` fallback.
- Server-driven listings, resources, and template screen.
- CALL currently reports a configured capability but does **not** connect a communications provider.
- HTTPS external-resource launcher is developed in [PR #5](https://github.com/JSweatman/TV2-Development/pull/5), with allow/reject tests. It checks hostname syntax; it cannot establish DNS trust or eliminate all malicious websites.
- Live resolver smoke test includes retry handling for Render wake-up delays.

## Automated quality gates

- `backend-tests`: backend unit/integration checks.
- `flutter-tests`: Flutter logic/widget tests, not a native installation test.
- `live-smoke-tests`: live Render/Supabase response and fixture checks.
- `android-debug-build` (proposed in [PR #7](https://github.com/JSweatman/TV2-Development/pull/7)): generate a **temporary** Android scaffold and compile an APK in CI; retain it briefly as an internal test artifact. This does not establish release signing or Play Store readiness.

The restored Flutter archive lacks checked-in `android/` and `ios/` native runners. They must be generated, configured with final application identifiers and platform permissions, reviewed, and version-controlled before release. An APK produced by the temporary scaffold is for engineering testing only.

## Mobile-device acceptance plan

Perform the same core scenarios on Android and iPhone, recording PASS, FAIL, or NOT TESTED **independently for each device**:

1. Install a test build and launch without crashing.
2. Open Settings, explicitly select a country; verify no automatic `1` is chosen on a clean installation.
3. Close/relaunch the app and verify the selected NID persists; change it and verify future resolution changes accordingly.
4. Resolve a known exact fixture and a partial prefix under each supported test namespace; check display names and resource metadata.
5. Open a permitted HTTPS resource; reject malformed, local, non-HTTPS, and unsupported destination URLs without a crash.
6. Disconnect network access, reconnect, and check error/retry behavior.
7. Check physical touch targets, rotation/layout (where supported), accessibility text scaling, and browser return-to-app behavior.
8. Verify the intended foreign-language and translation experience; do not mark PASS until observed on a device.

Test fixtures must exist for any cross-country comparison. The example JP/FR `101` identities are architectural examples, not proof that live fixtures have been provisioned.

For iOS: establish a macOS/Xcode build environment, generate and configure the iOS runner, compile and test with the simulator, then install a private physical-device build through an approved signing/TestFlight path. Enrollment in the Apple Developer Program can be deferred until that distribution stage. Simulator checks alone are not device acceptance.

## Deferred / unverified work

- HOME double-press / two-second-hold shortcuts are documented but not implemented.
- Real calling, video, text, and CDD service integrations are not yet complete.
- iOS simulator, physical Android, and physical iPhone acceptance remain unverified.
- Translation prompt behavior is a required device acceptance test, not a confirmed TV2 feature.
- Production signing, stable application IDs, launch policies, and final release packages remain outstanding.

**Astra handoff gate:** Do not describe the project as handoff-ready until merged CI checks, platform builds, device acceptance evidence, security limitations, and a current architecture/operations inventory are documented.
