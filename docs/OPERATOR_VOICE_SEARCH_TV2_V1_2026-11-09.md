# TV2 / V1 — OPERATOR voice search development contract
Date: 2026-11-09

## Approved keypad legend (implemented in this change)

- Fourth keypad row remains `* 0 # .`.
- Display `OPER` directly below the numeric `0` key, evoking legacy telephone OPERATOR.
- Do not display a `+` legend beneath zero. The selected country/NID is separate from the List Number input grammar.
- A normal zero-key tap still inputs the literal digit `0`, preserving the existing List Number parser, numeric display, and resolver behavior.
- This patch **only implements the visual label and the unchanged tap**. No microphone activation, long-press gesture, AI search, sound, or permission request is implemented.

## Intended future OPERATOR interaction

1. On a keypad screen, a deliberate press-and-hold exceeding **1.5 seconds** on zero invokes OPERATOR and **does not input a digit**. An ordinary press/release continues to input zero. Implement a custom hold timer and gesture cancellation, not Flutter's default shorter long-press threshold.
2. Provide an accessible alternative (an explicit OPERATOR action and keyboard/screen-reader invocation) so the gesture is not the sole way to activate this capability, especially for desktop PWA.
3. Open an OPERATOR screen and request microphone access *only after explicit user action*. Play an unobtrusive affirmation tone and show a clear recording indicator after successful permission/recognizer initialization; do not imply listening if unavailable or denied.
4. Show partial live transcript while speaking. After a short configurable pause/final result, preserve an editable transcript and display the recognized request for confirmation or correction. Provide Cancel / Stop / Retry and a typed query fallback.
5. For the initial English preview, choose supported speech locale `en-US` (with ability to change), and interpret constrained intentions:
   - Find a **specific public discoverable** company, person, or List Number.
   - Search a **category** and **area**, such as `Italian restaurant`.
   - Respect explicit requests for 5 or 10 results, or radius such as 5 or 10 miles.
6. Require opt-in foreground location permission when `near me` is requested. Do not infer precise desktop position from IP address; web may provide approximate location or none. Allow manual city/ZIP/postal location and an option to search without precise location. Do not persist GPS/audio by default.
7. Rank **authorized public discoverable listings** by geographic proximity when reliable coordinates exist, then relevance / name, with transparent distance labels. Never return protected CDD records, private/unverified identities, or internal contact routes. A claimed search should never fabricate directory entries.
8. Tap a result to pass its canonical qualified List Number to the existing deterministic resolver. Do not auto-dial, join video, or open third-party apps on interpreting the phrase `connect me`.
9. Preserve strict country-code/namespace rules; OPERATOR's language and location context are separate from the identity-resolution namespace.

## Engineering dependencies and release gates

- TV2's current resolver implements `/v1/countries`, `/v1/prefix` and `/v1/resolve` only. It has no authorized full-text/category/geo search endpoint or complete searchable directory location/category fields yet.
- Build a limited public-listing discovery API with authorized searchable flags, normalized entity/category keywords and geolocation fields, spatial index, bounded results, abuse controls, access tests, and explicit provenance. A development fixture may prove the English preview without implying broad directory coverage.
- Use a cross-platform speech recognizer adapter (Flutter `speech_to_text` is a candidate, subject to Android/iOS/PWA compatibility testing and browser limitations). Support partial transcripts, availability checks, microphone permission, short utterances and cancel/final timeout.
- Keep intent parsing/AI as a separate service or deterministic parser that emits a validated structured query (entity name, list number, category, latitude/longitude if permitted, radius, limit, locale). Never use generated text as an unchecked resolver identity or claim returned results unsupported by the database.
- Add privacy controls, retention policy, abuse/cost quotas and audited consent. Never include provider secrets in the browser/PWA client. Text search works when speech recognition or permission is unavailable.
- Phase 1: English speech-to-text + exact List Number/name lookup against test fixtures; visible verified results.
- Phase 2: bounded category search and distance ranking with supported public directory data.
- Phase 3: multilingual recognition and intent normalization via explicitly selected locale or user preference; fall back to typed translation review if uncertain. The selected country/NID may suggest the initial language but must not override user language preference.
- Test separately on actual Android hardware, iPhone, desktop/mobile browser; a successful widget test, simulator, or web build is **not** physical-device acceptance.
- Keep OPERATOR feature behind an explicit release flag until real end-to-end behavior, permissions, language handling, and accessibility are verified.
- Keep existing Android TV2 installed. Isolated preview must retain package ID `com.sundara.preview.tv2` and never replace the old app.
