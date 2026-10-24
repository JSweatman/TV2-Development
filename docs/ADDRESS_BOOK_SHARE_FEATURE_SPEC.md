# List Number TV2 — Address Book & SHARE

**Proposed by:** Founder & Managing Partner, Sundara Technologies LLC  
**Proposal date:** October 24, 2026  
**Status:** Captured / staged for TV2; **not yet implemented**. Labels and visual designs remain open.  
**Tracking issue:** [#17](https://github.com/JSweatman/TV2-Development/issues/17)  
**Related:** [SAVE design](SAVE_BOOKMARK_FOLDERS_NOTIFICATIONS_SPEC.md), [SAVE update-alert issue #15](https://github.com/JSweatman/TV2-Development/issues/15), [local SAVE implementation PR #16](https://github.com/JSweatman/TV2-Development/pull/16).

## 1. The idea

Use the existing saved-listing/collection capability to give individuals both **Bookmarks** and an **Address Book** (working names). Bookmarks are primarily for sources, interests and updates: news, organizations, commerce, sports, artists, public figures, media. Address Book entries are primarily for people with whom the user wishes to communicate: family, friends, colleagues, trusted contacts. **The distinction is the user's intent**, never a platform-inferred label and never an intrinsic classification of the owner of a List Number.

The same identity may be in both collections. A mayor can appear in *Bookmarks/Local Offices* and *Address Book/Local Offices* if the user wants. A sister can appear in an Address Book and be bookmarked for content updates. The user, not Sundara, determines how to organize them.

The Address Book can be structured by region, country, personal relationship, companies, subjects, or any user-created folder name. **Country/region are optional organizational attributes, not required rigid folder categories.** Users may wish to create arbitrary local collections, tags or future nested folders. Do not prematurely fix folder depth or naming.

### Example — Lois (founder story)

- Lois is a reporter who bookmarks public offices, international news, corporations, events, shops and public figures.
- Her Address Book contains personal contacts such as her brother, sister and friends.
- She creates folders such as *Local Offices*, *POTUS*, *International News*, *Bhutan Royal Family*, *Family*, *Friends*, and region/country-based collections.
- A mayor publishes a news-conference announcement; **Lois receives an immediate update only if she explicitly enabled updates for that listing**.
- Lois' sister publishes a personal update about expecting twins named Arthur and Irving; Lois receives it only if the owner intentionally published it to Lois' authorized audience and Lois opted in. The names are an illustrative affectionate nod to A.I.; they are **not** personal data TV2 should store as contact records.
- Lois finds a stroller designed for twins. On the retailer's landing page she sees **Bookmark** and **Share**. Tapping SHARE offers her private Address Book, she selects her sister and confirms. The sister receives a *shared-listing* notification **once private delivery exists**.
- Future discussions may extend this to photos, videos, private messages and WebRTC. None is necessary to implement local Address Book folders.

## 2. Proposed visual navigation

```text
HOME / Personal landing-page experience   [future; authenticated route needed]
   ├── Bookmarks / SAVE
   │      └── User-defined folders (news, sports, local offices, etc.)
   └── Address Book
          └── User-defined folders (family, friends, countries, regions, etc.)

Resolved listing (native preview or authorized partner page)
   ├── Bookmark  → choose Saved folder; owner label or own alias
   └── SHARE     → [initially OS Share / QR]
                   [later] Address Book picker → recipient → Confirm → Deliver
```

**Current product reality:** Flutter TV2 opens on a keypad, not the user's landing page. The keypad HOME control currently clears input; the personal landing-page destination and HOME context switching are not implemented. Don't silently replace a tested HOME behavior. Use a separate temporary Address Book/Saved control until authenticated HOME navigation and device UX acceptance are available.

The resolver does not own HTML of partner-hosted landing pages. Bookmark/share icons require a native TV2 action, a controlled overlay where supported, or partner-provided embed/deep link. Never inject arbitrary scripts into unrelated websites.

## 3. Reusable architecture: one storage service, two collections

Leverage the local `TV2_flutter/lib/saved_collections.dart` identity, folder and bookmark storage. The first SAVE implementation uses device-local SharedPreferences; treat this as a **limited test store**, not final encrypted/synced production data.

**Design for evolution**:

```text
LocalSavedIdentity
  canonicalIdentity             // e.g. 1*529, 91*529, *529
  listingRegistrationId?         // preferred stable ownership generation
  ownerDisplayTitleSnapshot
  userAlias?
  id                            // local stable unique key

CollectionMembership
  savedIdentityId
  collectionKind                // 'bookmark', 'address_book'; could be more later
  folderId
  position

UserFolder
  id
  collectionKind
  label
  optionalParentId?
  optionalUserRegionTag?
  optionalUserCountryIso2?

UserNotificationPreferences     // NO remote push in local-only stage
  identityOrRegistrationId
  ownerContentUpdatesEnabled    // default false
  urgencyPreference?            // instant / digest / off, future
  recipientShareAllowed?        // separately governed
```

Users may save an identity in both and move/copy it without losing either. Duplicated physical records should not produce duplicate subscriptions. Distinguish a personal alias from a publisher's title.

**Important:** The phone country *code* is not a unique country identifier for organization (e.g., multiple NANP countries share +1). Preserve both canonical NID-qualified identity and optional ISO country metadata, without any hardcoded default NID.

A number can be reassigned; an address-book reference should not silently begin delivering to the new owner if its original registration changes. Require registration binding/re-verification for secure routing.

Device-only collections are private. If personal landing page is hosted elsewhere, it should show an **authenticated private view** of the user's collection references, not publicly readable names/folder hierarchy or other people's identities. An optional encrypted backup/sync needs its own opt-in and deletion story; uninstalling current debug builds may erase local collections.

## 4. Share mechanism: three separate capabilities

### 4A. Native OS share (TV2-feasible, limited changes)

- A user presses SHARE on a resolved listing.
- TV2 supplies a **well-defined canonical List Number identity link** to the OS share sheet, so the user can select an installed messaging or mail app.
- Receiver opens URL through an approved HTTPS resolver/app-link protocol.
- No List Number private messaging or recipient notification service is implied; external transport is responsible for delivery.
- Deep-link URL format, host/domain and allowed route must be explicitly designed and tested before distribution. Do not assume the current raw API endpoint is a user-friendly shareable URL.

### 4B. QR share (TV2-feasible, limited changes after link format)

- Generate/share a QR containing the same canonical identity link; the QR image can be **static**, while List Number resolution points it to updated authorized landing pages later.
- A so-called dynamic QR service is not necessary just to change the eventual landing-page destination when the resolver already mediates that identity.
- Expiring invitation QR codes, single-use sharing, protected private content, or tracking/revocation each require purpose-specific signed tokens and authorization; do **not** place private access tokens in openly shareable permanent QR codes.
- Validate the resolved identity and publisher permissions when scanned/opened, including restrictions, reassignment and owner deactivation.

### 4C. Address Book recipient picker + in-app delivery (requires new bounded service)

- Press SHARE -> private Address Book picker -> select eligible recipient -> explicit confirmation -> sender's authenticated delivery request -> trusted relay/partner service -> recipient's private inbox and optional push.
- Local folder membership or a known List Number is **not** evidence of authorized destination routing.
- Need verified sender account and recipient identity/registration, recipient eligibility and permission, secure service token and delivery mechanism; do not use public resolver lookup as a messaging authorization primitive.
- Receiver sees the sender's permitted identity, listing title, optional limited preview, and an **Open** or decline/block action. Store only the minimal message envelope/identity link; content remains on creator's landing-page provider.
- Abuse prevention: sender and recipient rate limits, spam reports, block, revocation, opt-outs, pending recipient enrollment, and minimal retention/deletion.
- Push providers APNs/FCM are transport adapters; app must handle tokens/lifecycle securely and use existing Supabase grant/RLS constraints for any **new** private tables.
- Never imply recipient receives a notification until delivery is implemented and tested, and don't auto-send a share merely by viewing or saving a contact.

## 5. Don't conflate three notification categories

1. **Publisher update notifications:** a listing owner's verified authorized publish event; user must explicitly opt in to each listing or approved content category (covered by SAVE [#15](https://github.com/JSweatman/TV2-Development/issues/15)). Example: mayor's planned press conference, sister's audience-authorized personal update.
2. **Direct share notification:** Lois has intentionally sent a canonical listing to her sister, independent of whether the sister follows that listing. Receiver controls whether incoming shares are allowed; may need to accept a connection/request.
3. **Urgent alerts:** e.g. weather, public safety or emergency information, which require authoritative providers, separate delivery assurances and severity policy. A generic content-change notifier must not claim emergency-service reliability.

All preferences controlled by the user; storing a contact or bookmarking does not enable notifications by default. Publisher's content access rights and the recipient's preferences BOTH apply.

## 6. TV2 development sequencing

| Stage | Deliverable | Dependency | Outcome |
|---|---|---|---|
| A | Address Book view and user-defined local folders; save/move/remove person/organization; owner label or custom alias | Reuse SAVE stage A store and screen patterns | **Suitable for TV2 before V1** |
| B | Native SHARE icon using OS share sheet; optional public QR of canonical List Number link | Approved public redirect/deep-link destination | **Suitable for TV2 if routing standard established** |
| C | HOME/personal landing page and contextual navigation | Authenticated personal landing-page integration | Integrate after personal home route exists |
| D | SHARE -> Address Book recipient -> deliver to another user's app | Account/auth, consent, private message envelope, push/inbox provider | **Do not promise as local-only TV2 feature** |
| E | Owner-publish alerts for opted-in listings | Publisher webhook/fanout described in SAVE #15 | Independent consent-driven service |

Stages A and B can be implemented **without materially altering the resolver grammar**. Stages D and E should be independent lightweight services/adapters and must never expose private Address Book content to the public identity resolver.

## 7. Device / security acceptance checklist

- Add a listing to Address Book and Bookmarks independently; retain the same exact qualified identity; remove it from one without deleting the other.
- Create labels *Family*, *International News*, *Local Offices* and arbitrary additional folder names. Reopen app; verify folder persistence.
- Validate country-based grouping does not confuse US/Canada +1 and distinct US 1*529/India 91*529 or global *529.
- Verify owner titles and private aliases; do not publish private aliases.
- QR/OS Share opens the intended authorized listing even after the landing page URL changes, subject to resolver status/policy.
- Recipient picker only shows **user-authorized** Address Book entries eligible for in-app delivery, not everyone ever viewed or bookmarked.
- No unsolicited direct messages, notifications, or contact sharing without explicit consent.
- A shared link to a restricted landing page does not bypass access controls. A reassigned number cannot impersonate a saved prior person.
- Confirm no persistence across uninstall is promised until backup is designed; test Android and iOS separately.
- Test external provider rejection/errors and airplane-mode behavior.
- Confirm full private messaging and publisher alerts are marked NOT IMPLEMENTED until real service/device acceptance.

## 8. Design decisions preserved as open

- "Address Book" is the founder's preferred **working label**; naming of "SAVE", "Bookmarks", "Contacts Page" and HOME hierarchy not final.
- Users control folder structure, visual design, country/region classification, alias choices; do not enforce a single taxonomy.
- Whether a listing can live in both Address Book and Bookmarks: **recommended yes**, subject to confirmation in UX tests.
- Whether a SHARE picker should appear immediately versus only once in-app delivery exists: avoid giving a nonfunctional recipient picker; use OS Share/QR until private delivery works.
- Whether sender/recipient permissions need relationship confirmation, connection requests or allow lists: design before adding in-app delivery.
- Creator update events, alerts, push defaults and owner privacy remain governed by explicit choice and consent, not inferred relationships.
- Avoid creating a large Sundara-hosted social system. Keep identities and orchestration minimal, partner for communication delivery.

**Conclusion:** Add a local Address Book and link-based sharing to TV2, as a scoped extension of SAVE; reserve actual Address-Book-to-Address-Book push delivery and publisher updates for the authenticated communications layer. This staged approach remains compatible with a January 2027 **planning target**, but does not establish final release readiness or a delivery commitment.

## 9. Founder architecture principle — connections without attention capture (2026-10-24)

List Number should offer familiar social-media **utilities**—saving, contact organization, chosen source updates, private sharing and direct communication—without creating a Sundara-operated social network or designing algorithms to maximize users' session duration. Specifically:

- No mandatory infinite scroll, attention-ranking recommender feed, reward loops or invasive engagement optimization in the List Number core.
- No broad public social-graph database inferred from private Address Book membership, and no behavioral advertising derived from contact collections or messages.
- User-initiated discovery and opted-in source notifications should serve **clear user goals**; users can mute, unsubscribe and choose not to participate.
- Third-party listing owners may independently build social-media-style or community experiences on their own landing pages, under applicable law, platform permission/routing requirements and their own responsibility. That is **their application**, not a mandate to Sundara to replicate, endorse, or host it.
- Sundara remains a lean identity, resolution, permission, private collection/navigation and lightweight communications-orchestration layer; design freedom and presentation belong to listing owners/partners.

**Design test:** Does a new TV2 feature help someone find, keep, share or communicate with the person or source they chose? If its real goal is to make users stay longer, it is outside the core platform's purpose.
