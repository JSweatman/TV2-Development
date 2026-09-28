# TV2 Resolver API Contract — v0.3

## Principle
The resolver answers: **what identity exists here, and which public capabilities are configured?** It does not answer: who may enroll it, who may see CDD, how a call is routed, or what analytics should infer.

## Progressive lookup
`GET /v1/prefix`

Inputs: `input`, optional `country`, optional `limit` (1–20).

Output exposes only: namespace context, List Number/TLDx identity, display name, entity type, exact flag, and a globally unambiguous `qualified_input`. It does not expose resources.

Temporary composition states such as `1*`, `*`, `700@`, and `529.` are accepted by the prefix parser where structurally safe. Marker-only inputs return no namespace enumeration.

## Exact resolution
`GET /v1/resolve`

Strict grammar is required. Exact listing output contains:
- namespace + List Number + optional TLDx;
- display name and entity type;
- template key;
- configured public resources;
- up to nine configured button slots.

Communications resources can exist with `uri = null`. The mobile client interprets that as "capability configured; session service must handle routing." Internal communications destinations must never be inserted into `public_uri`.

## Resource record
- `key`: listing-local stable resource key.
- `type`: capability type such as `web`, `image`, `video`, `audio`, `call`, `video_call`, `text`, `dm`.
- `uri`: only when the destination itself is safe/public (for example a public web or media URI).
- `metadata`: public presentation metadata only; never credentials, protected demographic data, or internal routing addresses.

## Country policy boundary
Base grammar has a current platform maximum of 15 characters. Future country-specific base lengths, telephone-number namespaces, and initial language/locale rules enter through the separate country-policy layer. They are not hard-coded into resolver grammar while founder research remains open.
