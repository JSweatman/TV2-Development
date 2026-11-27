# Root PWA orientation — review only

Baseline: #74 d001a4d8d1ed8ebdfa1b64de485cf57f275c37b4. No deployment or installed-PWA state changes.

Confirmed actual output, not template inference:
- GitHub run 45931351373, artifact 15168577451 downloaded through authorized connector. ZIP SHA-256 add68378e07c189bb611897135ca374b77c3d7a60b57e2d3493a6ced39d95233. Its root manifest declares orientation portrait-primary.
- Retained normal-entrypoint Flutter 3.50.0 Render-style release output from aa269559a7fabafa4fae49d6894f691142ea940a also declares portrait-primary. This is local recipe evidence, not a read of the current hosted deployment.

Fix: track TV2_flutter/web/manifest.json with only orientation changed to any. Existing Flutter create generates absent runner/icon files but preserves this manifest, so GitHub and the recorded Render recipe consume one version-controlled source without a Render setting change. Both exact scaffold forms were executed with Flutter 3.50.0 and retained the manifest SHA-256 f99a36f72deb1721c84eacaea2a3fc12e02bf01f5cf35e17b01485a4942a44d7:

    flutter create --platforms=web --project-name tv2 .
    flutter create . --platforms web --project-name tv2

Normal release build passed:

    flutter pub get
    flutter build web --release --dart-define=TV2_API_BASE_URL=https://tv2-development.onrender.com
    python3 ../scripts/check_root_web_manifest.py build/web

The build does not contact the resolver. No tutorial is configured. Postbuild values match the tracked manifest exactly. start_url '.', standalone display, tv2 labels, colors/description, absent explicit id/scope and all icon definitions remain unchanged. All four emitted icon files are byte-identical to the downloaded #74 artifact. Root index.html references manifest.json; no portable /app/ launch or guide is substituted.

Four packaging tests pass, covering correct output and rejected orientation, identity/start/scope/name drift, missing icons and missing manifest linkage. Six existing listing-landscape widget tests pass, including same-player portrait/landscape return. CI now executes the manifest tests and postbuild assertion; no hosted job was triggered in this pass. There is no Dart/native/signing/version change.

Limits: no fresh Chromium synthetic-media run in this pass; widget rotation does not establish browser or physical rotation. No Home Screen installation, manifest-update propagation, OS orientation preference or iPhone/Android acceptance has been tested. Browser/OS may control orientation despite manifest any. Prior portable Northstar /app/ evidence is separate. Future acceptance should install/relaunch the exact candidate on each platform and rotate an explicitly playing listing video, check pause/exit/portrait return, and preserve existing saved data; do not clear stable app storage to obtain a pass.
