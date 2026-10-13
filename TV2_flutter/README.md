# List Number TV2 Flutter Client

TV2's mobile client consumes the public resolver API hosted on Render.

## Country / NID behavior

TV2 intentionally has **no hard-coded default country code**. On first launch the
client requests `/v1/countries` from the resolver and requires the user to choose
a country/namespace. The selected NID is stored locally and reused until the user
changes it.

An explicitly entered namespace such as `91*529` or a Global Code such as `*529`
continues to override the selected local context according to the resolver grammar.

## Development API

The default API base is `https://tv2-development.onrender.com`.

It can be overridden at build time with:

`--dart-define=TV2_API_BASE_URL=https://example.test`

## Scope

The client is a TV2 test bed. Landing-page presentation, WebRTC provider
integration, CDD, permissions, and enrollment flows are separate layers and are
not fabricated in this checkpoint.
