# SAVE — Local Collections & Listing Update Alerts

**Product owner:** Sundara Technologies LLC / List Number  
**Founder request:** October 23, 2026  
**Status:** Approved for scoping; staged TV2 feature. **No claim that bookmark sync or content alerts have been implemented.**  
**Tracking issue:** [#15](https://github.com/JSweatman/TV2-Development/issues/15)

## Vision and purpose

Give List Number users a simple, voluntary way to **save sources they care about**, organize them in personal folders, and elect to hear when those sources have genuinely published new content. The feature provides useful, social-media-like continuity without rebuilding a feed, comments system, content platform, or follower-engagement marketplace.

Examples include important public figures, news and weather sources, sports teams, family, friends, organizations, and client relationships. No obligation to participate; no inferred interests or social-credit model.

## End-user journey, as requested

1. A user resolves a List Number and views its authorized landing page. A **bookmark/SAVE icon** is present in the experience.
2. Selecting SAVE opens a menu for **New Folder** or **Existing Folder**.
3. A new folder requires a user-selected label. An existing folder is selectable without creating a duplicate.
4. The bookmark's default name is the **listing owner's chosen title**, with a separate user-editable alias; the user's alias never edits the owner's display name.
5. The saved bookmark appears within its selected folder. A listing may be kept in more than one folder if the user chooses (implementation decision; do not accidentally create duplicate alerts).
6. Folder organization lives primarily **on the user's device**.
7. The list of canonical saved listing references/List Numbers is represented in the **user's own landing-page experience**, privately if the collection is personal.
8. **HOME** opens the user's personal landing page. While on that page, HOME changes context to provide quick access to stored folders; specific gesture and navigation need device acceptance.
9. When the listing owner or their authorized landing-page provider *publishes* new video or content, the platform receives a trusted content-available event and alerts users who opted in to updates for that listing.
10. User may choose whether a notification opens the **new content directly** or opens **Saved Folders**. Do not force this choice during initial scoping.

A bookmark's existence **must not** automatically enroll its owner or viewer in a public follower graph, expose private folder names, or imply that all content changes deserve push notifications.

## Current TV2 reality

- Flutter app: progressive resolver keypad, COUNTRY selector and persistence, native `TemplateScreen` **placeholder detail view** reached by ENTER.
- Resolver: FastAPI identity-resolution reads, external landing-page resource launching, fixture paths and protected metadata separation.
- Personal landing-page navigation, account-specific authentication, arbitrary third-party page integration, notification subscriptions, content publication events and production push token lifecycle **are not implemented**.
- `HOME` on keypad currently clears input. Replacing that button immediately would break an established device interaction; transition only once the personal landing-page route exists.
- Android debug build signing is not stable and the iOS runner is incomplete. A GitHub APK compilation does not count as user-device acceptance.

## Namespace fidelity, records and device model

Never store only the unqualified visible entry (`529`). Save a canonical identity reference:

- Country-scoped: explicit country NID + base + optional TLDx (e.g., `91*529`).
- Global Code: explicit global form (e.g., `*529`), not the current country.
- Prefer an immutable listing **registration ID** in addition to the human-facing List Number, once provided by a verified resolver API.
- Keep owner title snapshot and a separate private user alias; record created/updated timestamps and selected notification preference.
- For the initial local store, key folders and bookmarks by generated local IDs and normalize duplicate canonical references.
- A bookmarked number may cease to exist, be reassigned or change owner. Do not silently send prior followers updates from an unrelated new registrant; track registration/ownership generation or force re-confirmation for ownership transitions.
- Export, sync and restore are distinct from a device-only MVP; uninstalling a debug APK currently loses locally stored folders without an authenticated backup.

Suggested local model:

```text
SavedFolder { id, label, createdAt, order }
SavedBookmark { id, canonicalIdentity, registrationId?, ownerTitleSnapshot,
                userAlias?, folderIds[], savedAt, alertOptIn:false,
                lastNotifiedVersion? }
```

Folder access remains locally governed; authenticated private bookmark manifests can later be synchronized to a partner-hosted storage location and rendered from the user's personal landing page through a permission-checked component. **Never embed the collection as publicly readable metadata** in an externally hosted site. Agree the sync provider and ownership/auth protocol before implementing this phase.

## Lean, event-driven content updates

```text
Landing-page owner / authorized publisher
       |
   Publish new content  [explicit publish event, not merely page edit]
       |
   Signed, scoped webhook / publisher connector
       |
   Lightweight List Number notification-orchestration service
       | verify publisher authorization + listing registration ID
       | validate event ID, version, type, allowed deep link
       | deduplicate, rate-limit, enforce content/access policy
       |
   Opt-in subscription registry  [minimal account/device token mapping]
       |
   Push provider / permitted delivery service (APNs / FCM, adapter)
       |
   Saved-listing users' devices
```

Sundara should not store video, host creator content, scrape entire partner sites, record browsing histories, or build the delivery provider itself.

Publisher metadata/event payload sketch (**not yet a committed public API**):

```json
{
  "event_id": "publisher-unique-idempotency-key",
  "listing_registration_id": "stable-registration-reference",
  "canonical_identity": "91*529",
  "content_version": "publisher-version",
  "content_type": "video",
  "published_at": "ISO-8601 timestamp",
  "content_url": "https://approved-provider.example/new-content"
}
```

A **publisher-authenticated signature or equivalent trusted authorization** is required out-of-band. Avoid accepting unauthenticated owner-supplied claims to trigger push to subscribers. Content URL must be constrained by authorized destinations and permissions. A CMS/landing-page provider may support webhook events; other providers might require a separately approved feed polling/ETag connector. Arbitrary remote web-page edits cannot be detected reliably or cheaply by the current resolver alone.

**Important distinction:** The notification relay requires a private subscription registry and delivery endpoint (e.g. user ID/device push token) to fan out alerts. Device-only folders by themselves cannot receive reliable personalized server-side notifications when the app is closed. This service can be an isolated partner capability; do not make public resolver listing RPCs responsible for private subscription access. If adding Supabase tables, explicitly GRANT only necessary privileges, enable/tune RLS, and audit the October 30, 2026 Data API default grant changes.

## Delivery stages and acceptance

### Stage A — TV2-local Save MVP (small, isolated Flutter changes)

- Save icon on the **native TV2 listing detail/preview**, since we cannot inject code into arbitrary external web landing pages.
- New folder (label), select existing folder, and alias vs owner's original title.
- Local persistence and Saved folders view; clear/remove/edit flows and duplicate handling.
- Stable canonical identity independent of selected default NID.
- Manual access to saved identity through resolver; app may show unavailable state if removed.
- Offline folder browsing remains available, without claim of offline external landing-page content.
- Widget/storage tests + separate Android device acceptance.
- **No push, remote bookmark sync, publisher webhooks, or conversion of keypad HOME yet.**

### Stage B — Native HOME/personal landing page and provider SAVE affordance

- User-specific landing-page route and permission model.
- HOME-from-keypad -> personal landing page; HOME-while-there -> saved folders shortcut (exact interaction user-test).
- App-owned Save overlay or partner-provided bookmark/deep-link action while using external landing pages.
- Authenticated, private synchronization of saved listing **references** into the user's own landing-page experience; folders may remain device-owned as requested.
- Reinstall/multi-device consent/restore, deletion/rights and abuse reviews.

### Stage C — Publication events and opt-in update alerts

- Publisher-verified content-available event connectors, versioning, duplicate suppression, signed events.
- Private user/device subscriptions, explicit opt-in, mute, unsubscribe, access/ownership checks, secure token lifecycle.
- Push provider integration; user-selectable notification destination (specific content vs saved folder).
- Privacy/rate limiting/retention/international law and consent review; prioritize social/sports/new content over **no-guarantee** weather/emergency messaging unless authoritative emergency-feed partners and SLAs exist.
- External partner acceptance tests and security audit.

## Non-goals and decision record

- No Sundara-hosted social feed, comments, creator video CMS, ratings, follower market, or general content moderation.
- No automatic tracking of visits, inferred interests, ad targeting based on private bookmarks, or sale of saved lists.
- No arbitrary external landing-page HTML injection.
- No mandatory notification on every listing content edit, nor emergency alert SLA.
- Do not decide now whether tapping a push opens content or folder; user should be offered a preference.
- No need to change Render pricing, current Supabase grants, or published resolver contracts to implement **Stage A**.

## Dependencies, known limitations and future verification

- Current TV2 `TemplateScreen` is not an actual user-designed third-party landing page.
- Current resolver returns canonical identity in listing detail, but has no stable externally exposed immutable registration ID in the Flutter `Listing` model.
- SharedPreferences is appropriate only for a modest internal test implementation; production collections might need an encrypted/local database plus explicit backup lifecycle.
- Device-only storage means uninstall or device loss can remove folders; warning and eventual optional restoration required.
- Backend still has no authenticated account, notification event registry, or push delivery provider.
- All phases must retain country-code rules, active assigned telephone-number protections, permission boundaries, and the right not to participate.

## Owner decisions preserved, not prematurely resolved

1. Feature name: **SAVE**, bookmark icon, folders, alias.
2. Storage: folders local on user device; listing references accessible from user's personal landing-page experience.
3. HOME is context-dependent only *once* personal landing page exists.
4. Creator update event originates from partner-hosted content; resolver notified, then opted-in users.
5. Notification destination (new content vs folders) user-choice; implementation delayed.
6. High-priority feature; attempt Stage A within TV2 if limited in scope and safe, otherwise keep the rest in roadmap.

**Implementation and acceptance must be reported by stage**, not as an undifferentiated completed SAVE feature.
