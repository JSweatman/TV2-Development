# TV2 — Android physical-device acceptance observations (2026-10-20)

**Status:** Partial physical-device acceptance; not launch approval or full Astra handoff.

Source: user-conducted TV2 testing on a personal Android phone, with screenshots and descriptions provided in the ChatGPT conversation on 2026-10-20. The screenshots are conversation evidence and have **not** been copied into this repository. Device make/model, OS version, APK hash and exact app build identity have not been independently captured. The tester downloaded an APK from the TV2 GitHub Actions artifact workflow (link was provided for run `39305218207`).

## Observed results

| Scenario | Outcome | Evidence/limitations |
| --- | --- | --- |
| Install and launch development APK | **PASS** | User reported app installed and interacted with Flutter UI |
| First country-list load | **INTERMITTENT FAILURE** | User reported initial timeout and `Select Country` not responding; subsequently list loaded and user selected US. Suspected short request timeout/Render cold start, not confirmed root cause. Candidate fix: [PR #10](https://github.com/JSweatman/TV2-Development/pull/10) |
| Explicitly select United States `+1` | **PASS** | Screenshot with `US +1` header |
| Enter base `529` under US `+1` | **PASS** | `1*529` resolved as **TV2 Fixture Alpha**, marked EXACT; other prefix results were displayed (`529.411`, `5291`) |
| ENTER opens listing/resources | **PASS** | `TV2 Fixture Alpha`, `1*529`, generic template/basic screen and configured CALL, TEXT, VIDEO, WEB buttons |
| External HTTPS launch | **PASS** | Selecting WEB opened Brave at `example.com/alpha`; it is a reserved example destination, **not** an actual hosted production landing page |
| Browser translation prompt | **OBSERVED** | Brave offered a translation prompt identifying Russian-to-English on a multilingual example.com page; not proof of country-specific translation policy |
| Change selected country to India `+91` | **PASS** | Screenshot with `IN +91` |
| Enter base `529` under India `+91` | **PASS** | `91*529` resolved as **TV2 Fixture India Namespace**, EXACT, different from US `1*529` |
| Persist selected country across app restart | **PASS** | User closed/reopened app; screenshot showed retained `IN +91` and cleared input |
| Global `*529` under India `+91` | **PASS** | Screenshot showed `TV2 Global Fixture`, EXACT |
| Global `*529` under United States `+1` | **PASS** | After switching country without changing Global Code, screenshot again showed **TV2 Global Fixture**, EXACT. Confirms expected namespace-independent Global Code behavior for this test fixture |
| Offline lookup in Airplane mode, Wi-Fi off | **PASS — error visible** | Screenshot at 14:42 shows `529` and red `Resolver request timed out.` message; app stays open without a successful result. This confirms handled failure, but does not confirm immediate socket-error detection or helpful offline wording. |
| Lookup recovery after reconnecting | **PASS** | Screenshot at 14:44 shows `529` resolved again as TV2 Fixture Alpha and prefix listings under US +1. It proves recovery with renewed input; does not prove auto-retry without user action. |
| Android Recent Apps task switching | **PASS — user-reported** | User reports repeatedly switching between ChatGPT and TV2 using Android Recent Apps; TV2 resumes with previous functions available. The user has not separately documented browser-specific back-stack behavior or process-death restoration. |

## Still NOT TESTED / NOT YET VERIFIED

- Full country directory beyond currently provisioned testing namespaces.
- Clean-install first-run selection with no automatic NID across multiple devices.
- Offline timeout and manual reconnection recovery, plus Android Recent Apps switching between ChatGPT and TV2, passed on one Android device. Additional network permutations, automatic retry, invalid/malicious URL refusal, launcher failure, and browser-specific back-stack behavior are not yet verified.
- Touch/accessibility/rotation on different screen sizes and Android versions.
- Dedicated France/Japan scoped `101` fixtures and translation prompt behavior for true foreign-language landing pages.
- Real CALL/TEXT/VIDEO integration, consent, protected-number enrollment/verification, CDD, restriction and privacy policy behavior.
- Any iOS build, iPhone test, mobile production signing, or app store readiness.

## Engineering follow-up

1. [PR #10](https://github.com/JSweatman/TV2-Development/pull/10) merged on 2026-10-20, with automated checks previously passing. Verify first-run selection and Retry Country UI with a newly built APK before calling the timeout fixed.
2. Retest first-run and retry UI under delayed/failed requests; distinguish transient free-tier cold starts from client defects.
3. Improve user-facing offline wording (currently `Resolver request timed out.`); run remaining allowed/disallowed external-resource and return-navigation tests on device.
4. Record device model, Android version, tested APK provenance/hash, and test cases in the final acceptance matrix once available.
5. Refresh [Astra Read Me First](ASTRA_READ_ME_FIRST.md) with these **partial** physical-device results; do not mark handoff ready solely on these screenshots.

No personal details from the test device or private accounts should be added to repository logs.
