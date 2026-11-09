# TV2 / V1 OPERATOR — English existing-listing lookup only

Approved 2026-11-09. This contract supersedes earlier OPERATOR concepts that included immediate category or location searches.

## ZERO-key visual change (PR #30)

- Keep four-column keypad order `* 0 # .`.
- Show numeral `0` with smaller `OPER` directly beneath it; no `+` legend.
- Ordinary tap inserts the exact digit `0` and preserves current resolver input rules.
- PR #30 changes the legend and adds a regression test. It does **not** enable microphone/AI/long press.

## English OPERATOR MVP — desired user experience

1. A deliberate ZERO hold **longer than 1.5 seconds** opens an OPERATOR screen, with no digit inserted. Quick taps remain ordinary digit entry. Provide a visible and keyboard/screen-reader accessible alternate invocation.
2. On user request, ask for microphone permission, then signal ready-to-listen with an accessible indicator and affirmation tone **only after** recognition is actually ready.
3. Display spoken words as live partial transcript, then an editable final transcript after Stop or a short pause. Offer typed request, Retry, Cancel, and an intelligible unavailable/denied-permission state.
4. Recognize **English** requests for one of two existing public listing forms:
   - Exact base or qualified List Number, scoped by the saved country/NID or explicit country/global code; e.g. 'find five two four seven'.
   - Existing public listing *display name*; e.g. 'find [known company/person]'.
5. Show only real, currently active/discoverable database matches. A single match opens as a user-selectable listing; ambiguous names produce a bounded choice of verified listings. Tap uses existing deterministic resolver; speech never automatically initiates a call or navigation to an outside destination.
6. When no match exists, clearly state that no listing was found. Do not generate names, identities, or unverified links.

## Current backend limits and minimal viable integration

Current backend implements `GET /v1/countries`, `GET /v1/prefix` (numeric/identity prefix) and `GET /v1/resolve` (exact identity). `ListingRecord` already includes `display_name` and a public `list_number`; it does **not** expose a name-search endpoint.

- Spoken numeric identities can be parsed and sent through the current exact resolver after explicit transcript confirmation.
- A **public-name search endpoint/repository adapter** is required for arbitrary name lookup. Investigate querying existing `display_name` with an authorized bounded server-side method; avoid a new table/column or migration if existing policies and performance allow.
- If a safe live name search cannot operate without additional SQL/RPC/index work, use an explicitly labeled development fixture for named-listing demonstration until the backend is ready; do not silently scan all listings client-side or claim live name discovery.
- Enforce approved discovery visibility and return only safe public listing information; never expose CDD, internal communications endpoints, unauthorized personal records, or subscriber information.

## Explicitly deferred to later phases

**Do not implement as part of the English OPERATOR MVP:** ISIC classification, business categories, address fields, GPS/location permission, radius settings, distance ranking, 'restaurants near me' searches, broad natural language discovery, or multilingual recognition. These belong to separate future database/design phases, after relevant fields and governance are agreed.

Keep future speech engines replaceable via a platform adapter for Android, iOS and PWA. `speech_to_text` is a candidate, subject to real platform availability, microphone permission, and language behavior testing; locale for this preview is English. The AI component may be small or deterministic for these two constrained intents; do not assume that an LLM or paid AI API is required for basic speech transcription and exact lookup.

## Acceptance, privacy and safety

- Tests for short tap vs over-1.5-second hold, hold cancellation, accessibility alternate, permission denied, unavailable speech recognition, transcript corrections, silence timeout, numeric/name intent parsing, no match, multiple genuine matches, bounded outputs, and error recovery.
- Never record in the background or request microphone access except after an explicit OPERATOR action; do not retain audio by default.
- Do not introduce location permission at this stage.
- Test actual microphone/transcript/lookup separately on Android devices, iPhones and mobile/desktop PWA. CI/simulator compilation does not count as physical-device acceptance.
- Keep OPERATOR gated until actual behavior and permissions are verified. Maintain the original Android TV2 installation; isolated Android preview must remain `com.sundara.preview.tv2` and must never update/replace it.
