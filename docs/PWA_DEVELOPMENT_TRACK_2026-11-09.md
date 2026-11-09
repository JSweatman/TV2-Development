# TV2 PWA parallel-development track — 2026-11-09

## Target

Aim to open one isolated TV2 **development preview** from both a laptop browser and a mobile browser by Friday 2026-11-13. This is a target, not an assertion of availability. Android, iOS, and mobile PWA should share a Flutter source and aligned feature milestones; platform acceptance remains independent.

## This PR: build foundation only

- Keep the shared Flutter client and resolver contract intact.
- Replace the HTTP resolver's native-only `dart:io` dependency with `package:http`, which chooses browser and native clients as appropriate.
- Build web in GitHub Actions; do not add a public deployment or implicitly publish private user data.
- Add opt-in resolver CORS allowlisting through `TV2_CORS_ALLOWED_ORIGINS`. It must contain explicit comma-separated browser origins, including scheme, hostname and optional port (e.g. `https://preview.example.org`). Never allow `*` or HTTP origins other than local development. Do not enable credential sharing.
- Keep existing Android and iOS build workflows unchanged. Do **not** uninstall the original TV2 app.

## Acceptance gates before claiming a usable PWA

1. `flutter test` passes against the changed client.
2. `flutter build web --release` passes; web bundle and provenance are uploaded as `tv2-pwa-preview-dist`.
3. Backend tests pass, including CORS allowed/disallowed origin cases.
4. Set up a **separate HTTPS preview host** after deployment review. Point it at an appropriate development API and register only that preview's exact origin in the backend's CORS allowlist. Never use wildcard CORS.
5. Open the hosted URL in a laptop browser and a mobile browser, test country/NID choice (no default `1`), persistence after refresh/reopen, numeric keypad, prefix/exact resolution, loading/error/retry, bookmarks, address book and permitted HTTPS links.
6. Test both browser instances simultaneously. The same deployed preview URL is not account-based synchronization: preferences and saved collections remain **local to each browser**. No cross-device sync is claimed.
7. Check accessibility, layout at multiple viewport sizes, browser back/navigation, local network failures and refresh behavior; record PASS/FAIL/NOT TESTED per platform.
8. Separate milestone: implement the approved default tropical-sunset keypad design and **free-for-all** appearance settings, image preview/crop and durable local storage across mobile platforms.
9. Separate milestone: confirm whether the installed web app can be added to home screen and functions as intended. A compilable web bundle is **not** proof of installability or offline support. Service worker, icons and install flow must be reviewed separately.

## Web-specific notes

- `universal_io` can be used where a compatible `dart:io` API is genuinely needed, but ordinary REST networking here uses `http` with a single platform-independent interface.
- `WebSocketChannel.connect` from `package:web_socket_channel` is the cross-platform choice for **future** signaling. No WebSocket/WebRTC work is included in this foundation PR.
- `kIsWeb` may guard truly web-specific UI/platform behavior; avoid forks for the same resolver logic.
- Browser CORS, storage quotas, file-selection permissions and service-worker caching policies cannot be proven in a mobile-native test.
- No calling, text, video call, login/enrollment, cross-device sync, production App Store/Play Store readiness, or desktop-specific layout is claimed.

## Safe rollout

1. Keep all work on a review branch until the checks pass.
2. Review cross-platform changes and backend CORS environment configuration.
3. Merge only after checks and review; deploy preview separately.
4. Record real laptop/mobile results in a dated acceptance note.
