# TV2 Android re-test — 2026-10-21

**Status:** Partial physical-device evidence on updated Android debug APK; user-reported and screenshots in ChatGPT conversation. Do not treat as full release or Astra acceptance.

**Build provenance:** The user downloaded the `tv2-android-debug-test-build` artifact from GitHub Actions run `39614794869` (PR #11 head `e8412c2005943a3470199a3050474473019d967d`; test APK created Oct 21). This build includes the merged PR #10 country-load retry changes and PR #11 human-readable timeout/connection guidance. Native Android scaffold is generated per build with debug signing, so signing identity is not stable across CI runs.

## Observations

| Scenario | Outcome | Evidence and caveats |
| --- | --- | --- |
| Attempt update over previous debug APK | **FAIL** | Android offered to update installed app but displayed `Something went wrong. App not installed.` Signing mismatch is likely because debug builds are created on ephemeral CI runners, but root cause has not been verified with APK signature comparison |
| Uninstall previous debug APK, install new one | **PASS** | User confirmed clean installation; uninstall removes locally saved preferences, not remote Supabase listing records |
| Initial country-list population | **NEEDS IMPROVEMENT / INCONCLUSIVE** | User reported long wait and exited the app; on reopening the country-selection screen appeared automatically. No measured duration, no proof that `Retry Country` was invoked or exercised |
| Explicitly select IN +91 | **PASS** | Screenshot 14:43 shows main Flutter screen with `IN +91`, empty input |
| Persist selected NID across close and reopen | **PASS** | User explicitly reports country persisted. Follow-up screenshot 14:46 shows `IN +91` after reopening |
| Resolve local 529 with selected India NID | **PASS** | Follow-up screenshot 14:46 shows exact `91*529` → `TV2 Fixture India Namespace` |
| Enhanced timeout/offline message | **PASS** | User screenshot at 14:49 with Airplane mode ON, Wi-Fi unavailable, IN +91 selected and `529` input shows red text: `Resolver request timed out. Check your internet connection and try again.` App screen stayed visible; this confirms improved failure guidance on device, but not immediate offline detection or auto-recovery. |
| Network reconnection recovery (updated APK) | **PASS — user reported** | After restoring network access, user cleared/re-entered `529` while keeping IN +91 selected; lookup resolved properly without issues or app restart. No follow-up screenshot was provided for this step. This verifies manual retry after reconnect, not automatic retry. |
| Trash-can clear control — user feedback | **POSITIVE** | User expressly liked the trash-can action, which was used to clear input as part of network recovery. Preserve simple, obvious clear affordance. |
| Switch selected namespace with entry on screen (India → US) | **PASS — automatic re-resolution observed** | User said lookup began automatically after selecting US +1; screenshot 14:53 shows exact `1*529` → **TV2 Fixture Alpha**, plus Alpha Catalogue and Alpha Branch prefix results. The input display reads qualified `1*529`, not the earlier unqualified `529`; exact moment and mechanism of qualification were not captured, so confirm input-preservation separately. |
| Clear NID after uninstall / first-run with no default 1 | **LIKELY / INCOMPLETE** | Country selector appeared after reopening; user chose India explicitly. Record more precise first-frame behavior before marking clean-install no-default check fully passed |

## Next engineering actions

1. Airplane-mode timeout wording and manual recovery after reconnect now both passed on this new build. Future checks: auto-retry behavior (not yet implemented/verified), different network conditions, and distinguishing offline failures from slow servers.
2. Investigate slow first-launch country list. A 40-second timeout plus Retry Country may be insufficient UX if the UI seems unresponsive during Render cold start. Consider loading-state feedback and retry timing tests without silently defaulting NID to 1.
3. Establish repeatable debug build signing for internal update tests (securely protected fixed debug keystore or other approved stable signing path), instead of ephemeral CI signatures. Do not put private signing keys or secrets in the repository.
4. Perform a controlled repeat of India↔US namespace switching with unqualified `529` visible, without tapping any search suggestion, to confirm the UI retains unqualified input while context switches; document whether the app applies qualified notation only after selecting a match.
5. Continue Android smoke and track iOS separately. Retain build/run and device evidence without any sensitive personal information.

This is an evidence archive, not a claim of complete production readiness.
