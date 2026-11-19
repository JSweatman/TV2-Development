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
