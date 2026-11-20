# Private staging media: next approval boundary

This is a design evaluation, not a deployed or staging-ready owner-sign-in/storage
adapter. It remains disabled: no production entrypoint imports the local demo,
no runtime flag mounts its routes, and no hosted auth/storage call is made.
The injected local owner session must never be promoted into a hosted login.

The parent confirmed that the existing Supabase project has no Auth users,
assigned listing owners, Storage buckets, or exact `1*5247` row. The resolver uses
narrow public read RPCs; that credential must not acquire write powers. Existing
Render infrastructure can be considered only after root approves a protected
preview path and verifies current plan/remaining quotas. This task does not create
users, email contacts, buckets, policies, routes, grants, services or deployments.

## Narrow route to a genuine authorized-only demo

1. Root approves two test identities (owner and separate invited viewer) and one
   synthetic staging listing, with server-controlled owner assignment and a viewer
   allowlist. No public signup, anonymous Auth, contact publication or bypass of
   email verification. Use an already approved sign-in method; do not send email
   or create identities as part of this task. The Auth server must validate the
   session, not just decode a user-supplied JWT or trust `user_metadata`.
2. Root approves one **private** bucket with small size/MIME limits and immutable
   object names. Authorize INSERT only when the verified user owns that exact
   listing. Never treat `authenticated` alone or an owner UUID in a client request
   as authorization. No public bucket, blanket table grants or service-role key
   in Flutter. Keep listing ownership immutable to clients; any later update
   policy needs both old-row and new-row ownership checks.
3. A separate default-off server integration on the existing backend validates
   Auth plus current owner/viewer access on every operation. Owner upload goes to
   private quarantine; publish only after isolated validation/transcoding. Published
   metadata references an opaque object/version, not a long-lived bearer URL.
   Existing public resolver responses and anonymous read permissions stay unchanged.
4. The protected preview resolver/byte-delivery path checks the invited viewer,
   resolves the exact listing with the existing grammar, and verifies publication
   before returning/serving media. For strict authorized-only access, prefer a
   same-origin authenticated byte gateway supporting Range and `no-store` over
   putting signed URLs in a public resolver. Signed URLs are bearer capabilities
   usable until expiry; if selected instead, short lifetime and leak/revocation
   limits require explicit acceptance. An unguessable URL is not access control.
5. A private preview can reuse existing backend capacity to serve a gated Flutter
   preview and media gateway under a protected path, leaving the public PWA intact.
   This requires root-approved implementation/deploy, origin/session/CSRF review,
   and capacity validation; the current static PWA does not provide this gate.
   No new service or paid disk is proposed. Render's ephemeral filesystem is not
   durable upload storage. The local ffprobe proof is not a hosted decoder sandbox.
6. Before enabling, test owner A vs owner B vs invited viewer vs anonymous,
   expired/revoked sessions, reassigned ownership, unpublished/deleted media,
   upload limits, cross-origin requests, Range responses and access revocation.
   Existing guest keypad resolution stays available independently.

## Cost boundary

The local TLS/fixture proof needs no hosting spend. Hosted testing can proceed
without **new resources/plan upgrades** only within verified existing allowances;
zero incremental charges cannot be guaranteed from the currently available
billing evidence. Render bandwidth/build minutes and Supabase storage/egress/Auth
usage are metered. Root must verify remaining allowances and spend controls before
any staging write/deploy. Bound the demo to two testers, one <=5 MiB synthetic clip,
a small request budget and deletion afterward; stop at the approved budget.
Do not add Supabase branches/projects, Render services/disks, SMS, paid email,
transforms or third-party media services. If safe isolation/validation cannot fit
existing capacity without added cost, continue locally rather than enable it.

## Official references checked

- [Supabase changelog](https://supabase.com/changelog.md): recent Flutter v3 and
  CLI v3 breaking changes do not require an upgrade here; neither SDK nor CLI is
  added or changed.
- [Auth getUser](https://supabase.com/docs/reference/javascript/auth-getuser):
  authenticated user retrieval is the server-validation boundary to evaluate.
- [Password sign-in](https://supabase.com/docs/guides/auth/passwords.md): hosted
  email verification is preserved; no signup or password/email flow exercised.
- [Private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals.md)
  and [Storage access control](https://supabase.com/docs/guides/storage/security/access-control.md):
  private reads remain controlled; writes require explicit policies. No policies
  from examples were executed.
- [Supabase usage](https://supabase.com/docs/guides/platform/manage-your-usage.md)
  and [Render free limits](https://render.com/docs/free.md): existing plans still
  have metered limits; Render local files are ephemeral.

Minimum next decision: approve the two test identities, synthetic listing ownership,
private bucket/policy design, protected preview route and verified zero-additional-
spend budget. Those are pending setup/approval, not completed integration. No need
to weaken public resolver permissions to reach that next stage.
