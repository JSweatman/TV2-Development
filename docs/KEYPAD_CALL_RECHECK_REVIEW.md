# Keypad CALL availability check

Separate draft stacked on #71 head 632ee7a620d900722283050c2ac400d584fd96b9.
No Des, server contract, hosted listing or database changes.

Reproduced with the actual TV2App widget entrypoint, a disposable controlled
ResolverApi and injected DeviceHandoff launcher: after an exact preview,
keypad CALL previously showed cached contact confirmation without another exact
request. The new regression failed because the fresh-request count was zero.

CALL now cancels obsolete preview work, takes request-generation ownership and
resolves the preview's full qualified identity before showing the existing phone
confirmation. Matching country/base/suffix is required; a global *529 check
cannot accept the same digits in +1. Base #71's HTTP adapter omits empty default
country. No new fallback or lookup scope is introduced.

not_found removes the cached preview and reports unavailable. Transport or
identity mismatch reports inability to verify, permitting an explicit retry.
A removed CALL resource cannot reach a confirmation. A changed phone resource
uses the fresh validated destination. CALL is disabled while its request runs;
edit/clear/country/ENTER generations invalidate old replies. A final current-
generation guard protects the existing Open device app callback. It remains a
separate direct user gesture; nothing auto-dials.

## Reproduction / acceptance

`flutter test test/keypad_call_recheck_test.dart` exercises actual keypad digits,
CALL, BACK, Clear and namespace selection before ENTER. Thirteen cases cover:
- National/global missing result, removed typed CALL resource, changed synthetic
  number, wrong namespace and offline failure.
- New +12025550102 shown rather than cached +12025550101; injected launcher
  remains untouched until Open device app, then receives only the new tel URI.
- Held replies invalidated by backspace, Clear and actual +91 country selection
  (asserting persisted NID=91), with duplicate pending CALL suppression.
Existing national handoff, global HTTP serialization and listing-gate tests run
in the full suite. Test numbers are reserved fictional numbers; launcher is
injected, never the OS/default URL launcher.

This is Flutter UI/widget evidence with controlled resolver replies, not a
browser/real HTTP transport rehearsal or a physical device call. A release web
compile checks shared source compilation but does not prove OS handler behavior.
No new polling or guarantee of recalling already-open external apps. The check
establishes availability at lookup time, not an atomic reservation until launch.
