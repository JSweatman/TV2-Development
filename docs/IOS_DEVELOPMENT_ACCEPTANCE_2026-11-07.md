# TV2 iOS development and acceptance plan

**Initiated:** November 7, 2026  
**January 2027 public-launch target:** critical business milestone, not a claim of completed certification or guaranteed App Store approval.

## Current implementation

TV2 is a Flutter mobile application in `TV2_flutter/`. It already contains the resolver API client, keypad and number-entry UI, numeric NID selection/persistence, listing display, public HTTPS resource launching, Bookmarks, and an on-device Address Book prototype. The live media panel is a **nonfunctional preview placeholder**; WebRTC, translation, account enrollment, private account synchronization and production CDD are not part of the current testbed.

The repository previously had only dynamically generated Android native runners. It had no iOS project, iOS CI or Apple signing workflow.

## What this pull request actually adds

- `.github/workflows/ios-simulator-preview-build.yml`: macOS/Xcode pipeline to generate an iOS runner, run shared Flutter tests, compile a **debug iOS Simulator app**, verify iOS bundle ID `com.sundara.preview.tv2` and display name `TV2 Preview`, and publish an expiring internal simulator archive and hash manifest.
- `scripts/prepare_ios_simulator_preview.sh`: reproducible Flutter iOS project generator and identity gate.
- This checklist: the iOS acceptance gates, launch-critical dependencies, and privacy/security boundaries.

This is a **simulator build only**. It is not an `.ipa`, TestFlight, App Store submission, or evidence that an iPhone has been tested. Signing/provisioning remain separate work.

## January business milestone: minimum demonstrable product

For Squarespace discussions, prioritize a consistent Android/iOS experience:
1. One numeric List Number can be entered and resolved within the selected namespace; `+1` is shown without US/CA/JM dialer suffixes after PR #26 merges.
2. Country/NID selection, saved namespace and numeric input work through restart, offline/reconnect, and normal usage.
3. A verified/authorized List Number opens a real, appropriate digital destination, not only a fixture.
4. Video content and contact pathways (where implemented and permitted) are usable; clearly label nonfunctional WebRTC/AI translation concepts.
5. Bookmarks and local Address Book remain separate and survive app relaunch; do not imply server-sync or mutual contact acceptance exists if it does not.
6. Android and iOS builds are independently signed, tested, documented, and safely installable.

Do not silently substitute an illustrated mock for an implemented feature or activate reserved third-party organization records without authorization.

## Release gates and suggested sequencing

| Period | Gate | Objective proof |
| --- | --- | --- |
| Nov 7–13 | iOS engineering foundation | Mac CI passes iOS Simulator build, bundle-identity verification, Flutter tests, and artifact upload. Android PR #26 release gate continues independently. |
| Nov 14–21 | iOS signing / distribution setup | Apple developer enrollment; owned Apple Team; reviewed production and internal bundle identifiers; private signing/provisioning; check-in and review of stable iOS runner; TestFlight path planned. |
| Nov 21–Dec 5 | iPhone and Android acceptance | Physical device acquisition; iPhone installation and signed-build startup; country/NID, exact lookup, resource, local-data and offline test report; compare Android behavior. |
| Dec 6–20 | Feature and risk stabilization | Authorized landing-page route and cross-platform functional demo; production privacy/security/accessibility review; regression results for both platforms. |
| Dec 21–31 | Release candidate and external readiness | Release freeze, App Store metadata, privacy disclosures, signing, TestFlight external review where needed, App Store submission with review contingency. |
| Jan 2027 | Demonstrable launch milestone | Confirm actual deployment availability; if App Store review is not complete, distinguish TestFlight/controlled demonstration from public availability. |

These dates are planning targets and must be adjusted to demonstrated progress; do not imply Apple review timelines are under Sundara's control.

## Apple prerequisites and access governance

- iOS compilation requires **macOS and Xcode**. The workflow uses a GitHub-hosted macOS runner and does not require a local Mac for an unsigned simulator build.
- A physical iPhone installation requires correct development/Ad Hoc signing or an Apple-approved distribution path. TestFlight/App Store Connect require an Apple Developer Program membership and configured application identifiers.
- No Apple ID password, authentication token, signing private key, certificate password, or provisioning profile may be committed to GitHub source, embedded in public issue text, or printed in CI logs. Prefer authorized Apple accounts and carefully scoped protected secrets; review app permissions and export/compliance documents before release.
- Decide the **production** iOS bundle identifier deliberately. `com.sundara.preview.tv2` is internal-only and must not be silently promoted to a public App Store identifier.
- Generate a stable, checked-in `ios/` runner and a managed signing pipeline before TestFlight; the temporary generator is a bridge, not a permanent release strategy.
- The iOS simulator artifact is for Xcode simulator use on a Mac; **do not try installing it on an iPhone**.
- Android's existing TV2 app must remain intact. Do **not** uninstall the old Android installation; cancel any prompt to update/replace the existing app when testing the isolated preview.

## Physical-device acceptance record (pending)

When a physical iPhone is available:
- Record iPhone model, iOS version, build run, commit hash, bundle ID, signer/team and installation method.
- Verify first-launch selection has **no forced +1 default** and shared +1 behaves as approved; retest after two complete app restarts.
- Exercise `529`, `1*529`, and other **authorized** destinations and verify the selected numeric namespace survives country switching. Use a real authorized digital destination to prove end-to-end resolution.
- Verify loss of connectivity yields a useful error, then recovery succeeds without reinstall.
- Verify video placeholder has no implied live video capability, resource links launch via HTTPS, and Bookmarks/Address Book persist independently.
- Verify accessibility (VoiceOver focus/order, Dynamic Type, safe-area/notch, dark mode), platform dialogs, background/foreground transitions, and crash-free operation.
- Save screenshots and actual results. Do not mark a test PASS until observed on the target device.

## Critical missing pieces

1. **A compiling simulator build** (this CI is the first gate; inspect logs and correct failures).
2. **Stable native iOS project and signing**, including capability and privacy review.
3. **Physical iPhone acceptance**; cannot be replaced by CI.
4. **The minimum working digital destination flow**, with explicitly authorized test identifiers rather than only fixture responses.
5. **App Store preparation and schedule risk**, with a controlled-demo fallback if Apple external distribution is delayed.

The iOS effort must reuse the existing Flutter UI/business logic and the same resolver API. Do not fork a second iOS-only List Number resolver.
