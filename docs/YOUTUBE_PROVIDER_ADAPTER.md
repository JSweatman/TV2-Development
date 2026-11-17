# Opt-in YouTube listing video (local review)

This increment extends the #45 themed listing and local typed EMAIL branch. It is separate from owner-uploaded MP4 and keypad tutorials. No production/default listing is configured, no dependencies were added, and no remote data or settings were changed.

## Contract and consent

A trusted listing publisher may supply exactly one resource with `type: provider_embed`, no URI, and metadata exactly `{"provider":"youtube","video_id":"M7lc1UVf-VE"}`. This ID is YouTube's official documentation sample, used only in tests and the explicit loopback preview entrypoint. An ID is exactly eleven ASCII letters/digits/underscore/hyphen. URLs, HTML, query options, additional metadata and ambiguous multiple resources cannot create a player. Validating an ID does **not** establish ownership or approval: approval remains the trusted publisher's responsibility; this patch adds no publishing endpoint or permissions.

In the normal JavaScript PWA build, Load creates a canonical `https://www.youtube-nocookie.com/embed/ID?autoplay=0&playsinline=1` iframe. There is no provider request before the visitor clicks Load (or explicitly chooses the browser link). The visitor then presses Play in YouTube's own player. Camera, microphone and autoplay are denied; no JS player API, credentials or arbitrary embed markup is used. Dismiss, route coverage and app inactivity remove the frame. Reload requires another opt-in. No claim is made that privacy-enhanced mode avoids all provider tracking or network activity.

The frame retains at least 200×200 pixels. Below the minimum width, native builds, and the WASM fallback use the explicit Open on YouTube link. The existing HTTPS launcher opens only a canonical watch URL; launch failure shows the URL for manual use. Valid uploaded MP4 keeps priority and its existing consent/player behavior. Unconfigured and unsupported media retain their prior placeholders; six actions and EMAIL/CALL/TEXT are unchanged.

## Official requirements consulted

- [YouTube embedded-player parameters](https://developers.google.com/youtube/player_parameters): iframe form, sample ID, autoplay, playsinline and minimum viewport.
- [Embedding and privacy-enhanced mode](https://support.google.com/youtube/answer/171780): youtube-nocookie domain and provider restrictions.
- [Required minimum functionality](https://developers.google.com/youtube/terms/required-minimum-functionality): origin identification via HTTP Referer. The frame uses `strict-origin-when-cross-origin`, not a referrer-suppressing policy.

Embedding must also be enabled by the video's owner. Age, region and provider restrictions can still prevent playback. YouTube may navigate within its player or expose its own links; application configuration cannot supply redirects or arbitrary URLs.

## Evidence and reproducibility

`tool/youtube_preview.dart` is a loopback-only actual Flutter TemplateScreen with a synthetic listing and the official sample ID, not a mocked player. Build that explicit entrypoint in a disposable web scaffold, then run `backend/local_media_demo/youtube_proof.py <build/web> <output-directory>` with existing Playwright/Chromium. No browser interception or certificate exception is used. This harness is not imported by the default app.

Recorded Chromium 156.0.8078.79 at 390×844: zero provider requests and zero iframes before Load; canonical frame 318×200 afterward; correct referrer and permission policy; Dismiss removes the iframe and fallback remains visible. Both screenshots were visually inspected for fit and readable controls. See `evidence/youtube-opt-in/result.json` and accompanying images.

**Actual inline playback is unverified:** the environment rejected the provider request with `net::ERR_CERT_AUTHORITY_INVALID`. Testing stopped at that gate; no trust changes, certificate bypass or alternate provider path were attempted. The gray browser error frame is preserved honestly in the after-opt-in screenshot. External watch navigation was not attempted after this gate; its canonical URL routing, success and failure UI are widget-tested with a mock launcher. No native or physical-device playback is claimed.

Five focused tests cover strict reference parsing, opt-in/dismiss/reload/inactivity, native fallback, launcher success/failure, 320×568 at 2× text, minimum player width and uploaded MP4 precedence. All 95 Flutter tests passed; both the explicit sample preview and default PWA release web builds passed (default build: 57.0 seconds). Formatting and git diff whitespace checks passed. The default compiled app does not contain the official sample ID or preview listing name. The SDK analyzer has its existing unnecessary non-null assertion warning plus Material import deprecation information; no analyzer errors.

Remaining acceptance gate: in an environment with ordinary trusted provider access, verify user-initiated playback, provider controls/fullscreen and the real browser fallback with an owner-approved embeddable ID. No hosted activation or content approval is implied by this local adapter.
