# TV2 Security Gate Checklist

Do not expose TV2 publicly merely because the resolver works locally.

Before any public/BETA endpoint is approved, verify at minimum:

- Enrollment/trust workflow prevents unapproved identities from reaching `resolution_state=active`.
- Country-specific telephone-number protection is enforced in enrollment, not inferred by resolver.
- Resolver database account is read-only and cannot access CDD/consent/private communications schemas.
- Public resolver responses contain no CDD, consent IDs, credentials, private provider routes, secrets, or unnecessary PII.
- Rate limiting/abuse controls exist at the edge and are load tested.
- Input/query limits, database indexes, timeouts, and failure behavior are measured.
- TLS is mandatory outside local development.
- Logs avoid CDD and secrets; retention policy is defined.
- Communications service authenticates/authorizes sessions independently of listing visibility.
- CDD Gateway authenticates both authorization and requested categories; client receives packets, never profile-store access.
- Revocation is tested.
- Optional service outages do not break resolver availability.
- Dependency and container vulnerability scans are clean enough for the test stage.
- Backup/recovery and database migration rollback are tested.
- Real-device privacy permissions and notification behavior are reviewed.

This checklist is a gate, not a claim that these controls are already implemented.
