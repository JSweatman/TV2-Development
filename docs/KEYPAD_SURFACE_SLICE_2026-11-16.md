# Keypad surface first slice — issue #34

Base: `fb8c13f1dc669b3cda5c1c63847446409f38b374` (includes merged PR #37).

The founder reference `1661.png` was retrieved from Library and visually inspected.
It is a complete phone mockup, not a clean licensed background. It is not added to
source. This slice implements the independently specified dark translucent entry
and rounded keypad surfaces, light borders, white digits, purple 2–9 legends,
and green CALL / blue navigation accents. No pixel-parity claim is made.
The newer CALL / HOME / BACK / ENTER order overrides the picture. PR #37's zero
child, OPER legend, callback, and regression tests are retained.

One shared Flutter layout grows and scrolls on compact viewports and enlarged
text. The presentational video module and independently scrollable match list
remain. The home video stays in the scrollable content at all viewport heights,
including compact phones and enlarged text. The match list has its own bounded
72–160px viewport so long result sets cannot push the keypad arbitrarily far down. Country, resolver, persistence, SAVE, Address Book,
clear, and navigation callbacks are unchanged. Launch still goes directly to
HomeScreen and asks for a country on first use, without registration.

## Remaining acceptance work

- Obtain a clean licensed tropical background and implement full-bleed composition.
- Compare baseline screenshots to the founder reference and tune spacing/glow.
- The original surface slice preserved HOME-to-clear behavior. The subsequent
  guest Home navigation slice resolves that mismatch with separate on-device
  Bookmarks and Address Book destinations. Returning preserves dialer input and
  selected NID; only the separate trash action clears the input. Authenticated
  personal profiles remain outside this scope.
- Physical Android, iOS simulator/iPhone, and browser visual acceptance remain
  untested. Automated widget tests and web compilation do not establish those.
- Appearance customization and operator hold behavior remain separate work.

No native identifiers, signing, security policy, dependencies, backend code, or
production configuration change in this slice.

## Local validation

Flutter 3.50.0 stable (`ab2912035e`), Dart 3.14.0, Linux cloud workspace:

- `flutter test --reporter expanded`: **44 passed**, including unchanged OPER,
  navigation order, resolver/country persistence, SAVE and Address Book tests.
- New coverage: all 16 exact callbacks, minimum 48px targets, semantic labels,
  contrast guidelines, 320×568 viewport at 1×/2×/3× text, resolution/open/clear,
  and enlarged offline guidance. The video status label now wraps at large text.
  Compact tests explicitly scroll to both the demo panel and ENTER at all three
  text scales, return to the panel after resolution, and open the listing.
  Existing home interaction tests scroll controls into view before tapping.
- `flutter analyze`: **no errors; exit 1**, one warning and ten info notices.
  Main under the same SDK reports one warning and eight info notices. The warning
  is the existing unnecessary `!` in `saved_collections.dart`; info notices are
  deprecated Material imports and the existing form `value` API. The two new
  files use the existing Material import for project compatibility and therefore
  each add the same SDK deprecation notice. No new warning/error category.
- A release web build is validated in a separate generated web-runner copy;
  generated runners and dependency/build caches are not included in the PR.
