# Shared +1 Numeric-Only Dialer — TV2 and V1

**Decision (2026-11-07):** In the TV2 and V1 dialing interfaces, display only **+1** for the shared +1 List Number namespace. Do not display US, CA, JM, or any other ISO country label adjacent to +1.

## User experience

- Show a single **+1** selection in the dialing namespace selector, even if the API supplies several country records with NID `1`.
- Once selected, display **+1** alone in the dialer header.
- Persist the selected numeric NID `1` across restarts. For new selections of +1, do not persist an inferred `tv2_selected_country_iso2`; ignore any legacy country ISO2 when restoring +1.
- Keep the standard country-specific selector and saved ISO2 behavior for other NIDs, unless a separate design decision changes it.
- Keep the resolver input and canonical identifier numeric. `1*529` has the same meaning throughout the +1 namespace. The UI label does not create distinct US/CA/JM listings.
- Do **not** default first-launch users to +1; the user still selects a dialing namespace.
- Do **not** change existing saved listings, bookmarks, account identity, or resolver back-end data merely to alter the dialing label.

## Separate country and identity context

The numeric +1 dialing selection does **not** establish country of residence, telephone-number ownership, nationality, language, jurisdiction, or enrollment authority. Any country-specific verification, consent, number-plan handling, localization, or account settings must be handled separately and should not be inferred from the first +1 record returned by the API.

## Acceptance criteria

1. With US, CA, and JM sharing +1 in any ordering, the selector shows exactly one **+1** choice and no country letters or country names for that choice.
2. Selecting +1 persists numeric NID `1`, leaves the existing entered digits intact, and the resolver continues to use numeric NID `1`.
3. After closing and reopening, the dialer still displays **+1**, with no US/CA/JM label, even when the device previously saved a legacy ISO2 preference.
4. Other dialing options such as India +91 retain their existing behavior.
5. V1 should follow the same design whenever its codebase is available; **no separate V1 implementation is present in this repository**.
6. Automated regression tests and a new isolated Android preview must pass before declaring the UI physically verified. Protect the original TV2 installation; the preview must use `com.sundara.preview.tv2` and must never overwrite the old application.

## Scope

TV2 Flutter UI and tests changed via the associated PR. This document is the V1 design contract until the V1 implementation is identified.
