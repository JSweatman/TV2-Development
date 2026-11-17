# Reusable listing themes — private synthetic proof

Stacked on PR #44 head `7b7d16303c9dcda76873982038fc02248fc8c3bf`.
This slice is separate from the private visual prototype and tutorial PR #43.
No business names, supplied/private art, real contacts, hosted records or List
Number assignments are introduced. The two examples are synthetic local fixtures.

## Contract and defaults

An existing listing resource opts in with type `landing_theme`, `uri: null`, and:

```json
{"version": 1, "palette": "graphite", "hero": "horizon"}
```

Version 1 permits only palettes `graphite` or `lotus`, and optional hero keys
`horizon` or `petals`. These are original, repo-native geometric decorations,
painted locally in Flutter. They do not load images, fonts, CSS or network assets.
The dark horizon/gold treatment represents a night/automotive direction; the
light sage/blush petals represent a soft lotus/coaching direction. Neither is
pixel parity with approved/private artwork. Future approved hero imagery needs
its own reviewed asset/provenance contract; arbitrary remote hero URLs are rejected.

Palette, typography, spacing, corner radius and minimum touch sizing are
build-owned defaults. Text scales normally and is never fitted by shrinking it.
Foreground/surface and accent/background contrast are tested at >=4.5:1. Hero
art is decorative and excluded from semantics. There is no text over the art.

Six action slots use the existing listing `buttons` and typed `resources`.
Slots 1–6 appear in order, two columns when space/text size permit and one column
at narrow widths or enlarged text. Buttons grow vertically, have a >=56 px
minimum height and remain inside the page scroll. Missing/invalid destinations
are disabled with a useful unavailable-state message. Labels come from listing
data; there are no brand-specific actions in core Flutter. Actual contact handoff
still uses the validated adapter and fresh user confirmation from #44.

Unknown versions/keys/palettes/heroes, duplicate theme/resources/slots, out-of-range
slots and invalid/oversized labels or resource keys reject the theme as a whole.
No theme, or rejected configuration, keeps the ordinary listing renderer. Existing
SAVE, separate Address Book, back navigation, exact resolver and keypad behavior
remain intact. A rejected theme resource is not displayed as a public URL action.

## Inline media and provider boundary

Owner-uploaded MP4 uses #44's `listing_video` contract and player: no request before
Load, explicit Play, pause/retry/dismiss, lifecycle/route pause and existing HTTPS
validation. It is independent of the theme. No media means the existing honest
placeholder, not a decorative working-looking player.

A reserved `provider_embed` resource has `uri: null` and only `provider` and
`video_id` identifier strings. These are **not** permission to construct/open a
URL: no providers are enabled in this slice. Valid identifiers produce an explicit
unsupported-provider fallback; invalid config produces an unavailable fallback.
Neither allocates a video controller nor opens a page. Arbitrary embed HTML,
iframe URLs, path syntax and unknown metadata are rejected. The resource is also
blocked from generic external launch.

Future official-provider support must register a specific provider with its own
strict host/path/ID-to-URL constructor, consent/load behavior and failure policy,
while retaining the general HTTPS guard. Web iframe/CSP/sandbox requirements and
native provider SDK/web-view dependencies require separate review. Current web,
Android and iOS all render the same safe fallback; no embed support is claimed.
No permissions, dependencies or toolchain changes are introduced here.

## Genuine local application proof

`backend/local_media_demo/theme_fixtures.py` adds two records only to the isolated
fixture repository: `1*70001` Night Studio and `1*70002` Garden Studio, both visibly
marked synthetic. These are not assigned to anyone. They share the existing local
owner's tiny synthetic uploaded clip; the proof does not introduce hosted ownership.
Their six actions are CALL, TEXT and four fixed local HTTPS information pages.
Those pages explicitly say no business, map or booking service exists.

Build the existing local entrypoint in a temporary Flutter web scaffold, then run:

```sh
# Temporary scaffold, same source lib/ and tool/:
flutter build web --release --no-web-resources-cdn -t tool/local_listing_preview.dart
# From backend, using existing local tools:
TV2_REPOSITORY=fixture PYTHONPATH=. python -m local_media_demo.theme_proof /absolute/build/web /absolute/evidence
```

The runner starts with an owner upload and then uses separate clean visitor
contexts for each theme. The actual TV2App selects +1, types each synthetic number,
uses real prefix/exact resolver routes and opens the listing. Video bytes travel
through real local TLS, without request interception. Ephemeral certificate pin
and local DNS mapping are confined to test Chromium; no trust-store or production
TLS validation changes. CALL/TEXT dialogs are verified and cancelled; no external
phone app opens. WEBSITE opens a genuine local HTTPS destination. No external
media is fetched. The blue clip is deliberately synthetic, not review footage.

## Validation and remaining scope

- Seven focused theme tests and full 83-test Flutter suite pass, including 320×568
  at 1×/3× text, contrast, disabled actions, no media, rejected config, provider
  fallback and shared call confirmation/dispatch through a test launcher.
- 37 backend tests plus 12 subtests pass, including real resolver theme fixtures
  and absence of theme overrides in the deployed application.
- Analysis: no errors; 23 findings (21 inherited from #44, two new Material import
  deprecation infos). No SDK changes to suppress existing deprecations.
- Browser evidence and default release web build results are recorded below.

No hosted data/config changes, public pages, media enablement, contact outreach,
production deployment, APK installation/distribution or physical-device claims.
Private visual assets and prior review artifacts remain untouched. Native device
and screen-reader acceptance, approved business content, actual hero art, provider
integration and private staging auth/storage remain separate work.

### Recorded browser evidence

Chromium 156.0.8078.79 at 390×844 verified both local fixtures through real
resolution and HTTPS delivery, with no request interception and no request for
media before Load. Playback was observed at 0.1460 s (graphite) and 0.2669 s (lotus),
both paused=false. The one-second fixture was slowed to 0.25× only for observation.
Both CALL/TEXT confirmations were cancelled, and WEBSITE opened the fixed local
HTTPS information page. Representative frames were inspected for fit and contrast.

[Graphite page](visuals/landing-themes/graphite-top.png) ·
[Lotus page](visuals/landing-themes/lotus-top.png) ·
[Graphite playback](visuals/landing-themes/graphite-playing.png) ·
[Lotus playback](visuals/landing-themes/lotus-playing.png) ·
[Recorded results](visuals/landing-themes/result.json).

Default PWA release build passed with no demo defines. Output contains no synthetic
business fixture names, contact number or MP4 fixture. Private review MP4/VTT
SHA-256 values remain unchanged. `git diff --check` passed.
