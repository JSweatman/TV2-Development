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

No remote PR or deployment is created for this local-only continuation. The
smallest staging go/no-go remains the authorization/infrastructure decision above,
not a claim that these preview routes are production-ready.
