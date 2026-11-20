# Compact portrait keypad results area

Based on main `9f8e7a3cb325a20abb0c2e1ade60da16c4e80392`. This is the
`TV2App` / `HomeScreen` source used by the bookmarked Render PWA according to
the last verified deployment. A fresh Render inventory was unavailable here
(`no workspace selected`), so this is source verification, not a fresh hosted
bundle comparison. Unmerged #45 themed listings and the separately hosted
JOYFUL page are distinct surfaces; neither is changed.

The excessive blank gap was the reserved results viewport (15% of available
height, bounded 72–160). On phone portrait widths below 600, halve that allocation.
With suggestions, retain at least one complete 64px two-line row, scaled with text;
additional results scroll internally. Landscape and desktop retain the original
allocation. Video, key dimensions and CALL/HOME/BACK/ENTER order are unchanged.
The outer scroll remains for short screens and enlarged text.

At 360×740 logical pixels, empty video-to-first-key gap is 116 → 62 (47% less);
results viewport 108 → 54 empty, or 108 → 64 with suggestions (41% less).
The 140px video and 64px numeric keys are unchanged. Widget assertions verify
ENTER is initially in the viewport in both states, and remains far right.
These are actual logical measurements, not inferred screenshot DPR or offset.

## Reproduce

Flutter 3.50.0. `tool/viewport_preview.dart` is a loopback-only synthetic resolver
entrypoint to the actual app, not imported by production. In a disposable web
scaffold containing these lib/tool sources, build:

```
flutter build web --release --no-web-resources-cdn -t tool/viewport_preview.dart
python scripts/portrait_gap_browser.py /absolute/build/web /absolute/output
```

The Chromium harness uses normal zoom (visualViewport.scale=1), mobile/touch
emulation and real scroll input. Its `gap_css` records the placeholder **semantics
text box** to key boundary, not the painted panel boundary; use widget geometry
above for the exact panel gap. Compare before/after deltas consistently.
Only synthetic local screenshots are retained; no user screenshot is committed.
No physical or installed-PWA device testing is claimed.

Widget coverage includes empty/single/multiple suggestions, internally scrolling
to a later match, selection/qualified resolution/ENTER and return, text scale 2,
and unchanged landscape/desktop heights. Existing tests also cover 320×568 and
text scale 3 reachability.

## Separate media staging gates (no changes)

#46's disposable local owner Auth/private Storage/upload/publish/viewer proof
exists. Reusable staging still needs an approved HTTPS session/origin gate,
Secure/HttpOnly/SameSite cookies, expiry/logout/revocation, exact invited owner and
viewer binding, and durable private storage. Untrusted ingest remains a separate
validation/isolation/quota/cleanup gate. No accounts, buckets or permissions were
changed here.

#47 already provides opt-in privacy-enhanced YouTube embedding on PWA and a native
link fallback. Actual provider playback remains unverified due to the recorded
ERR_CERT_AUTHORITY_INVALID; no certificate retry or trust change was attempted.
Its next gate is trusted-access playback of an approved embeddable ID. Neither
existing draft nor its description was edited. JOYFUL and its window are untouched.

## Validation results

- Focused widgets: 5 passed; full suite: 72 passed.
- Chromium 156: all eight viewports passed empty reachability, synthetic single
  suggestion → qualified selection → ENTER → listing → Back with query retained:
  320×568, 360×640, 360×740, 390×844, 430×932, 320×480, 844×390, 1280×800.
  Initial empty bottom row now fits 360×740 (previously clipped); also fits 390×844,
  430×932 and desktop. Shorter heights still need normal accessible scrolling.
  Inspected before/after and single-result screenshots at 360×740; both final
  states show the complete bottom row. Multiple-result scrolling is widget-tested.
- Synthetic preview and default PWA release builds pass.
- `flutter analyze` blocked by analyzer cache creation at read-only
  `/home/agent/.dartServer` (OS error 30); not reported as a passing analysis run.
- No live resolver, media, contacts, trust settings or hosted state changed.

## Selecting a suggestion

A selected match fills the input with its unchanged `qualifiedInput` (namespace
and suffix included), sets the results viewport to zero height, and stays on the
keypad. ENTER opens the listing only after the normal qualified lookup succeeds.
Returning from details retains that selection and collapsed panel. Real edits,
backspace, clear and namespace selection restore normal matching. Request
generation invalidation prevents stale completions/errors from reopening results
or replacing the current listing. Current lookup errors remain visible.

Six additional tests cover mobile/desktop selection and return, suffix integrity,
semantics tap activation, country/clear/edit reset, delayed stale success and error,
and current selected-lookup failure. All 78 Flutter tests pass. The previous
empty/single and multiple-result/enlarged-text regressions remain included.

The browser harness now uses touch selection in mobile emulation and records
`selection_reclaimed_css`, `selected_enter_visible`, and edit-to-reopen behavior.
The allocated suggestion height is fully removed; displacement of keys can be
smaller because the resolved listing name also appears in the input display.
No universal viewport fit or physical-device result is claimed.

All eight Chromium cases pass selection → ENTER → details → return → edit.
After selection the complete bottom row is visible without additional scrolling
at 360×740, 390×844, 430×932 and 1280×800. Shorter cases retain working scrolling.
At 360×740 the 64px result region becomes 0; keys move up 44px because the resolved
name adds 20px to the identity display. The video-to-key gap is now 8px.
