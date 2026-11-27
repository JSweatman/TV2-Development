# Portable, read-only owner review package

This replaces the upload-lab dependency **for this sample package only**. The normal
app entrypoint, live resolver, owner experiments and other drafts are unchanged.
`tool/portable_visitor_preview.dart` runs the actual TV2App with a sample ResolverApi
adapter containing only `1*700001` and `1*70002`. It performs no API requests. All
video and website URLs derive from the current HTTPS origin. The application still
executes its normal prefix/selection/ENTER logic; the adapter is immutable synthetic
data, not evidence that a hosted resolver or business owner onboarding exists.

## Canonical build/package

Use an isolated Flutter scaffold; do not regenerate platform files in the repo:

```sh
flutter create --platforms=web --project-name tv2 /tmp/tv2-portable-web
cp -R TV2_flutter/lib TV2_flutter/tool /tmp/tv2-portable-web/
cp TV2_flutter/pubspec.yaml /tmp/tv2-portable-web/
cd /tmp/tv2-portable-web
flutter pub get
flutter build web --release --no-web-resources-cdn --base-href /app/ -t tool/portable_visitor_preview.dart
```

From the repository root, choose a fresh output directory:

```sh
python scripts/portable_review/package.py /tmp/tv2-portable-web/build/web /tmp/tv2-owner-private-review
```

The resulting ZIP contains only `www/` (compiled app, guide, sample destination and
generated eight-second MP4), `README.txt` and `MANIFEST.json`. Source maps are omitted.
No upload handler, session, token, secret key, executable host, real contacts,
production endpoint, backend or source tree is included. The script rejects unwanted
extensions and known live/lab references, validates ZIP inventory and supplies each
file's SHA-256. Inspect the manifest and verify all hashes after extraction.

Serve **only `www/`** at the root of a separately approved owner-private HTTPS host.
Open `/` on the phone, then the guide's `/app/` link. Any valid HTTPS DNS origin is
supported; numeric IP, localhost, HTTP and file origins fail closed. This intentional
portability is not authorization to publish. The host must restrict the guide, app,
website and media to the owner, supply correct MIME types, no-store and MP4 Range
responses, and reject writes. No CORS exception or proxy to production is needed.
The archive supplies no authentication; it is NOT an already private or published URL.

## Local verification

```sh
python scripts/portable_review/test_host.py
python scripts/portable_review/browser_proof.py EXTRACTED_PACKAGE/www EVIDENCE_DIR
```

The browser proof needs existing Playwright/Chromium and openssl; it reuses the
isolated ephemeral-certificate test pin and loopback hostname mapping, with no global
trust changes or request interception. Its test server is read-only static delivery,
not the local owner/upload lab. It is a verification tool, not a proposed hosted service.
HTTP tests cover GET/HEAD, start/open/suffix ranges, invalid/unsatisfiable ranges,
traversal/unknown paths and rejected write methods. Flutter tests cover the two-record
adapter, qualification, no contacts, same-origin resource construction and origin guard.

The mobile browser flow exercises guide → clean account-free launch → immediate
ENTER → actual video playback/landscape/portrait → WEBSITE popup and return → qualified
fill-only selection → personal sample → refresh/country retention → unavailable retry.
It verifies all app/media requests stay same-origin, media waits for opt-in, no autoplay,
no owner/API endpoints, no CORS, Range 206 and a blocked insecure-origin app.
No physical phone/installed-PWA, owner authentication or actual hosted publication is claimed.

## Delivery boundary

This turn prepares and transfers the private archive only. An approved owner-private
HTTPS destination remains required before Jair can open the app on a phone. Do not
create a public preview, activate storage/auth, deploy the upload lab, or treat download
of the ZIP as delivery of a working phone URL. Library errors/denials stop that transfer
path; there is no alternate public upload or private URL guess.

## Validated artifact and evidence

`tv2-owner-private-review.zip`: **14,207,229 bytes**, 45 files.
SHA-256: `3f719f2defb4884a8b017dc34499ba71ac97bb3f9ac495b20be7f0b24540d069`.
ZIP integrity, exact inventory and every extracted file's size/hash were verified.
The package was tested after extraction, not against the upload lab.

All **113 Flutter tests** passed; the portable release build and read-only host
contract test passed. Chromium 156 at 390x844 passed the complete described flow,
with 844x390 video expansion retaining the same DOM element. `/owner` and
`/v1/resolve` return 404; writes return 405; MP4 Range returns `206 bytes 0-15/93094`.
All visitor requests stayed same-origin; the HTTP-origin app blocked itself before
media/API use. Screenshots were visually inspected locally. See `portable-result.json`.

## Separate Alex destination review candidate

The portable adapter now maps only Alex (`1*70002`) to `/alex.html`, a fictional
personal bio-links page with working same-page About, Small projects and Favorite
things links. Northstar (`1*700001`) retains `/sample-website.html`. No contacts,
forms, signup, transactions, external links or new services were introduced.
The guide distinguishes the personal example. The original delivered ZIP is preserved;
this candidate is not an update to any hosted preview.

`tv2-owner-private-review-alex.zip`: **14,208,372 bytes**, 46 files.
SHA-256: `495e2ba433b22098f98a967647329f44e9730f75deb0ab456bb3ad386b72d43e`.
Every extracted hash and exact archive inventory passed validation. Byte comparison
against the original ZIP confirmed Northstar's HTML and MP4 are unchanged.

The focused adapter/origin tests, all 113 Flutter tests, read-only HTTP contract test
and portable release build passed. The exact extracted-package HTTPS Chromium flow
passed both distinct WEBSITE destinations, Alex's section link, popup close/return
to each listing, Alex's retained keypad query, existing video rotation, origin guard
and same-origin-only requests. Screenshots were inspected locally; see `alex-result.json`.
This remains browser automation, not physical-phone or installed-PWA verification.

## Northstar class introduction candidate

This asset-only sample update makes Northstar a fictional beginner woodwork class:
make a small shelf with a tutor, bring closed-toe shoes and a water bottle; the
class supplies wood, tools and eye protection. The WEBSITE answers “What should I
bring?” and includes the full introduction under “Words from the video.” The
transcript is accessible HTML on the nearby WEBSITE destination, not a new inline
player control. No booking, date, price, contact or real class is implied.

The silent introduction is original local text/shapes rendered using the installed
DejaVu Sans font and ffmpeg: **16 seconds, 768x432, H.264, no audio track**. Four
four-second scenes use legible on-frame captions. All scenes were inspected at
336x189 (mobile inline size); full decode passed. No paid voice, external image or
real business media is used. `northstar_content.py` keeps the caption text and HTML
transcript together. The guide has one primary cue: open TV2, choose +1, type
700001 and press ENTER, with qualification and Alex under a secondary disclosure.
This is guided self-serve review, not evidence of uncoached human first use.

`tv2-owner-private-review-northstar.zip`: **14,178,975 bytes**, 46 files.
SHA-256: `a7fc321d7906356abfda7c5dce56c9a6ef0b9face2515f3d0de76aa624312525`.
All extracted hashes and ZIP inventory were verified. Every compiled Flutter app
asset and the distinct Alex page are byte-identical to the prior Alex candidate;
production code and the sample resolver were not changed. The existing tested
release build was reused rather than altering the genuine TV2 UI.

Focused Flutter adapter/origin tests and the HTTP contract test passed. The exact
extracted-package HTTPS Chromium proof passed video playback/rotation/return,
both distinct WEBSITE destinations, the promised bring-answer and HTML transcript,
Alex's links/return, same-origin-only requests, no autoplay and the insecure-origin
guard. MP4 Range returned `206 bytes 0-15/68191`. See `northstar-result.json`.
No physical device, installed PWA or actual visitor test is claimed. This is a new
separate private review archive; no current Site, prior artifact or public service
was replaced or deployed.

## Explicit pause at WEBSITE handoff (November 20)

A valid public-link tap now requests a pause from this listing's own inline
player before calling the existing URL launcher. The pause is not awaited, so
opening the external URL stays in the original user gesture. Invalid links do
not pause; unloaded/already-paused players are unchanged. Launch refusal retains
the existing fallback and leaves playback under the user's control. No destination
monitoring or return-triggered playback was added.

116 Flutter tests pass, including successful/refused launch, invalid URL and
non-playing cases; the static-host test passes. The rebuilt extracted package
passed the full local Chromium proof at 390×844: playing at 1.0209s, paused at
1.0499s when WEBSITE opened, still paused at exactly 1.0499s after closing the
popup and waiting, then advancing to 1.2837s only after explicit Play. No
visibility events fired. The video element, Northstar listing and qualified
identity were preserved; the class supplies answer opened correctly. Rotation,
Alex destination/return, input, range/no-store and isolation regressions passed.
[Result](handoff/result.json), [paused return](handoff/handoff-return-paused.png).
This is automated local Chromium evidence, not phone/installed-PWA acceptance.

The separately prepared local candidate is `tv2-owner-private-review-handoff-v2.zip`
(46 files, 14,179,000 bytes), SHA-256
`74d6e92c3349da59812c10df7bddfe17d6951492cf2d3b2281fb1e4a5f8f8552`.
It was built with the documented `/app/` base path and inventory/manifest checked.
An initial local build with the wrong root base path was rejected by browser QA;
that earlier candidate is not the validated deliverable. The original Northstar
ZIP (`a7fc321d7906356abfda7c5dce56c9a6ef0b9face2515f3d0de76aa624312525`)
and owner-hosted build are unchanged. This candidate has not been uploaded,
published or deployed; replacing any hosted review requires a separate action.

## Installed-PWA rotation candidate

The portable packager sets only its copied `www/app/manifest.json` orientation to
`any`. The default/public PWA manifest and native files are not changed. Existing
relative `start_url: "."`, inferred identity/scope `/app/`, standalone display and
icons remain intact. The root `/` is a review guide, not the installed app entry.
This permits rotation where the browser/OS supports it; it does not force device
orientation or prove an installed app's behavior.

Run the regression against the actual compiled release build before delivery:

```sh
python scripts/portable_review/test_package.py /tmp/tv2-portable-web/build/web
```

It runs the real packager and verifies ZIP inventory/hashes, the app index/base
path/bootstrap/manifest link, resolved launch/identity/scope, orientation, icons,
guide separation, and that packaging leaves the input manifest unchanged.
Then extract the candidate and run the existing HTTPS browser proof as above,
including explicit WEBSITE pause, return and user-controlled resumption.

### Separate actual-device acceptance (not yet performed)

On each approved phone, use a fresh test installation of the exact candidate;
keep any original TV2 installation untouched. Record OS/browser and candidate
identity. Any hosting sign-in is separate from TV2, which needs no account.

1. Open `/app/` through the guide and add that app to Home Screen. Launch its icon:
   it must open the keypad, not the guide. Record standalone/browser presentation.
2. Open Northstar, explicitly load/play video, rotate to landscape and return to
   portrait. Check aspect ratio, accessible exit and playback position. OS rotation
   lock and browser support can affect this; browser viewport automation is separate.
3. Open WEBSITE during playback, verify the class-supply answer, return and confirm
   the same listing stays paused until explicit Play.
4. Open Alex, Save, close and relaunch the installed instance. HOME → Bookmarks →
   Alex should fill `1*70002`; ENTER should open Alex's distinct personal page.
   Record storage behavior inside that installation, not a separate browser session.

No device installation, hosting/access change or publication is performed by this
packaging task. Existing delivered archives and hosted Northstar remain unchanged.

Validated local candidate: `tv2-owner-private-review-orientation-any.zip`,
14,178,989 bytes / 46 files, SHA-256
`f17338a1734483561ff3a68418360dfa0a3e5e9ceddffa07941b4728001474ab`.
The release build, two focused Flutter tests, read-only host test and real-build
packaging regression passed. Every final archive entry/hash was checked before
extracting it for Chromium 156. At 390×844 (and 844×390 viewport rotation), the
existing complete browser journey passed: immediate/fill-only ENTER, both distinct
sample destinations, country retention, origin isolation and media opt-in/Range.
WEBSITE paused at 1.0557 seconds, returned on the same video element at 1.0557,
and advanced to 1.296 only after explicit Play. The landscape frame was contained
at 608×342 for the 768×432 source, with explicit exit and same-element portrait
return. These viewport results do not establish Home Screen installation behavior.
