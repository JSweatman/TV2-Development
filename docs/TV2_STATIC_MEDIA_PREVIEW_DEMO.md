# TV2 tester: visual-only video/media teaser

**Proposed by:** Sundara founder, October 28, 2026.  
**Implemented for review:** October 29, 2026.  
**Status:** Flutter UI branch `feat-static-media-preview-panel`; this document does not imply physical-device acceptance.

## Purpose

The TV2 tester has intentionally focused on resolving List Number identities, country switching, SAVE and Address Book behavior. However, founder demos and early Squarespace-partner conversations need to communicate where video/media will appear in the eventual personal/organization landing-page experience.

This change adds a **dark rectangular media-preview surface** with a play-shaped decoration and unambiguous **COMING SOON** text. It does **not** play videos, request camera/microphone permissions, connect to WebRTC, load third-party content, or send notifications. The play symbol is illustrative only; it is **not a functioning button**.

## Presentation locations

- **Keypad tester / main screen:** a compact static rectangle in the space above search matches and below identity input, only when sufficient vertical space exists. Match list and keypad remain usable; small screens should prioritize input.
- **Native resolved listing preview:** larger 16:9 static preview between listing identity metadata and existing resource buttons.
- **External landing pages:** unchanged; no HTML injection, partner website modification or media ownership assumptions.

Both views use the same reusable Flutter component `TV2_flutter/lib/video_preview_placeholder.dart` with a clear accessibility label declaring video is unavailable in this test build.

## Demo guidance

Say: **“This is a visual placeholder for the planned video/media section. Video playback is not implemented in this TV2 tester.”**

Never describe the play image as interactive or imply completed streaming, recording, calls, secure session management or automatic connection to the user's camera. Real video belongs to a separately specified future WebRTC/playback integration.

## Acceptance criteria

1. On a suitably tall Android screen, main tester displays video/media rectangle while List Number keypad and search results remain usable.
2. Entering `529` continues to resolve the correct country-qualified listing; changing country does not alter explicit identity semantics.
3. Opening a resolved listing shows a 16:9 placeholder labeled COMING SOON.
4. SAVE and Address Book icons remain operable.
5. No request for camera/microphone permission; no player package; no network media calls; tapping the decoration does nothing.
6. Short screens retain an operable keypad, country selector and list even if the media teaser is hidden.
7. Automated Flutter widget checks pass; **physical Android check remains separate**.
8. A developer APK update must not be treated as data-preserving until stable signing, package identity and existing installation compatibility are verified (Issue #20).

## Product boundary

A richer-looking tester is valuable for early pitches, but the TV2 app remains an identity and resolution utility. Landing-page visual design, media assets, hosting and commercial integrations remain primarily partner-controlled. Sundara does not add infinite feeds, behavioral engagement optimization or video-hosting operations merely because a visual panel is shown.
