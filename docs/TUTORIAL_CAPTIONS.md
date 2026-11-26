# Optional tutorial captions and transcript — issue #32

Base: main `9f8e7a3cb325a20abb0c2e1ade60da16c4e80392`.

This bounded slice adds **Show captions / Hide captions** and **Show transcript**
to the existing one-video panel. No tutorial URL still means only the original
noninteractive placeholder. No media or caption content is enabled by default.
No dependency, toolchain, platform target, service, permission or workflow changes.

## Build-owned configuration

`TV2_TUTORIAL_URL` retains its explicit approved HTTPS URL contract.
`TV2_TUTORIAL_CAPTIONS_VTT` is the matching WebVTT **text**, not a URL or path.
An operator can supply both strings in an approved JSON file using Flutter's
`--dart-define-from-file` option. JSON represents line breaks as `\n`. Neither
field should contain secrets: build defines are included in client output.
The application does not fetch captions, load an asset, or discover a remote
caption service. An empty tutorial URL disables the entire panel even when
caption text is supplied. No hosting or staging configuration is changed.

The built-in video_player 2.9.5 `WebVTTCaptionFile` parser is reused, checked
against the installed package source and the [official Flutter package source](https://github.com/flutter/packages/blob/video_player-v2.9.5/packages/video_player/video_player/lib/src/web_vtt.dart).
The optional text is parsed only after Show captions or Show transcript.
The panel rejects a missing WEBVTT header, empty/partially malformed cue sets,
empty cue text, reversed/zero duration, overlapping/out-of-order cues, more than
200 cues, or more than 65,536 Dart string code units. This is a simple ordered
single-language track; styling, regions, positioning and multi-track selection
are outside this slice. Use plain-text cues. Content review must verify that all
spoken words and meaningful sounds are represented and that visual information
has an appropriate text alternative. The fixture is not approved tutorial text.

## Behavior and accessibility

- Captions start off. Show captions enables text synchronized to the controller's
  media position, with half-open cue ranges (start inclusive, end exclusive).
  Text appears below the video, wraps, follows text scaling and uses white on
  the existing dark surface. It does not cover the video or keypad controls.
- Cue text clears during gaps, completion, failed video, and dismissal. Position
  notifications also update the text after seeking/replay; no extra timer or
  background polling is introduced. Timing follows the plugin's position updates
  (approximately 100 ms while playing), not a frame-accurate subtitle clock.
- The transcript is selectable plain text in a scrollable, titled dialog, with
  a keyboard-focusable Close transcript action and Escape dismissal. It can be
  opened without loading video, including when video failed. Opening it pauses
  playback; closing does not resume automatically. It snapshots the current
  approved cue text so config changes cannot invalidate an open dialog.
- Dynamic captions are not an assertive/live announcement stream; users can
  pause and read them or open the full transcript. No screen-reader/device
  acceptance claim is made solely from widget or desktop browser tests.
- Missing text shows a noninteractive unavailable-configuration message. Invalid
  text shows a sanitized error on opt-in, without preventing video or lookup.
  Video retry retains the caption choice and transcript availability. Dismiss
  and a new configuration reset caption state; reopen needs a fresh opt-in.

## Validation and boundaries

Tests use only `test/fixtures/tutorial_captions.vtt` (two synthetic cues) and the
existing silent blue test pattern. Neither fixture is declared as a Flutter
production asset. The private navigation review MP4/VTT is not used or modified.
Focused widget coverage includes missing/invalid configuration, cue boundaries,
no player allocation for transcript-only use, keyboard navigation, 320×568 at
1×/3× text, dismiss/reopen, video failure/retry, and lookup under simultaneous
caption/video failure. Default release web builds contain no configured media.

One approved language/track per video only. The optional three-video sequence,
content approval, screen-reader acceptance on Android/iOS, and physical-device
playback are separate work. No free-account or personalization behavior is added.

Verified for this slice: 24 focused tutorial tests and all 78 Flutter tests pass.
The default PWA release build passes with no tutorial defines. Analysis reports
18 findings (no errors): 17 existing findings and the same Flutter Material
import deprecation info in the new test.

Chromium 156.0.8078.79 exercised the actual panel in a local release harness with
the synthetic blue clip and VTT. Transcript-only use made no media request.
First and second cues appeared, completion cleared the cue, and dismiss/reopen
reset the opt-in. Browser playback was slowed to 0.25× for reliable observation
of the 400 ms synthetic cues; the second cue was observed at media time 0.4665 s.
The transcript was exposed as readable text rather than a disabled text field.
Representative caption and transcript screenshots were visually inspected.
This is desktop browser evidence, not staging, native-device or screen-reader
acceptance. The release harness and test clip are outside the shipped build.

## Single-line build transport

For SDKs whose compiler rejects multiline `-D` values, supply
`TV2_TUTORIAL_CAPTIONS_VTT_BASE64`: standard Base64 of the UTF-8 WebVTT file.
This is encoding, not encryption; never include secrets in client defines.
Raw `TV2_TUTORIAL_CAPTIONS_VTT` remains unchanged and takes precedence when
nonempty. Literal backslash-n text is not converted. Do not set both forms.
Invalid encoding/UTF-8 or excessive size produces the existing sanitized caption
error on opt-in; it cannot prevent video or keypad use. No URL still disables
all tutorial UI. No caption network request is introduced.

Example local config generation (approved files only, outside the repository):

```python
import base64, json
from pathlib import Path
config = {
    "TV2_API_BASE_URL": "https://your-approved-resolver.example",
    "TV2_TUTORIAL_URL": "https://your-approved-media.example/tutorial.mp4",
    "TV2_TUTORIAL_CAPTIONS_VTT_BASE64": base64.b64encode(
        Path("approved.vtt").read_bytes()).decode("ascii"),
}
Path("tutorial-defines.json").write_text(json.dumps(config))
```

Build the normal entrypoint with `flutter build web --release
--dart-define-from-file=tutorial-defines.json -t lib/main.dart`.
Do not commit that configuration or media. The unconfigured build retains its
noninteractive placeholder and makes no tutorial request.
