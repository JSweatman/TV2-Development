# TV2 Demo Tutorial Videos — ElevenLabs production and integration brief

**Date:** 2026-11-14
**Status:** Draft creative/engineering handoff for founder approval; media not generated and player not implemented.
**Source:** Approved direction in GitHub Issue #32; shareable isolated Android TV2 Preview APK is the immediate delivery target.

## Objective and safety

Produce a polished, optional three-part tutorial inside TV2's existing media area. All content must be truthful about what works today versus what is planned. The keypad, country selector, List Number resolution, and external destination flow always remain available without mandatory registration or video viewing.

**ElevenLabs / ElevenCreative Studio** is the desired production tool for warm female narration, accurate synchronized captions, and final H.264 MP4 exports. Generate/edit media in the owner's ElevenLabs account after reviewing usage/credits; do not create billable resources or insert ElevenLabs API credentials in source/mobile artifacts. Use actual screen recordings from an accepted TV2 build for functional steps; avoid generative imitation of unimplemented UI.

## Playback experience

- Keep the normal TV2 keypad as the first screen. Videos are entirely optional and must not auto-play with sound.
- Show a clearly labeled **Play: Navigating TV2** entry in the media panel only once approved content is present.
- After each tutorial completes, offer **Play next video** and **Done / Return to keypad**; allow skip, pause, resume, replay, and seek.
- Captioned video (or equivalent synchronized captions) plus an accessible plain-text transcript, readable tap targets, error state, and no interference with number resolution.
- A playback or network failure must never interrupt the resolver. No registration, microphone/camera access, user tracking, or forced account creation for playback.
- Content should be replaceable/versioned without exposing database credentials or writable admin APIs.
- Ship a size-conscious 720p H.264/AAC MP4 set (preferably 16:9 for the existing panel), optimized for Android demo delivery. Decide bundled offline assets vs secure hosted downloads based on final APK size and offline demonstration needs. Bundle only approved releases.
- Automated tests: initial keypad remains accessible; play/next/done/skip/replay actions; absent/unavailable assets; failure handling; no compulsory tutorial or login; no regressions to country selection, LIST entry, and local data.

## Video 1: Navigate TV2 (mandatory for first demo release, 60 seconds maximum)

**Narration draft (approx. 103 words):**

> Meet TV2, the test version of List Number. Start by choosing your country or numeric dialing namespace. TV2 remembers your selection until you change it. Enter a List Number using the keypad. As you type, TV2 looks for matching public listings. Select the correct match, then choose ENTER to view its listing. When the owner has provided an available web destination, tap it to open the page. You can also save a listing in Bookmarks, while the Address Book remains separate. If your connection drops, reconnect and try again. That's the TV2 experience: a simple number that helps you reach the right destination.

**Suggested shots:**
- 0–6s: TV2 launch; keypad visible; title “TV2: Find it by number.”
- 6–15s: Select +1 or another supported namespace; note that +1 appears without country letters.
- 15–31s: Enter an authorized known fixture; show an actual match and the ENTER flow.
- 31–44s: Open one authorized HTTPS landing-page destination. Clearly label any placeholder page.
- 44–53s: Brief Bookmarks / Address Book distinction.
- 53–60s: Return to keypad; “Enter. Connect. Explore.”

**Production gating:** Record the working source build and the exact authorized fixture used. Do not use the approved tropical-sunset default UI as if shipped until implemented and accepted.

## Video 2: Free access and personalization (hold until real feature acceptance; 45–60 seconds)

**Status:** CONTENT PLAN ONLY. Optional account creation and free appearance customization are approved requirements, **not yet verified as implemented in main**. Do not publish this video as an instructional tour of functioning controls until the feature passes acceptance. If showing a V1 concept now, overlay “Planned feature — not yet available” throughout.

**Future narration draft:**

> TV2 is designed to be useful without requiring an account just to enter a List Number. When personal account features are available, you'll be able to customize your own experience, including the background and appearance of the keypad. Preview how an image is positioned, confirm the crop, and save your design. Your preferences are meant to stay with you when you close and reopen the app. Personal appearance customization will remain free for every account tier. Until those controls are released and tested, you can continue using the core TV2 number-entry and resolver experience without signing up.

**Future shots:** Actual free-user personalization flow, image preview/crop confirmation, accessibility contrast, app relaunch persistence. Captions and narration must match demonstrably implemented functionality before release.

## Video 3: What List Number V1 is building (future roadmap, 45–60 seconds)

**Narration draft (approx. 94 words):**

> List Number begins with one simple idea: a number can be an easier way to reach a person, business, or organization online. Sundara Technologies is building a portable identity and access platform that routes a List Number to its owner's approved digital destination. TV2 lets us demonstrate the foundation today. The full V1 vision goes further, with more ways to personalize a landing page and connect through services offered by participating providers. Some of those capabilities are still being developed. We'll show you what works now and introduce new features only after they're ready. One number. More possibilities.

**Suggested shots:** List Number identity routing, authorized landing-page example, global namespace illustrations, V1 concept graphics explicitly marked “Concept / Planned,” closing logo and demonstration disclaimer.

## ElevenLabs deliverables to request and verify

For each published video:
1. Original editable Studio project owned/accessible by Sundara.
2. Final approved MP4 with H.264 video + AAC audio suitable for the test device.
3. Accurate timed captions (SRT/VTT or burned-in plus an accessible app transcript).
4. Plain-text narration, version/date, estimated duration, voice/license rights, and music/visual asset provenance.
5. Owner acceptance confirming no false statements about working TV2 features.
6. File hashes and source/version mapping so the app can display the exact approved asset.

## Demo APK release gates (separate engineering work)

- Use isolated Android application ID `com.sundara.preview.tv2`. Never overwrite/uninstall the founder's legacy TV2 installation.
- Replace temporary per-run debug signing with a **stable, private**, reproducible signing path. Use protected credentials, never Git history. Validate signer fingerprint and APK SHA-256 in CI.
- Produce a fresh full build for an Android device; independently test installation, update without data loss, first launch, offline/restore, country persistence, List Number resolution, media sequencing, and Bookmarks/Address Book.
- Publish the approved APK through a controlled distribution mechanism with version, hash, compatibility, clear “TV2 Demo / Preview” branding and support contact. No Play Store or production certification is implied.
- On iOS and PWA, repeat player UX and platform-specific test gates; this Android demo work must not be mistaken for TestFlight/App Store readiness.

## Relationship to other work

- Source requirements: [Issue #32](https://github.com/JSweatman/TV2-Development/issues/32)
- Android packaging and signature risk: [Issue #20](https://github.com/JSweatman/TV2-Development/issues/20)
- Android isolated preview guide: [ANDROID_ISOLATED_PREVIEW_TEST_PLAN.md](ANDROID_ISOLATED_PREVIEW_TEST_PLAN.md)
- Approved iOS acceptance: [IOS_DEVELOPMENT_ACCEPTANCE_2026-11-07.md](IOS_DEVELOPMENT_ACCEPTANCE_2026-11-07.md)

**No claim:** This documentation does not generate media, grant access to ElevenLabs, install a Flutter video player, change app behavior, or establish an installable signed release.
