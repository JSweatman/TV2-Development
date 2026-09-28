# TV2 Architecture Boundaries

## Resolver
Database-authoritative, read-only public identity lookup. Fast and deliberately boring. No CDD, consent, AI, analytics, marketplace, provider credentials, or communications sessions.

## Enrollment / country policy
Determines whether an identifier is eligible to be assigned. This is where country-specific telephone-number protection, holder authorization, written consent, reserved ranges, and founder-approved base-length rules belong. The resolver assumes only already-resolvable records can be returned.

## Communications
Provider-independent service boundary for CALL, VIDEO CALL, and async TEXT. The resolver may expose `call`, `video_call`, or `text` capability presence, but private WebRTC/SIP/FreeSWITCH/managed-provider routes belong behind the communications service. FreeSWITCH remains a deferred BETA research candidate, not a TV2 dependency.

## CDD Gateway
Separate protected data service. It validates user authorization, issues approved packets, records audit events, and prevents clients from receiving database access. **CDD means Consumer Demographic Data.**

## CSL
Consumes authorized data packets and aggregates plus resolver/event metrics. It must not turn the resolver into an analytics engine.

## Future-service sockets
GEM, Global Credits, Omni Stream, richer commerce, and other ecosystem services attach through service interfaces. Their failure must not prevent identity resolution.
