# Saved publisher titles after a definitive unavailable lookup

Independent candidate based on #64 d6a28e6b460be5c780d8abeb092ef31e63a9f5b8;
no edits to #71 or Des. The original normal TV2App HOME → Bookmarks → saved
entry → ENTER route retained the cached publisher title after not_found and
app recreation. The new regression failed on that baseline; offline control
passed.

TV2App decorates its existing ResolverApi. Only an existing exact request with
not_found, no listing, matching echoed input and namespace clears the cached
publisher title for the full qualified saved key. Prefix absence, exceptions,
unknown statuses and mismatched results do not clear it. No request is added.
Newest request ownership protects against a late superseded exact result for
the same identity. Both collection kinds are updated in the same local write. Open collection
screens refresh through an in-process notification, without a network request.

Folder, kind, qualified identity and private alias remain unchanged. Default
entries show `Listing unavailable`; explicit aliases remain visible even if
identical to the former publisher title. The publisher text is erased from
stored records, not merely hidden by UI. Re-saving a currently available listing
can restore a publisher title using the existing Save behavior.

## Boundaries

Before the first definitive exact recheck, cached titles can still appear.
Opening a collection does not itself recheck entries. Timeout/offline errors do
not imply withdrawal. No background polling, sync, account, migration or shared
DB write. This covers API calls through normal TV2App; custom test entrypoints
constructing HomeScreen with an undecorated API must opt into this adapter.
#71 integration is separate and must preserve this decorated API through its
listing gate. Already-open external pages/downloads are outside this scope.
Multi-tab/process SharedPreferences write races and storage failure are not
claimed solved. Local write failure reports an error instead of claiming the
saved titles were updated. Physical devices remain untested.

## Checks

Widget journey uses actual TV2App, HOME, Bookmarks, saved selection, ENTER,
app recreation and both collection screens. Tests verify offline retention,
exact namespace/global/suffix isolation, full saved metadata preservation,
late-response exclusion and the existing core app flows. Local synthetic data
only. Browser evidence, when recorded, uses normal main.dart and real loopback
FastAPI/Postgres; no hosted resolver.

The local Chromium harness found an existing saved-row semantics limitation:
rendered row title/number were absent from the browser semantics tree although
visible in screenshots. Row selection uses a screenshot-verified pointer click;
this does not claim keyboard/screen-reader acceptance for saved rows. Form entry
uses real keyboard events, since Playwright fill() did not reliably update the
Flutter text controller. Neither harness finding caused runtime scope expansion.

Observed browser journey: Chromium 156.0.8078.79, 390×844, normal main.dart with
loopback FastAPI/Postgres from foundation 22aa61d. UI Save to Bookmarks with no
alias, UI Add to Address Book with a private alias, suspend only synthetic 1*529
in the disposable store, reopen saved reference and press ENTER, then browser
reload. Visually inspected screenshots show `Listing unavailable` / `1*529` in
My samples and `My private alias` / `1*529` in People. No hosted endpoint or
external destination involved. All 145 Flutter tests and release web build pass.
