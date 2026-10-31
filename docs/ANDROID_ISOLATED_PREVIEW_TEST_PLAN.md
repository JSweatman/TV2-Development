# TV2 isolated Android preview — safe installation path

**Prepared:** October 30, 2026  
**Status:** New workflow proposed for CI validation; **not yet installed or physically verified**.

## Why this exists

The founder's existing Android app opens and preserves its settings despite repeated failed in-place updates of newer APKs. GitHub Issue [#20](https://github.com/JSweatman/TV2-Development/issues/20) tracks update signing compatibility. Do **not** instruct anyone to uninstall, clear data, or overwrite that installed app.

The historical workflow `.github/workflows/android-debug-build.yml` generates `com.example.tv2` using `flutter create --org com.example` on an ephemeral runner, with ephemeral debug signing. A different signing certificate may prevent updating the installed package.

The new `.github/workflows/android-isolated-preview-build.yml` generates a **different package ID**, `com.sundara.preview.tv2`, and labels the application **TV2 Preview**. It outputs `tv2-preview-app-debug.apk`, and verifies the APK package ID with `aapt` **before publishing**. It also verifies the signature and records SHA-256 and signing certificate provenance.

This should allow the preview to **coexist** with the existing older TV2 app. It is a separate installation with its own preferences and local SAVE/Address Book storage; old data **is not imported**. Android may still block installation for other reasons. No physical-device success may be claimed until tested.

## Founder installation safety gate

1. Confirm GitHub workflow **android-isolated-preview-build** succeeded and package-identity check succeeded.
2. Download only the artifact **tv2-android-isolated-preview** from the verified workflow run; inside is **tv2-preview-app-debug.apk**, not `app-debug.apk`.
3. Keep the existing **TV2** app installed. Do not uninstall it or clear its data.
4. Open the preview APK on Android. Expected: a separate app named **TV2 Preview** installs, rather than an update prompt for existing TV2.
5. **If an Update prompt for the original TV2 appears, cancel immediately.** Do not proceed, and report the actual Android dialog and APK filename.
6. After installation, confirm two apps coexist and independently launch. Leave the original app unchanged.
7. Select US +1 in TV2 Preview, close/remove preview from recent apps, reopen twice, confirm **US +1** stays selected. Repeat for Canada +1 and India +91. Verify canonical `529` and explicit `1*529` resolution.
8. Verify media-preview placeholder is labeled **COMING SOON** (no actual camera/video access), native listing SAVE folders, and Address Book separation.
9. Record actual results and screenshots before closing #23.

**Important:** A new isolated package doesn't fix signature compatibility for subsequent `TV2 Preview` builds. The dedicated, stable signing-key workflow remains required by #20; test installer cannot be presented as production-ready.

## Identity and permissions

- Package ID is only for internal previews: `com.sundara.preview.tv2`.
- The existing legacy tester is not modified, removed, migrated, or signed again.
- No new credentials, secrets, network host, permissions or payment services are introduced.
- Do not use the preview package ID as the final production Android App ID without governance review.
- Both apps point to the current TV2 backend, but data under Android's per-app storage is isolated.
- Debug APK only; not signed or approved for public Android distribution.

## Follow-up

- [#20](https://github.com/JSweatman/TV2-Development/issues/20): permanent package configuration and stable protected signing; reproduce data-preserving in-place update.
- [#23](https://github.com/JSweatman/TV2-Development/issues/23): country-ISO2 physical-device regression; automated protection merged via #24.
