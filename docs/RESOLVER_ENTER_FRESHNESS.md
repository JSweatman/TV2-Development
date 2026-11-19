# ENTER resolver freshness

Based on main `9f8e7a3cb325a20abb0c2e1ade60da16c4e80392`.
The previous client disabled ENTER after no-match and otherwise opened its cached
exact preview. This was a source-level finding; no user-device failure is claimed.

ENTER now performs a new exact resolve with the unchanged input and selected NID.
A resolved response opens its current listing; unavailable/error responses stay on
the keypad with an explicit ENTER retry message. The server still owns validation
and availability. Nonempty input with selected country can retry without editing.
Only an explicit ENTER submission disables ENTER while pending. ENTER cancels
the debounce and supersedes running preview work; generation checks reject late
results after edits, clear or country changes. Country selection
invalidates navigation before asynchronous preference storage. A response received
while another route covers the keypad cannot open a listing behind that route.

Suggestion selection remains fill-only. Draft #49 independently collapses the
suggestions region after selection; this patch does not import that layout or change
its branch. The current input (including qualification/suffix) is passed unchanged;
there is no new polling, server contract, endpoint, call/contact or automatic retry.

This refresh verifies availability at ENTER, not a continuous lease. A listing can
still change after the response; direct landing/media expiry remains a server concern.
No real listings or hosted configuration were changed.

Synthetic widget tests cover no-match to active, active to unavailable, refreshed
content, initial and ENTER transient errors, repeated taps, edit/NID changes in
flight, qualified suggestion selection, and preserved input after details return.

Integration note for #49 (`863a477e5d140ef8a1b30ffc3fa7dbfa4345c431`):
the patch applies cleanly. Its selected-error test must expect the retry message
and enabled ENTER instead of disabled ENTER; these are intentional changes in this
patch. That expectation adjustment was exercised only in a detached local checkout,
not committed to #49. Partial-match previews do not receive an extra no-match row,
so the compact suggestion/keypad layout is preserved.

A superseded prefix response is discarded before any downstream exact request.
Already-started HTTP work is not cancelled at transport level; its response is
ignored. Tests hold both prefix and exact preview responses to verify request order,
explicit-submit deduplication, same-listing navigation and late-response rejection.
