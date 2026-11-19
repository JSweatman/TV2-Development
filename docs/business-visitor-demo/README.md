# Private synthetic business visitor integration

For the newer self-contained read-only package, see [PORTABLE_REVIEW.md](PORTABLE_REVIEW.md).
The original lab instructions below remain historical local integration evidence.

This branch integrates the actual shared Flutter app from #44 (listing MP4 and
handoffs), #45 (themes), #49 (compact keypad and fill-only selection), #50
(landscape viewport) and #51 (immediate fresh ENTER). It is a review branch, not a
release, hosted demo, or evidence of uncoached human use.

The disposable resolver offers **1*700001 — Northstar Workshop, sample business**
and **1*70002 — Alex, sample personal listing**. These are local synthetic records,
not assignments in any real namespace. Both visitor paths have no account gate or
payment. The business has a generated eight-second MP4, theme and WEBSITE; the
personal example has a separate theme and website. Only configured, valid actions
are displayed. No CALL/TEXT/email contact data is present in these demo records.
The `/review` guide leads with the business benefit: one number opens an introduction,
video and website. It labels the samples and links to the genuine keypad.

## Run and inspect

Prerequisites are the existing Flutter SDK, Python backend requirements plus
Playwright, Chromium, ffmpeg/ffprobe and openssl. No new service, dependency in the
app, or paid tool is introduced. Build a disposable web scaffold (do not regenerate
platform files in the repository):

```sh
flutter create --platforms=web --project-name tv2 /tmp/tv2-business-web
cp -R TV2_flutter/lib TV2_flutter/tool /tmp/tv2-business-web/
cp TV2_flutter/pubspec.yaml /tmp/tv2-business-web/
cd /tmp/tv2-business-web
flutter pub get
flutter build web --release --no-web-resources-cdn -t tool/local_listing_preview.dart
```

From this repository's `backend` directory:

```sh
PYTHONPATH=. python -m local_media_demo.visitor_proof /tmp/tv2-business-web/build/web /tmp/tv2-business-evidence
```

This runs real local `/v1/prefix`, `/v1/resolve`, HTTPS MP4/range delivery and browser
WEBSITE handoff without request interception. It creates an isolated temporary owner
session solely to approve/upload the generated fixture; the separate visitor browser
context has no credentials. The local prefix delay exercises immediate ENTER before
a display name arrives. The owner session is not real Auth or a public onboarding flow.

The established harness maps `tv2-media.example.org` to loopback and pins its ephemeral
certificate only in the isolated Chromium process. It does not install a trust root,
modify global browser settings, or certify hosted TLS. Port 443 must be free and
permitted. All HTTP requests are asserted to stay on that local fixture origin.

On a supported local desktop, add `--review` to run headed Chromium and leave a fresh
visitor window at `/review` after the automated checks. Close it or press Ctrl-C to
stop. Headed review is an optional convenience, not physical-device validation.

## What the integration resolves

- ENTER's fresh-result navigation retains device adapter and route observer wiring.
- The same MP4 panel/controller is reparented for both normal and themed landscape
  views. Exit and portrait return stay on the listing; browser chrome can remain.
- Missing or rejected themed actions are omitted rather than displayed as dead controls.
- #49's selected-error test now expects an explicit retry message and enabled ENTER.

## Boundaries and later private preview packaging

The compiled fixture build must be paired with this disposable resolver/media server;
it is **not** a stand-alone static preview and cannot be copied to an arbitrary origin.
The preview entrypoint explicitly rejects nonlocal/nonfixture origins. A later owner-only
hosted preview needs a separately approved same-origin synthetic API/media destination
and an explicit entrypoint/host contract. Do not point this kit at the production API,
proxy around CORS, upload to a public Site, or treat the build directory as a published link.

The normal `lib/main.dart` entrypoint and hosted resolver are unchanged. This does not
ship business signup/upload, identity ownership, durable storage, provider video,
personalization, payment, ranking, tutorial, or APK delivery. Existing separate owner
proofs remain separate. Shared Flutter source and CI cover platform compilation only;
Android/iPhone/installed-PWA rotation, media policy and external return need device QA.
The eight-second moving test pattern is generated locally by ffmpeg; no third-party,
private or real business media is copied. Test playback speed is slowed for observation.

## Observed verification

- 111 Flutter widget/unit tests passed, including themed controller/position retention,
  compact viewport and enlarged text, fill-only selection and immediate ENTER races.
- 38 backend tests plus 12 subtests passed. Both release entrypoints built on Flutter 3.50.0.
- Chromium 156 passed the complete visitor flow through the real local resolver,
  with a clean account-free launch, immediate ENTER before any preview resolve,
  qualified suggestion selection, actual MP4 playback, rotate/exit/portrait return,
  genuine WEBSITE popup/normal close, listing/keypad recovery, separate personal
  sample and no-match retry. Error-state controls remain reachable by scrolling.
- Same DOM video element retained; 160x90 source contained at 608x342 in an 844x390
  viewport. No autoplay or request before Load. Range returned 206. At 150ms latency
  and 8192 bytes/sec the generated 93,094-byte clip loaded in about 4.5 seconds.
- `result.json` and the four PNGs are synthetic local browser evidence, visually
  inspected. No browser interception, real contacts/media or hosted mutation.

The browser test is headless automation, not an actual first-time visitor, physical
phone, or installed PWA test. The optional headed `--review` path has not been
independently exercised in a desktop session. All existing draft branches are intact.

Verified local compiled preview: 41 files / 42,552,815 bytes. `main.dart.js`
SHA-256: `75f786080ffb19e7f7e01f032874c9bfbedf0e654857851bd7c9c9a52ac10b8c`.
The evidence's “production /v1” label refers to reuse of the production route
functions in the **local** server, never calls to the hosted resolver. The fixture
entrypoint uses only its own origin. The final personal page omits the unused media
placeholder; the approved keypad tutorial placeholder remains unchanged.
