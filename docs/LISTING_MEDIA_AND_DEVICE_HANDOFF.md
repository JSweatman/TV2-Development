# Listing video and device handoff review slice

Base: main `9f8e7a3cb325a20abb0c2e1ade60da16c4e80392`. Independent of draft
PR #43: no tutorial implementation/configuration, dependency, toolchain,
application identity, deployment or database changes.

## Trust boundary and production blocker

The deployed resolver (`backend/src/app.py`) is read-only. Its repository exposes
public listing resources through narrow RPCs with a publishable key. This is not
an owner-authenticated write service. Existing schema/resources are reused as a
**contract**, not modified remotely. The parent's read-only project inspection
reported an `owner_user_id` column but zero assigned owners, zero Auth users,
zero Storage buckets, and no exact `1*5247` listing. This task made no remote
writes or provisioning. A Render resource inspection here returned exactly
“no workspace selected”; no workspace was selected or infrastructure altered.

Consequently the upload implementation is an explicit **local/test-only proof**,
not production ownership authentication. Its application is never imported by
the deployed resolver and cannot be enabled with a production build define.
It needs a caller-injected random local fixture session and binds to loopback in
the runner. The owner context receives an HttpOnly, SameSite=Strict test cookie;
a separate viewer context receives no owner credential. There is no login,
registration, account provisioning, or anonymous upload route added to TV2.

Before staging upload can be enabled, root must approve and establish:

1. Authenticated accounts, verified listing ownership/consent and a server-side
   authorization check against that exact listing on every write. Client resource
   metadata and the local injected cookie are not evidence of production ownership.
2. Approved storage/cost/quota/retention/deletion policy; owner-bound upload grants,
   private quarantine, atomic publish/revoke and public playback delivery. No bucket
   or service is created here.
3. Isolated untrusted-media validation/transcoding, metadata stripping, abuse controls,
   request timeouts/rate limits and malicious-file tests. Local ffprobe inspection
   is **not** a production media security sandbox.
4. Reviewed public contact disclosure, authenticated editing and recipient consent.
   Never publish private routing data or infer a telephone number from a List Number.
5. Approved HTTPS playback origin, redirect policy, MIME/CORS/range support and
   real Android/iOS/PWA acceptance, plus accessible captions/transcripts for content.

## Actual upload proof

`backend/local_media_demo/server.py` is separate from the deployed API. It accepts
raw `video/mp4` bytes from the injected owner of only `1*5247`, checks same-origin
and CSRF, caps content length and streamed bytes at 5 MiB, and inspects an MP4
header plus ffprobe metadata. Limits: 30 seconds, one H.264 video stream at most
1920×1080, at most one AAC audio stream. Invalid uploads never publish. Filenames
are server-generated content hashes; one publication is retained and replaced
atomically. Viewer reads use `video/mp4`, `nosniff` and range-capable FileResponse.
No upload filenames, credentials, personal contacts or private review media enter
resolver metadata. Disk files/session disappear when the runner exits.

Reproduce locally with the existing tools (no service provisioning):

```sh
# In a temporary Flutter web scaffold containing the repo's lib/ and tool/:
flutter build web --release --no-web-resources-cdn -t tool/local_listing_preview.dart
# From backend, with local Playwright/Chromium, uvicorn, httpx and ffprobe available:
PYTHONPATH=. python -m local_media_demo.browser_proof /absolute/build/web /absolute/evidence
```

The runner uploads the existing one-second synthetic blue fixture, never the
private review cut. `1*5247` has display name **Local owner fixture**, not a claim
that Jair's live listing exists. The separate visitor starts the actual `TV2App`,
selects +1, enters 5247 and uses ENTER after the exact lookup. `HttpResolverApi`
calls the production `/v1/countries`, `/v1/prefix` and `/v1/resolve` route functions,
identity grammar and response schemas against an injected fixture repository.
The dependency override is local to this test application; the deployed app's
repository selection is unchanged. Local proof refuses non-fixture repository mode.

The published URI points directly to a real local TLS server on port 443.
Chromium maps `tv2-media.example.org` to loopback and trusts only that run's
short-lived certificate SPKI. There is no request interception/fulfillment,
`ignore_https_errors`, global certificate-error disabling or installed trust root.
The generated key/certificate and media files are deleted after the run. This
proves actual HTTP resolver and HTTPS byte delivery, not publicly trusted hosted
TLS, real owner authentication or live Supabase storage.

The low-bandwidth phase applies 150 ms latency and 8,192 bytes/s to media delivery
after app assets have loaded. The clip is only 1,880 bytes: this verifies a bounded
slow-network path, not real-world long-video buffering or mobile network behavior.
See [the private staging plan](PRIVATE_STAGING_MEDIA_PLAN.md) for the disabled
integration evaluation and the minimum setup/approval needed before any live demo.

## Flutter listing playback

Only a `listing_video` resource with `metadata.publication = published`,
`metadata.content_type = video/mp4`, and an accepted public HTTPS URI enables the
listing player. Missing/invalid resource preserves the original placeholder.
Nothing is fetched until **Load listing video**, and playback requires a second
**Play listing video** gesture. Pause/replay, retry/error, dismiss/reopen and
lifecycle/route pausing use the existing player APIs in a distinct listing widget.
The listing and keypad remain available if media fails. Media links are not
launched externally; playback lives inside the listing. No default media is added.

## CALL / TEXT

The shared `DeviceHandoff` accepts only resource type `call` or `text` with explicit
`metadata.handoff = device` and a `metadata.phone_e164` string matching
`+` followed by 8–15 digits with a nonzero first digit. This is syntax validation,
not verification of assignment or consent. URI parameters, extensions, message
bodies and raw List Numbers are rejected. Existing generic public HTTPS validation
is unchanged. Old capability-only records cannot trigger a device handoff.

Keypad CALL consumes only the current exact listing; editing/clearing input
invalidates that result. Landing CALL/TEXT uses that listing's typed resources.
A confirmation names the number and device app, then a fresh press invokes
`tel:` or `sms:` through the same adapter. TV2 does not call/send automatically.
False/throwing handlers show manual fallback; even a reported success displays
fallback advice because a browser cannot reliably detect an installed handler.
Tests use only the reserved fictional `+1 202-555-0123` and inject a launcher;
no actual tel/SMS handoff is performed by automation.

Official existing API references checked:
[url_launcher 6.3.2](https://pub.dev/packages/url_launcher/versions/6.3.2) documents
platform-dependent handlers, direct launch with failure fallback, and browser
user-gesture limits; [video_player 2.9.5](https://pub.dev/packages/video_player/versions/2.9.5)
supports inline Android/iOS/web playback. No dependency/minimum changes are made.

## Evidence and limits

See the adjacent synthetic screenshots and recorded validation below. Android
and iOS share the Flutter path, but physical handoff/playback, native owner-upload
UI and screen-reader acceptance remain untested. The PWA local viewer playback is
verified; installed PWA handler behavior and real hosted media/CORS remain untested.
Owner upload UI is local HTML for this proof, not a shipped Flutter account feature.
The keypad tutorial, its captions PR and private review artifacts remain separate.

### Recorded validation

- 9 focused Flutter tests and all 76 Flutter tests pass. Covers typed destination
  rejection, deliberate confirmation/cancel, false/throwing handlers, shared
  keypad adapter and clear invalidation, no-media allocation, video failure/retry,
  dismiss and compact 320×568 at 1×/3× text. Enlarged-text confirmation supports
  keyboard Escape without launching a handler.
- 36 backend tests plus 12 subtests pass, including authorization/CSRF/host limits,
  type/size checks, unpublished failures, codec/duration/track limits, viewer
  read-only behavior and no deployed upload routes.
- Default PWA release build passes without tutorial/media defines. Test clip and
  local owner fixture are absent from the production web output.
- Analysis has no errors: 21 findings (17 baseline, four new Material import
  deprecation infos); no toolchain upgrade attempted to suppress those infos.
- Chromium 156.0.8078.79, 390×844, actual TLS 1.3: separate owner/viewer contexts; uploaded bytes
  SHA-256 `ae0dccc68fca59e2be732b5a75b4304e73d1a00e2ab6ab17ddcac0fdb3f51e16`;
  no media request before Load; no autoplay; inline playback observed at 0.3308 s,
  160×90 decoded video, paused=false. Fixture playback was slowed to 0.25× solely
  for observation. Completion and dismiss verified. Screenshots inspected.
  Media loaded in 1.010 s under the bounded throttle; a real Range request returned
  HTTP 206 and bytes 0–31/1880. Response server address was 127.0.0.1.
- [Owner upload](visuals/listing-media/owner-upload.png),
  [actual Flutter viewer](visuals/listing-media/viewer-playback.png), and
  [machine-readable local result](visuals/listing-media/result.json).
- Private navigation review MP4/VTT SHA-256 values remain unchanged. No media
  publication, real contact handoff, APK install/distribution, live write or deploy.
