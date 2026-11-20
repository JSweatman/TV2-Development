# Local Flutter owner / allowed-viewer preview

Independent continuation of `b9bdf1b280c67ae8c382cddf0ba3cdc4b7fd242a`.
This is an explicit web-only engineering entrypoint, not normal TV2 startup:

```sh
flutter build web --release --no-web-resources-cdn -t tool/private_media_preview.dart
# From backend/, using the existing disposable local Docker toolchain:
python -m private_media_lab.local_stack --run-local /absolute/new-evidence --flutter-web /absolute/build/web
```

The preview refuses any origin except `http://127.0.0.1:54327`. Normal
`lib/main.dart` does not import it and still opens the registration-free keypad.
No tutorial/media default is enabled. The only shared rendering change is an
optional media widget slot in TemplateScreen; normal rendering/validation is
unchanged when omitted. Owner controls live exclusively in the separate preview.

## Flow and trust boundary

A synthetic owner signs in through the actual local GoTrue password endpoint.
The local gateway holds the access token only in process memory. The browser gets
an opaque HttpOnly, SameSite=Strict session cookie, not a provider token; no token
or password enters URLs, screenshots, localStorage or the Flutter UI. Password
fields clear after every attempt. Test sessions are discarded at stack teardown.
The HTTP cookie is intentionally loopback-only; reviewed TLS/Secure-cookie and
session-expiry/revocation policy remain mandatory before staging.

The owner selects a local synthetic MP4, uploads a **private draft**, then presses
**Publish listing video** separately. File extension/size checks improve feedback;
the server remains authoritative for actual media validation and exact ownership.
A different synthetic viewer signs in in an independent browser context and sees
the actual #45 graphite themed TemplateScreen, six unconfigured actions, and a
private video widget. Load fetches authenticated media; a separate Play gesture
starts playback. No direct private Storage URL or bearer credential is handed to
the video widget. The media request uses the same-origin HttpOnly session cookie.

Writes require the exact same Origin. The gateway strips caller-supplied bearer
headers, verifies the server-held identity, and leaves exact-listing owner/viewer
authorization to the tested private service. It exposes no signup, owner-assignment
or grant-management endpoint. The public read-only resolver remains separate.

## Cancellation, failure and limits

Cancel aborts the client upload and ignores late results. A request already accepted
by the server may leave an unpublished private draft; cancellation never triggers
publication and the UI states the cleanup limitation. Publication is a distinct
non-cancellable action to avoid falsely promising rollback after a server commit.
Errors do not auto-retry or auto-publish. Denied/invalid sessions allow sign-out
and a new sign-in. File-selection cancellation and invalid files do not upload.
Video failure leaves the listing usable; Dismiss releases the controller, and
backgrounding pauses it. Returning to normal TV2 needs no preview session.

This preview uses the existing Dart web file-input API without a new dependency.
The JavaScript release build is the target: the SDK emits its legacy `dart:html`
WebAssembly dry-run warning. No WASM or Android/iOS file picker, native session,
APK or physical-device result is claimed. No deployment or hosted mutation occurs.

## Smallest independent staging gate

**No-go until root approves and verifies an authoritative owner-to-listing binding
and explicit allowed-viewer policy on an isolated, authenticated staging gateway.**
The existing public preview endpoints must not simply mount these local routes.
TLS/Secure cookies, bounded session lifetime/revocation, server secret handling,
isolated ingest and orphan cleanup must be reviewed there. That approval is
separate from this local UI proof; it does not require more visual/theming work.

The original private-storage gate's [remaining prerequisites](../private-media-integration/README.md)
still apply. #43/#44/#45 and the five-number kit stay unchanged.

## Observed verification

- **90 Flutter tests passed**, including seven focused preview widget tests.
  The owner flow is reachable at 320×568 and 2× text with no overflow; ordinary
  first-use, theme and keypad regression tests pass.
- **55 backend tests + 12 subtests passed**, including exact ownership, cross-listing
  denial, invalid session, Origin enforcement, cookie secrecy, ingest validation
  and provider failures.
- Preview and **default** release web builds passed. Analysis has no errors;
  it reports one pre-existing `saved_collections.dart:140` warning plus 24 info
  diagnostics (including the current SDK's Material deprecation notices).
- Chromium 156 at **320×640** completed actual Flutter owner sign-in, file picker,
  upload cancellation, retry, separate publication, and separate allowed-viewer
  sign-in and themed inline playback against real local GoTrue/Storage.
- There was no autoplay. Viewer upload returned **403**. Invalidating the
  server-side owner session caused a visible recoverable denial in the Flutter UI.
  The browser held only opaque HttpOnly session cookies, no provider token strings.
- No request interception, hosted data/configuration change, device test or APK.
  The runner removed its containers, volumes, network and identity metadata.

[Machine-readable result](evidence/result.json), [owner publication frame](evidence/flutter-owner.png),
and [actual themed Flutter playback](evidence/flutter-viewer.png) are retained and
were visually inspected. Browser bulk `fill()` intermittently left Flutter's
password controller empty; the repeatable proof uses focused keystrokes and Tab,
not an auth shortcut. Browser evidence comes from the fixed release artifact.

This work is packaged as a stacked draft for review only. The
[private-stage checklist](PRIVATE_STAGE_GATE.md) records the authorization and
infrastructure gates; draft publication does not activate these routes.

## Portrait ingest regression (November 20)

The shared local MP4 validator now bounds the **long side at 1920 and short side
at 1080**, rather than rejecting every encoded height above 1080. The original
validator rejected a generated upright 720×1280 H.264 clip with `Unsupported
video`. Duration (30 seconds), upload bytes (5 MiB), codec/track restrictions,
identity checks, private storage and explicit publication are unchanged.

`test_real_encoded_dimensions_in_both_orientations` runs real ffmpeg/ffprobe for
1280×720, 1920×1080, 720×1280 and 1080×1920 acceptance and for over-limit long
or short sides in both orientations. Full backend regression: 56 tests and 20
subtests passed. The Flutter proof now generates a labeled portrait clip (green
TOP, navy PORTRAIT, red BOTTOM), selects/uploads/publishes it through the real
owner UI, and checks 720×1280 inline playback in a separate allowed-viewer session.
It retains cancellation, no-autoplay, forbidden viewer upload and invalid-session
checks. Rotation metadata is **not exercised**: this is encoded upright video.

The browser proof uses the retained verified private-preview release build;
Flutter source is unchanged from `348f3610b337d61dca413d1b2af9a16fb78036d2`.
Its `main.dart.js` SHA-256 is
`017922446beea1abf542a9676a1a4aeac256bde9a7cb53318cd2d9de15c0f537`.
A fresh SDK invocation in this executor fails trying to create
`/home/agent/.dart-tool` on a read-only filesystem. No Flutter source or dependency
changed in this fix. These are local Chromium and disposable GoTrue/Storage
results, not physical-phone, hosted TLS or production ingest acceptance.

The final 320×640 Chromium 156 frame was visually inspected: TOP, PORTRAIT and
BOTTOM are upright and entirely visible with Pause/Dismiss, after ordinary
listing scroll. [Result](evidence/portrait/result.json) and
[viewer frame](evidence/portrait/flutter-viewer.png) contain only synthetic data.
The local runner removed its containers, volumes and identity database afterward.

## Upload validation guidance (November 20)

The preview HTTP adapter carries status codes only, never backend response text.
Upload 413 explains the byte limit; 415 requests MP4; 422 explains H.264, optional
AAC, duration, bytes and portrait/landscape dimension limits. A 401 asks for a new
session; 403 states permission denied without assuming expiration. Other failures
use a fixed retry message. Publish failures cannot receive upload-format guidance.
The picker, server rules, publication and cancellation controls are unchanged.

Fresh local release preview: a generated MPEG-4 Part 2 video in an MP4 container
returned 422 while signed in. The actual Flutter UI showed validation guidance;
the owner selected the valid upright H.264 portrait replacement, uploaded and
explicitly published without another sign-in. A separate allowed viewer played
720×1280 inline. Invalid owner session showed the distinct session message;
viewer upload remained 403; cancellation never published and no autoplay occurred.
[Result](evidence/validation-guidance/result.json),
[validation guidance](evidence/validation-guidance/invalid-clip-guidance.png),
[replacement playback](evidence/validation-guidance/flutter-viewer.png).

94 Flutter tests passed, including replacement/session retention, fixed status
messages, non-echoing generic errors, late cancelled failures, and 320×568 at 2×
text. Backend: 56 tests and 20 subtests passed. This pass built the preview afresh:
for this executor, `env -u HOME XDG_CONFIG_HOME=/workspace/config
PUB_CACHE=/workspace/pub-cache flutter ...` avoids analytics initialization in the
read-only home directory. No filesystem permission or browser trust change.
No HEVC/MOV support added; rotation metadata and physical phones remain untested.
Both fresh preview and default PWA release builds passed locally.

## Manual selected-file preview (November 20)

Only the disposable web owner entrypoint supplies the selected-clip player.
Selecting a valid-size MP4 exposes **Load selected preview**, then **Play selected
clip**; it never autoplays. The browser-local blob is not uploaded, and playback
is explicitly not server validation. Browser decoding failure has local guidance;
server rejection retains the existing fixed validation messages.

Starting a replacement immediately removes the old player and uploaded draft,
including while the picker is pending. A cancelled/late picker cannot restore it.
Replacement, cancellation, sign-out, dismissal and disposal release the controller
and revoke its object URL. Cancelling an upload retains the file for an explicit
retry but resets its local player; it never restores a publishable draft. Upload
and Publish remain separate actions, with existing access and limits unchanged.

Fresh Chromium 156 at 320×640 played the orange FIRST clip, then the distinct
upright 720×1280 portrait selection. Request observation found **zero upload or
publish requests during preview/reselection**. Fetching the old blob URL failed
after replacement and cancellation; the final blob was revoked on sign-out.
Only the second valid clip was explicitly uploaded/published. An independent
allowed viewer received 404 before publication, then bytes whose SHA-256 matched
that second clip and played it inline. Existing unsupported-upload 422,
no-autoplay, cancellation, viewer-upload 403 and invalid-session checks also passed.
No request interception or hosted provider was used; disposable services and
identity metadata were removed. [Result](evidence/selected-preview/result.json),
[first local preview](evidence/selected-preview/owner-first.png),
[second local preview](evidence/selected-preview/owner-second.png),
[allowed viewer](evidence/selected-preview/flutter-viewer.png).

95 Flutter tests passed, including old-draft invalidation and preview lifecycle;
56 backend tests + 20 subtests passed. Fresh preview web release build passed.
This remains browser-only, with no physical-device or rotation-metadata evidence,
no HEVC/MOV expansion, and no production owner controls.
The fresh default PWA release build also passed; normal startup is unchanged.

## Two independent synthetic listings (November 20)

The same disposable owner/viewer app can now be opened for either fixed fixture:
`http://127.0.0.1:54327/` (Copper, `1*73141`) or
`http://127.0.0.1:54327/?listing=1*73142` (Maple Studio). Unknown fixture IDs fail
closed. The session gateway determines the owner role for that exact selected
listing. The query parameter is **not authorization**: unchanged private-service
checks verify ownership on upload and publication and viewer grants on playback.
No deployed resolver, onboarding API or permission-management route changed.

The existing full local browser proof now seeds two independent synthetic owners
and one viewer granted to both. Both owners select, upload and explicitly publish
through the actual Flutter UI. The viewer plays Copper's upright portrait and
Maple's orange clip. Upload and publication against the other owner's listing are
403 in both directions. Copper's green replacement remains unpublished while the
viewer can still fetch its previous portrait; after explicit Publish, Copper's
bytes change to the replacement and Maple's SHA-256 remains unchanged. The viewer
also plays the new Copper clip. Prior preview/revocation, validation, cancellation,
session-denial and no-autoplay checks run in the same proof.

[Result](evidence/two-listings/result.json),
[Maple playback](evidence/two-listings/second-listing-viewer.png),
[Copper replacement](evidence/two-listings/updated-first-viewer.png).
Observed in Chromium 156 at 320×640 using disposable real local GoTrue/Storage,
without interception. Local services and identity metadata were removed afterward.
96 Flutter tests, 56 backend tests plus 20 subtests, and a fresh preview release
build passed. Physical phones and rotation metadata remain untested.

**Still not self-service:** fixture catalog, accounts, exact owner bindings and
viewer grants are provisioned by the disposable harness. This adds no signup,
listing creation/claiming, invitation UI, production ingest service or hosted
activation. Existing TLS/session/revocation and untrusted-ingest gates remain.
The fresh default PWA release build also passed with normal startup unchanged.
