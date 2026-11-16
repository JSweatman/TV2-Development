# Original sunset backdrop — issue #34 follow-on

This slice starts from PR #38 head `b0380c6ff17ef4977dcb7283616d4974ae29eee8`.
It does not modify that branch or change resolver/navigation behavior.

## Provenance and visual review

`TV2_flutter/lib/sunset_backdrop.dart` contains newly authored Flutter Canvas
geometry and gradients. All clouds, waves, sun reflection, coastline, trunks,
fronds and leaflets are procedural paths. No image was traced, sampled, cropped,
embedded or downloaded into the runtime. There are no third-party art assets,
new dependencies, external generation services or recurring costs.

The founder's original Library `1661.png` was visually inspected as the
composition/palette reference: dark palms at upper left, violet twilight above
an amber horizon, sun at right and a reflective ocean beneath. That full phone
mockup is not in source or assets. This is an original **stylized vector
interpretation**, not photographic or pixel-level parity. Founder acceptance
of this interpretation remains outstanding.

These generated development renders were inspected at their actual pixels:

- [Portrait scene, 400×900](visuals/sunset/scene-400x900.png)
- [Landscape scene, 900×400](visuals/sunset/scene-900x400.png)
- [Composed home, 400×900](visuals/sunset/home-400x900.png)

These are Flutter widget renders on Linux, using SDK Roboto/MaterialIcons for
review. They are evidence only, not shipped app backgrounds, device screenshots,
or a claim of browser/native visual acceptance. They are not golden baselines.

## Rendering and fallback

`SunsetBackdrop` paints outside the foreground SafeArea, filling the viewport
while the demo panel, independently bounded match list and keypad scroll above
it. Scene landmarks follow viewport proportions; palms use uniform scaling.
The decorative layer is excluded from semantics and ignores pointers. A repaint
boundary isolates the static painter; `shouldRepaint` is false. Rendering uses
finite path/stroke loops, no animation, image decoding, blur or saveLayer.

There is no artwork asset to go missing. Tests supply an asset bundle that
throws on every load and verify zero artwork loads. `showArtwork: false` selects
the solid navy fallback, which is also always painted beneath the scene. This
is an explicit reusable rendering option, not a new user customization UI or
a promise to recover from arbitrary rendering-engine errors.

The existing entry/key surfaces remain. Toolbar and populated matches gain
predictable light surfaces; disabled navigation buttons now keep a visible
light fill on a dark backdrop. Callback and enabled/disabled behavior is
unchanged. Numeric/legend color contrast is checked against the worst-case
white background after alpha compositing, at least 4.5:1, for artwork and
fallback. Standard widget screenshot contrast/label checks remain in the
normal test run. Optional real-font capture mode uses the deterministic color
check because screenshot classification misidentifies the tiny antialiased
period glyph as its border. Real-font review captures were visually inspected.

## Reproduce local renders

With Flutter installed, from `TV2_flutter`:

```sh
flutter test test/sunset_backdrop_test.dart \
  --dart-define=TV2_CAPTURE_DIR=/absolute/writable/review-directory \
  --dart-define=TV2_FONT_DIR=/absolute/flutter-sdk/bin/cache/artifacts/material_fonts
```

Normal tests omit both defines and need no local font paths or screenshot output.
The shared Flutter code remains the Android/iOS/web implementation. No app IDs,
signing, native runners, backend/security policy, HOME destination, deployment,
or physical-device work changes in this slice.

## Validation

Cloud Linux, Flutter 3.50.0 stable (`ab2912035e`), Dart 3.14.0:

- Full shared suite: **49 tests passed**, including #38's compact 320×568 demo /
  ENTER scrolling tests at 1×/2×/3× text, resolver, country, SAVE and navigation.
- Focused real-font review run: **5 tests passed**, with images exported above.
- `flutter analyze`: **no errors**, exit 1 for one existing warning and twelve
  info notices. The #38 baseline has one warning and ten info notices; the two
  added notices are the same deprecated Material import in the new files. No
  new warning/error category. Migration to the newer Material package is outside
  this compatible, dependency-free slice.
- `flutter build web --release`: **passed** in a separate generated runner, not the source
  checkout. No Android/iOS runner or build artifact is added or distributed.
