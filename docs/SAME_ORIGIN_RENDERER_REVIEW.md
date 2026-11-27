# Same-origin renderer — local review, not rollout approval

Base:62d38d3146b992c0a90a3933dfa5a58b0773518f. Only new runtime source is
web/flutter_bootstrap.js. No Dart, font, native, resolver, database, hosting or
build-command change. No push/deployment.

Official initialization docs describe flutter_js, flutter_build_config and
loader.load(config.canvasKitBaseUrl). The checked Flutter3.50.0 SDK
ab2912035e differs from newer docs in its service-worker default. Inspected
packages/flutter_tools/lib/src/web/bootstrap.dart and build_system/targets/web.dart,
and engine/src/flutter/lib/web_ui/flutter_js/src/{utils,loader,canvaskit_loader,service_worker_loader}.js.
The pinned loader prioritizes explicit canvasKitBaseUrl and resolves it against
document.baseURI. Use relative canvaskit/, never root-absolute /canvaskit/.

Preserve the pinned default serviceWorkerSettings/version token when non-null;
omit settings for a null token (e.g. disabled service-worker strategy). No custom
worker, version, entrypoint callback or renderer variant is forced. The SDK's
actual emitted worker is an unregistering compatibility script, not an offline
cache. Its bytes are unchanged. Fresh browser registrations remain empty.
Existing installed-worker/update behavior has not been exercised on devices.

## Reproduction
Use Flutter3.50.0 and normal lib/main.dart:

    cd TV2_flutter
    flutter create --platforms=web --project-name tv2 .
    flutter pub get
    flutter build web --release --dart-define=TV2_API_BASE_URL=https://tv2-development.onrender.com

Scaffolding preserves bootstrap byte-for-byte. No --no-web-resources-cdn flag.
Five local packaging/config tests pass:

    python3 scripts/test_renderer_bootstrap.py
    python3 scripts/test_root_web_manifest.py
    python3 scripts/check_root_web_manifest.py TV2_flutter/build/web

Using existing QA Python/Chromium/Docker dependencies:

    python scripts/same_origin_renderer_browser.py --web /absolute/root-release --output /tmp/fresh-proof

The script uses disposable Postgres and real local FastAPI. It intercepts the
compiled canonical API hostname to those synthetic responses; no live resolver
request. External renderer CDN is blocked. window.open is recorded and suppressed,
not the Dart/plugin launcher. No actual contact handler or message occurs.

Root release browser test and separate --base-href /app/ release test passed
semantics-driven +1 ->1*529 ->preview ->ENTER ->fresh CALL/TEXT/EMAIL confirmation,
cancel and final gesture, then Back/reopen. For the subdirectory run use --mount
/app/. Both requested only their same-origin canvaskit/chromium/canvaskit.js and
.wasm, HTTP200, with zero external renderer requests. Renderer CDN guard active.
All three recipient-only intents had userActivation.active=true. This is not an
OS composer/send test. Chromium156.0.8078.79,390x844; no physical or installed PWA.

Compared with baseline release, only flutter_bootstrap.js and .last_build_id differ.
index.html,manifest.json,all icons,main.dart.js and flutter_service_worker.js are
identical. Root start_url '.', implicit scope/id and standalone display preserved.
The /app/ test proves relative asset paths with matching base href, not the whole
portable Northstar package or an arbitrary nested route with incorrect base href.

## Explicit remaining blocker
Screenshots show icons and surfaces but blank text in this executor: external
Roboto/fallback fonts fail ERR_CERT_AUTHORITY_INVALID independently. Semantics
still expose labels and permit automated actions; that is NOT visual text or
human usability acceptance. No certificate override or font mirroring was used.
Therefore this is a proven renderer-only correction, NOT a clean staging go.
The previously proven --no-web-resources-cdn comparison remains available as a
separate approach; it is not enabled in tracked build commands or Render settings.
A readable exact-build check in an environment with normal font access remains
necessary; broader font reliability requires separate review.

Evidence retained locally in /workspace/same-origin-renderer-proof: root/subdirectory
release outputs, build logs, scaffold hash, browser result JSON/screenshots,
artifact-delta.json and per-file inventory.json. No media, recipients or fixtures
are added to the default compiled app. No remote branch, CI run, deployment or
cost was created by this pass.

Reference: https://docs.flutter.dev/platform-integration/web/initialization
