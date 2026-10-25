# TV2 Android acceptance — SAVE and Address Book (planning checklist)

**Prepared:** October 25, 2026  
**Owner:** Sundara Technologies LLC / List Number  
**Status:** PREPARED, **NOT YET TESTED ON A PHYSICAL DEVICE**. Automated CI checks are not interchangeable with on-device acceptance.

## Build and code history

- SAVE local folders merged via [PR #16](https://github.com/JSweatman/TV2-Development/pull/16) as `a884f59610b29d2bfe11edb2d316af4ece19aa74` (October 24).
- Address Book local collections merged via [PR #18](https://github.com/JSweatman/TV2-Development/pull/18) as `39c3d3749d82101f6f35aa319c9a22a6729fb9d7` (October 25).
- Android CI for PR #18 source commit `9b70777ff4bfa43bb6eb89cabd1a94653af4007c`: [run 40141518353](https://github.com/JSweatman/TV2-Development/actions/runs/40141518353), debug artifact `tv2-android-debug-test-build` created October 24, expires October 31. GitHub Flutter, backend, and live-smoke checks passed. **This artifact is a branch-built debug APK**, not a tested release build.
- Latest Render service deployed from main independently. A Render backend update **does not install the Flutter app** on the test phone.
- CI Android workflow uses `flutter create --platforms=android --project-name tv2 --org com.example .` on **ephemeral GitHub runners**. The resulting signing certificate may change every run, preventing an in-place Android update.

## Installation and data protection gate — BEFORE device testing

**DO NOT uninstall the user's current TV2 package merely because a new debug APK exists.**

1. Confirm whether the installed app holds valuable local preferences or SAVE/Address Book entries. Until export/restore is implemented, those device-local folders can be lost on uninstall or app-data reset.
2. Identify the current installed Android app version and, if feasible, signer certificate fingerprint (e.g. using an authorized Android developer/ADB workflow). Do **not** assume an APK can update an existing installation unless its package ID and signer certificate are compatible. A prior update failed with `App not installed`; root cause was **suspected** signing mismatch, not cryptographically proven.
3. Verify selected artifact source commit and recorded APK SHA-256/signing fingerprint before installing. A separate signing-provenance CI improvement is planned; legacy artifacts may lack this manifest.
4. An update install that preserves app data is preferable if compatibility is verified. Do not recommend force/uninstall/install to the user unless they explicitly accept the risk of losing device-only data.
5. A separately signed test package with a different package ID is an alternative **only after** that build configuration and namespace/data isolation are explicitly reviewed and tested.
6. Never request the user's signing private keys, passwords, personal contact list, or device-level sensitive information in chat.
7. If no safe update mechanism is available, **defer physical testing**, preserve current installation and prioritize a stable internal signing process. This does not block documentation or automated regression tests.

## Phone acceptance script — to execute only after safe installation

Record `PASS`, `FAIL`, or `NOT TESTED`, Android OS / device model / app build commit / artifact hash, time, evidence, and any issue reference.

| # | Device scenario | Expected result | Result |
|---|---|---|---|
| 1 | Launch with existing selected country | Restores exact country ISO2 and NID; no implicit +1 | NOT TESTED |
| 2 | Enter `529` under US +1 | US fixture resolves | NOT TESTED |
| 3 | Switch to India +91 while `529` remains unqualified | Field remains `529`; India fixture resolves | NOT TESTED |
| 4 | Enter `1*529` while selected country is India | Explicit US result does not change | NOT TESTED |
| 5 | Resolve `529` and tap ENTER | Native listing detail screen opens | NOT TESTED |
| 6 | Tap **Save listing** | SAVE dialog appears with new/existing folder and optional custom name | NOT TESTED |
| 7 | Create Bookmarks folder `News`, alias `My News Source` | Saved `1*529` appears under that private folder | NOT TESTED |
| 8 | Return to keypad; tap **Saved folders** | Folder and bookmark visible; listing can reopen through resolver | NOT TESTED |
| 9 | Open listing; tap **Add to Address Book** | Separate Address Book dialog opens | NOT TESTED |
| 10 | Create Address Book folder `Family`, alias `My Family Contact` | Contact saved independently of Bookmarks | NOT TESTED |
| 11 | Tap **Address Book** shortcut | Family entry visible and reopens exactly qualified identity | NOT TESTED |
| 12 | Remove contact from Address Book | Bookmark under News still exists; removal is isolated | NOT TESTED |
| 13 | Save same List Number into both collections | Neither duplicates nor overwrites the other collection | NOT TESTED |
| 14 | Close/reopen application | Folder names, entry aliases, and selected country persist on device | NOT TESTED |
| 15 | Disconnect network and visit saved folders | Local folder names/aliases remain accessible; opening remote content may fail gracefully | NOT TESTED |
| 16 | Reconnect network | Existing saved reference resolves again without changing its canonical namespace | NOT TESTED |
| 17 | Verify keypad HOME button | Prior current behavior preserved; personal landing-page HOME routing not yet implemented | NOT TESTED |
| 18 | Verify only expected notification controls | No false implication that publisher updates or recipient share push is implemented | NOT TESTED |

### Known features intentionally not part of this acceptance

- Authenticated user landing page navigation; HOME context changes.
- Direct List Number-to-List Number message delivery or in-app sharing.
- QR-based canonical identity links, OS-native share-sheet integration.
- Publisher webhooks and per-listing opt-in push notifications.
- Remote synchronization, backup, or restoration of device-local folders.
- Production signing/distribution and iOS device acceptance.

## Release engineering follow-up

A new CI checkpoint records an APK's SHA-256 and signing certificate fingerprint within `BUILD_PROVENANCE.txt` (and job summary), verifying its Android signature with `apksigner`. This supplies **diagnostics**, not stable signing. A separate reviewed signing approach must safely maintain the same signing identity across builds with secrets/keys held outside the Git repository and appropriate Android/iOS security controls. A permanently fixed `com.example` package and ephemeral runner-generated signing are **not** acceptable for the production release.

Do not call device acceptance PASS merely because PR checks or an APK build succeed.
