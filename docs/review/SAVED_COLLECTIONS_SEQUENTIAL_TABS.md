# Saved collections: completed writes in another tab

Local review only, based on frozen PWA `8a76ac0fafd3601f806aa43a256f63cdd35befb4`.
No storage key/schema migration, cloud sync, account, namespace, or platform packaging change.

## Reproduction

Use normal `lib/main.dart` release output with the canonical API declaration. Run
`scripts/saved_collections_browser.py --web <build/web> --out <new-evidence-directory>`
with the existing Python Playwright installation and `/usr/bin/chromium`.
The script serves loopback files, intercepts every canonical resolver request
with two synthetic fixtures, and aborts every other external request. It does
not contact the resolver. Flutter semantics is explicitly enabled for UI input.

Each scenario starts with fresh browser storage at 390x844. Within it, A/B/C
share one context/origin. HOME -> Bookmarks initializes the collection cache.
Tabs are brought to the foreground for their UI actions. Saves finish before
subsequent actions; this is not an overlapping-write test.

1. Single-tab control: save fictional `1*529` and `1*530`, then read through C.
2. Sequential tabs: initialize A and B, save `1*529` in A, then `1*530` in B;
   open C and inspect expanded folders plus persisted JSON.
3. Withdrawal: seed `1*529` in Bookmarks (alias `My Cedar`, folder `Woodshops`)
   and Address Book (alias `Cedar friend`, folder `People`); initialize B with
   that state. A saves unrelated `1*530` in `Other`. B enters 529 with ENTER
   after the synthetic resolver changes to definitive not_found. Inspect C.

Frozen behavior: the single-tab control preserves both entries. In scenario 2,
B's save replaces A's completed save. In scenario 3, title invalidation uses
B's stale document, losing A's unrelated item while clearing the seeded title.

## Small fix

Reload SharedPreferences on collection open and immediately before save,
remove, or publisher-title invalidation. Derive each mutation from that refreshed
document. Keep private aliases, folders and qualified identity unchanged.
Check the resolver generation after the asynchronous reload before clearing a
title. Ignore older asynchronous collection refresh results when a newer refresh
has started, including older failures.

Six focused regression tests independently mutate the platform store behind the
preferences cache, covering save/remove/invalidation/reopen, superseded evidence,
and out-of-order screen refresh. The original four persistence regressions fail
on frozen source. Existing transport-error/title-withdrawal tests remain in scope.

## Limits

This is a read-refresh-write correction, **not atomic cross-tab coordination**.
Two tabs that read before either completes a write can still race. No overlapping
write guarantee, browser storage event subscription, automatic background refresh,
cloud synchronization, physical device or native storage guarantee is claimed.
An already-open collection in another tab can remain visually stale until reopened.
Definitive unavailable responses clear publisher titles only after an actual exact
request; offline/timeout behavior remains distinct. Already-cached titles before
such a recheck are not evidence of current publication.

## Observed local results (2026-11-27)

Chromium 156.0.8078.79, fresh 390x844 contexts, ordinary main.dart:

| Scenario | Frozen | Local correction |
|---|---|---|
| Single-tab save then fresh C | Both entries retained | Both retained |
| Sequential A/B save then fresh C | A's Cedar lost; Maple only | Cedar and Maple retained |
| B unavailable after A unrelated save | Unrelated Maple lost | Maple retained; both Cedar titles empty; aliases/folders retained |

Before origin: `http://127.0.0.1:45267`; corrected origin:
`http://127.0.0.1:35655`. Origins differ between independent runs; A/B/C share
one origin within each scenario. No storage is copied between runs.
The full Flutter suite passed 192 tests. Release web build passed using Flutter
3.50.0 and the ordinary canonical resolver declaration; network was intercepted
in the browser. Focused analysis reported existing notifier/protected-member,
null-assertion and SDK deprecation warnings/info, plus test style/deprecation
info; it was not a clean analyzer gate. No analyzer errors.

Browser result JSON includes synthetic API requests, storage snapshots, exposed
row names and compiled JS hashes. Bookmarks were inspected through C's expanded
UI; Address Book alias/folder retention was checked in persisted JSON and existing
widget coverage, not a separate final C Address Book browser traversal. Some
screenshots caught folder expansion animation; storage and accessibility snapshots
provide the complete row assertions. Physical devices and overlapping writes remain
unverified. No push or hosted action was performed.
