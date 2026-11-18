# Listing MP4 landscape viewport

Stacked on draft #44, `7b7d16303c9dcda76873982038fc02248fc8c3bf`.
Only listing MP4 playback changes; keypad/tutorial and provider embeds are untouched.

An actively playing, initialized inline video expands on a portrait-to-landscape
viewport transition. The same panel state, controller and video widget are reparented
into the listing's safe app viewport. The image is contained at its source aspect
ratio; Pause/Play and Exit expanded video remain outside the image. Returning to
portrait restores inline playback. Exit (or system Back while expanded) restores
the listing without navigating away or restarting playback. A paused or never-started
inline player does not expand. Expansion errors return to the inline retry UI;
route changes pause playback and disposal releases the controller.

This is responsive app layout, not browser fullscreen or an OS orientation request.
Browser chrome can remain visible, and viewport resizing can trigger the same behavior
on desktop. Starting playback while already in landscape stays inline until a later
portrait-to-landscape transition. Pausing while expanded keeps the accessible exit.
Large text can scroll the controls rather than crop the picture or hide the exit.

## Reproduce

Run `flutter test` from `TV2_flutter`. The focused `listing_landscape_test.dart`
checks controller/position retention, 16:9 containment, explicit exit, system Back,
never-started/paused behavior, error collapse/disposal and 568x320 at 2x text.

Build the existing `tool/local_listing_preview.dart` entrypoint in a disposable
Flutter web scaffold, then from `backend` run:

```sh
python -m local_media_demo.browser_proof WEB_BUILD OUTPUT_DIR --landscape
```

This extends #44's existing synthetic local HTTPS proof; it does not contact hosted
services. The existing harness uses an ephemeral certificate SPKI pin in its isolated
Chromium process (not ordinary public CA verification), separate owner/viewer contexts,
real local resolver calls and byte-range media delivery, without request interception.
The one-second generated blue clip is slowed only by the test for observation.
No certificates, sessions, browser outputs or media are added by this patch.

## Physical device acceptance (not yet performed)

Repeat separately in Android Chrome, iPhone Safari and each installed PWA:

- Open a synthetic listing in portrait. Load must not autoplay; rotating before Play
  or after inline Pause must not expand.
- Play, rotate landscape, confirm continued position/audio and uncropped image.
  Check browser chrome, notches/safe areas and readable Pause and Exit controls.
- Pause/resume expanded; Exit must preserve the listing and position. Repeat rotation,
  then return portrait; playback must remain the same session.
- Check system Back exits expanded first, listing back returns to the retained keypad,
  backgrounding pauses, and leaving the listing releases playback.
- Repeat with enlarged text, short viewport, orientation lock and media/network error.

No physical Android/iPhone, installed PWA, production hosting or native fullscreen
results are claimed. This patch does not activate media, change auth or resolver rules.

## Recorded local verification

All 81 Flutter tests passed, including five focused landscape tests and a pushed
route with a non-void result. Flutter 3.50.0 release builds passed for the default entrypoint and the existing
local fixture entrypoint. Chromium 156.0.8078.79 passed at 390x844 portrait and
844x390 landscape: same DOM video element and continuing position, 608x342 image
from a 160x90 source, explicit exit, paused rotation stays inline, portrait return,
no browser fullscreen request, and video element removed after dismiss. Screenshots
were visually inspected. The existing proof also passed no media before Load, no
autoplay, local exact resolver round trip, viewer write denial and Range 206 under
150ms latency / 8192 bytes/sec. This is a local browser test, not hosted/device evidence.

Local `flutter analyze` could not start: the analyzer attempted to create
`/home/agent/.dartServer` on a read-only filesystem. No permission change was made.
