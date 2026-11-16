# Optional tutorial player foundation — issue #32

Base: main `3b67ec41175803e7a455ee91df416442fb8e068e`.

## Scope

One optional, explicitly configured video uses the existing keypad media slot.
No configuration means the existing noninteractive COMING SOON placeholder and
no controller or media request. Listing/template media placeholders are unchanged.
The dialer still opens without registration and keeps its independent lookup,
country/NID, SAVE, HOME navigation, and scrolling/bounded-match behavior.

An operator may supply an approved, versioned HTTPS URL through the existing
build/review process using `--dart-define=TV2_TUTORIAL_URL=<approved-https-url>`.
There is no default URL, remote configuration service, public editor or writable
credential. Empty/invalid/non-HTTPS URLs disable the player; user-info credentials
in a URL are rejected. Do not put secrets in a compiled client. No workflow or
staging default is configured by this PR.

Interaction: **Load tutorial** fetches metadata after explicit consent, then a
separate **Play tutorial** press starts playback with a fresh browser gesture.
Loading does not autoplay. Controls support pause, replay after completion,
dismiss, reopen and retry. Loading times out after 20 seconds. Dismiss disposes
the controller; navigation away/backgrounding pauses it and returning does not
autoplay. Controls wrap with enlarged text; the video remains letterboxed in a
16:9 area and the home page can scroll. No fullscreen takeover, microphone,
recording, analytics, account prompts, or cross-session playback state.

## Dependency and compatibility

One runtime plugin: Flutter-maintained `video_player ^2.14.1`; its endorsed
Android, AVFoundation and web implementations resolve automatically. The platform
interface is an explicit **test-only** dependency for the fake backend.

The chosen version requires **Flutter >=3.44 / Dart >=3.12**. The app's declared
minimum is raised accordingly, matching the plugin's published requirements;
this is a toolchain compatibility change. Validation uses Flutter 3.50 / Dart
3.14. Official platform support is Android SDK 24+, iOS 13+, and compatible web
browsers. Older toolchains/platforms are not supported by this slice.

Official references checked during implementation:

- [Flutter video_player](https://pub.dev/packages/video_player): endorsed platforms,
  supported versions, network setup and controller lifecycle.
- [Flutter play/pause guide](https://docs.flutter.dev/cookbook/plugins/play-video):
  initialization, disposal, platform caveats.
- [Web implementation](https://pub.dev/packages/video_player_web): user-gesture
  playback, browser codec variation and HTTP range support.
- [Controller API](https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController-class.html).

HTTPS media hosting must support the target browser's codec/CORS/range behavior.
Native network playback needs existing Internet permission; this PR changes no
manifests, ATS policy, app IDs or signing. Do not weaken transport security.
There is no network-cache/offline guarantee or new media-hosting service.

## Content and acceptance still required

This is a player foundation, **not completed issue #32 or approved training media**.
The first navigation tutorial must be approved and stay within the issue's
60-second limit. No approved tutorial/audio is bundled or enabled. The local
silent blue test clip is test-only; the previous review cut is not included.

Captions/transcript UI, accessible content validation, language selection and
caption metadata are deferred and must be addressed before tutorial-content
acceptance. The plugin offers caption primitives, but they are not wired here.
The optional three-video sequence, next/skip choices, and per-video metadata are
also deferred; this slice only replays/dismisses one clip. Do not enable a free
account/personalization tutorial before those features exist or are explicitly
approved as a forthcoming-feature preview.

Android/iOS playback and physical-device acceptance remain untested. CI native
compilation is not playback or device evidence. Android Preview APK distribution
remains on hold while training media is worked out; this PR distributes none.

## Validation for this slice

- Focused player widget suite: 10 passing tests, including compact 320×568 at
  normal/3× text, keyboard operation, load/play failure and retry, timeout,
  disposal during loading, background pause, route pause, and real app lookup.
- Full Flutter suite: 64 passing tests.
- `flutter analyze`: no errors; 17 findings (one existing warning and 16 infos).
  Baseline had 15 findings; the two additions are the same Flutter 3.50 Material
  import deprecation notice in the new widget and its test.
- Real headless Chromium smoke test of the same TutorialPanel, in a local-only
  harness with the controlled fixture: no video before Load; loaded paused at
  time zero, decoded 160×90; Play advanced currentTime; Pause paused; Dismiss
  removed/disposed the video. Ready-state pixels were inspected. This is desktop
  browser evidence, not native or physical-device evidence.
- Release web build uses the production entry point with no tutorial define.
  The smoke harness and test clip are not included in that output.
