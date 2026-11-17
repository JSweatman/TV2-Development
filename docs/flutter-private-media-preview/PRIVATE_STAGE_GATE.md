# Invite-only synthetic stage: go/no-go

**Current decision: NO-GO for hosted activation.** This draft packages local proof;
it does not authorize provisioning, credentials, account creation, configuration
changes, deployment, public links or real uploads.

Root may authorize a separate minimal stage only when every item below has an
identified owner and passing evidence:

- [ ] **Isolated entry point:** an approved, access-restricted gateway and explicit
  preview build; never mount local routes on the existing internet-facing resolver.
  Ordinary TV2 remains registration-free with no owner controls or default media.
  No new service or spend without separate approval.
- [ ] **Two invited synthetic identities:** sign-in only for explicitly approved
  owner/viewer accounts; no open signup, anonymous writes or self-assigned ownership.
  Bind the owner to one authoritative exact listing ID and grant the other account
  read-only playback. Prove mismatched owner, wrong listing and uninvited viewer deny.
- [ ] **Private storage and trusted publication:** one bounded MP4-only private
  bucket, no direct client object policies, server-only credentials, and separate
  owner-checked upload/publication. Keep credentials out of bundles, URLs and logs.
  Use synthetic clips only; retain public resolver HTTPS guards unchanged.
- [ ] **TLS/session gate:** approved HTTPS origin, Secure+HttpOnly+SameSite cookies,
  strict Origin/CSRF checks, bounded session lifetime, logout/revocation policy and
  tests. Local proof uses HTTP loopback and in-memory sessions; it does **not**
  validate production TLS, refresh, distributed sessions or immediate JWT revocation.
- [ ] **Ingest gate:** isolated decoder/transcoder with time/memory limits, upload
  size/duration/type enforcement, quotas/rate limits, integrity checks and private
  orphan cleanup after cancellation/failure. Current single-process ffprobe tests
  synthetic clips; they are **not** untrusted-upload sandbox/security certification.
- [ ] **Review/stop rule:** separately authorize activation, verify allowed viewer
  playback and all denials on that exact configuration, then retain a rollback and
  deletion plan. No real contacts/media, public invitations or APK handoff.

Minimum successful stage: one authorized synthetic owner uploads and explicitly
publishes one tiny clip; one separately authorized synthetic viewer explicitly
loads/plays it; everyone else is denied. Native clients, device testing, public
media distribution and general owner enrollment remain out of scope.

## Packaging review

Reviewed stack ancestry: #45 `c154ff2a78c9be14ab1eb70ef0c4821b5e24f8a7` →
local provider proof `b9bdf1b280c67ae8c382cddf0ba3cdc4b7fd242a` → Flutter proof
`348f3610b337d61dca413d1b2af9a16fb78036d2`. The five-number commit is not an ancestor.

The stack changes no live endpoint/configuration, public URL validator, Android
identity, dependency list or existing workflow. The backend Dockerfile includes
only `src` and fixtures, excluding the local integration package. Production Dart
entrypoints do not import preview tools. The default release JavaScript was checked
for preview control/session-route markers; none were present. The sole shared UI
change is an optional trusted widget injection; it is not resolver-configurable.

Reviewed changed text/history and three synthetic screenshots: no generated secret
values, token literals, real contact data, private reference assets, MP4/VTT,
credentials files, databases or private media are included. Pattern scanning
supports this review; it is not a guarantee that arbitrary secrets can be detected.
Existing operational limits remain explicit rather than being treated as safe to
activate on an internet-facing service.
