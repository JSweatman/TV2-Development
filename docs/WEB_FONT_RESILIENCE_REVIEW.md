# Optional web font startup resilience — local only

Frozen baseline8a76ac0fafd3601f806aa43a256f63cdd35befb4 remains published unchanged.
This review uses normal main.dart, unchanged Render build command and390x844
Chromium156.0.8078.79. Canonical resolver requests are intercepted to disposable
synthetic Postgres/FastAPI. Renderer is healthy and bundled; external renderer/font
hosts remain blocked. No live resolver or OS contact handler is used.

## Reproduction
Existing exact frozen release JS SHA256
b0dc8890e13a84a92e749ed60e9be175be50ce5b3e5a485979ba39afe3c403ab.
Intercept ONLY local Roboto-Bold.ttf with static404. Regular and Medium returned200,
Bold returned404; screenshot is blank white and country picker absent. Engine
semantics placeholder existed, but was not counted as mounted app UI. Two browser
page errors occurred. No browser country/resolver calls followed startup (the
harness's two direct API fixture prechecks are separately recorded).

A second fresh context with injection removed loaded normally, showed readable
keypad/preview and resolved synthetic1*529 through ENTER. No file was changed to
restore it: routing failure injection is test-only. This distinguishes the
startup regression from a corrupted asset or unhealthy resolver.

## Narrow fix
Register required Regular first. Load each optional Medium/Bold face separately,
catching only each optional load's failure; continue with remaining registered
faces. The engine can synthesize unavailable weights. Do not suppress a required
Regular failure. Do not change theme, font files/license, asset platform filter,
bootstrap, resolver or Android/iOS behavior. No new dependency/cache/retry policy.

Unit coverage: no-fault registered order, independent Medium and Bold failures,
continuation to the other weight, required Regular failure, native guard.
Full Flutter suite190 passed; five existing bootstrap/manifest tests passed.
Unchanged Render scaffold/pubget/release build passed. Generated untracked counter
test removed before running repository tests. Dart formatter command could not
initialize its analytics directory in read-only home; this is not claimed as a
format-check pass. No environment permission or home override was attempted.

## Browser regression
Use existing QA dependencies and locally built release:

    python scripts/same_origin_renderer_browser.py --web /absolute/build/web --output /tmp/bold --fail-weight Bold
    python scripts/same_origin_renderer_browser.py --web /absolute/build/web --output /tmp/medium --fail-weight Medium
    python scripts/same_origin_renderer_browser.py --web /absolute/build/web --output /tmp/normal

For frozen failing build add --expect-blocked with --fail-weight Bold.
Each injected request must be observed exactly once, correct static404, other two
faces200. Tests exercise picker/+1/keypad/preview/ENTER/listing, contact cancellation
and explicit intercepted final gestures, and Back/reopen. No actual contact app.
Screenshots, errors and request logs retained under /workspace/font-resilience-proof.

Regular/total font loss remains an explicit limitation (unit test only), as does
broader font/CDN/offline recovery. This is not a physical-device or hosted check.
No frozen-branch update, push, deployment, live data, native install or spending.

Observed final results: Bold404, Medium404 and no-fault runs all passed the above
flow with zero page errors. Manually inspected failed-weight keypad/preview and
no-fault email screenshots were readable. No-fault picker, empty keypad, exact
preview and returned listing screenshots were pixel-identical to the frozen
restored controls. Email dialog capture differed during overlay animation, so
pixel parity is not claimed for it; text remained readable. summary.json records
comparison outcomes and request/status/body-byte evidence. All190 tests passed.
