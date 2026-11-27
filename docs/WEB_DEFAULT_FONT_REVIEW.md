# Web-only English default font — local review

Base 5fe22406119435ed87a0af63ccbcebbe94e085da. No push/deployment, hosted calls,
settings changes, native theme change, font-host override or certificate bypass.

## Cause and minimal fix
Pinned Flutter3.50.0 engine canvaskit/fonts.dart loads remote Roboto whenever the
font manifest lacks that family. Prior screenshots showed icons/surfaces but
blank English text; recorded Roboto and fallback requests failed certificate
validation. main.dart uses ThemeData(useMaterial3:true), with no custom family.

Load the original default family Roboto before normal main.dart runs TV2App,
using Flutter FontLoader. Register Regular400, Medium500, Bold700 from the SDK's
licensed material-font archive. Fonts are web-only assets via platforms:[web];
kIsWeb prevents loading on native. No global replacement fallback family,
non-Latin glyph subset/remapping, theme or native font selection change. SDK
asset.dart matchesPlatform excludes web-only entries on Android/iOS (tester
intentionally includes all assets). No native package was built or measured.

These fonts contain896 mapped characters each, including complete printable
ASCII; they are not CJK fonts. The SDK files are Roboto2.137(2017); precise parity
with the external v32 font or all synthesized/intermediate weights is not claimed.
The chosen regular/medium/bold preserve family and common UI weight intent.

## Provenance/license
Flutter3.50.0 bin/internal/material_fonts.version pins:
https://storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/fonts.zip
Official archive downloaded normally and compared byte-for-byte with all three
copied fonts and Roboto_LICENSE.txt. Archive SHA256:
e56fa8e9bb4589fde964be3de451f3e5b251e4a1eafb1dc98d94add034dd5a86

Regular171676 bytes SHA25679e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95
Medium172064 bytes SHA256f205cc511821ea56078a105557fcea6253129404d411c997e1866fbd006abb68
Bold170760 bytes SHA2567d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86

Unmodified Apache2.0 license is bundled as assets/web_fonts/LICENSE.txt and
registered with Flutter LicenseRegistry for the web app. No new dependency.

## Build and observed browser results
Unchanged Render scaffold/pub-get/release command, normal lib/main.dart,
TV2_API_BASE_URL=https://tv2-development.onrender.com, no tutorial definitions or
renderer flags. Separate subdirectory check adds only --base-href /app/.
Root manifest,index and service-worker output remain byte-identical to base;
orientation any, start '.', implicit identity/scope, icons and display preserved.
Total release directory increase534457 bytes; three font response bodies total
514500 bytes. These are local uncompressed body/file sizes, not field bandwidth.

Updated scripts/same_origin_renderer_browser.py blocks renderer CDN and both
fonts.gstatic.com/fonts.googleapis.com. It intercepts the canonical resolver
hostname to disposable synthetic FastAPI/Postgres; real plugin launches are
suppressed solely at window.open. Chromium156.0.8078.79,390x844, fresh profiles.
Root and /app/ tests pass: country picker,+1,1*529 preview,ENTER,listing,
fresh contact availability confirmation,Cancel and explicit final gestures for
CALL/TEXT/EMAIL, Back/reopen. One recipient-only intent each with active user
activation; no OS app or message. Font JS API or Dart launcher not mocked.
All three local TTF requests returned200 at correct root/subdirectory asset paths.

Actual screenshots inspected: picker instructions/countries, +1, ENTER LIST NUMBER,
all digits/letter groups and OPER, Synthetic Contact preview/title, qualified
reference, CALL/TEXT/EMAIL/WEBSITE and email confirmation recipient/buttons readable.
Far-right ENTER remains its existing arrow icon; no new label/interface redesign.
Empty and populated keypads keep bottom actions visible at390x844; this is not a
universal-fit assertion. OCR corroborates selected visible labels but misses some
digits; manual screenshot inspection, not semantics alone, establishes text here.
Default first launch still asks for country; no tutorial configured. Existing
country persistence/layout regression tests pass; no new installed-storage claim.

Full repository Flutter suite:186 passed (including web-default-font native guard).
An initial run included Flutter-create's untracked counter-template test; it was
removed and the full suite rerun successfully. Existing packaging checks retained.
No actual screen reader, physical phone or installed-PWA test.

## Limits
The engine can still attempt its original remote default-font request before
main; it fails harmlessly in these blocked-host tests and local registration then
restores English. This patch does not eliminate every external font request or
provide offline support. Non-Latin fallback configuration/code is untouched, but
working-host CJK parity could not be verified in this certificate-blocked executor;
no broad language claim. Alternate tool/sample entrypoints that bypass main.dart
have not been adapted/tested. Missing/corrupt local font delivery is not tested.

Evidence /workspace/web-default-font-proof: root/sub release outputs, screenshots,
request/intent JSON, OCR text, font hashes, build and full test logs. This is a
local candidate for review, not a deployment or production readiness guarantee.

Official API/docs read: https://api.flutter.dev/flutter/services/FontLoader-class.html
https://docs.flutter.dev/ui/assets/assets-and-images#platform-specific-assets
