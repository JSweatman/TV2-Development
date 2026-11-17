# Typed EMAIL compose handoff (local review)

Based directly on #45 theme head
`c154ff2a78c9be14ab1eb70ef0c4821b5e24f8a7`; no owner/upload/session experiments
are ancestors of this slice. EMAIL was not previously implemented in the client.

A listing button can reference a resource with this synthetic contract:

```json
{
  "key": "email",
  "type": "email",
  "uri": null,
  "metadata": {"handoff": "device", "address": "demo@example.invalid"}
}
```

Only one conservative ASCII mailbox is accepted. Local parts are at most 64
characters, total address at most 254, DNS-style domain labels at most 63.
Whitespace/control characters, quoted/display-name forms, recipient lists,
encoded input, supplied mailto URLs, query/fragment/body/header fields and unknown
metadata keys are rejected. This is syntax validation, not proof of ownership,
deliverability or support for every RFC-valid international/quoted mailbox.

The six-action layout enables EMAIL only for a valid typed resource. Tapping it
shows the exact recipient and explains that TV2 does not send. Cancel does nothing;
**Compose email** makes one explicit external-app request for a plain
`mailto:recipient`, with no subject/body/CC/BCC/query parameters. Repeated taps
while a request is pending cannot create duplicate handoffs. A false result or
exception shows the recipient for manual composition. Even a reported success
reminds the user what to do if no handler opened.

The existing CALL/TEXT adapter and generic HTTPS validator are unchanged. No new
dependency, backend/schema/configuration change or default email recipient is
introduced. EMAIL also routes through the same confirmed adapter from the normal
listing renderer; invalid typed resources never launch a URL.

All verification uses the synthetic `example.invalid` recipient and an injected
mock launcher. No email client was opened, message sent, real contact used, or
external handler/device behavior claimed. No personal/business data has been
assigned to a List Number. The actual recipient/content for a future page needs
separate approval and is not included here.

Coverage includes typed contract/injection rejection, both theme palettes,
explicit confirmation and cancellation, disabled invalid configuration,
missing-handler/exception fallback, repeated confirmation, and 320×568 at 2× text.
Existing CALL/TEXT, theme, keypad and navigation regressions are included in the
full Flutter run. This branch remains local until root review. The HTTPS browser
session experiment remains blocked; its trust settings were not touched.

Verified: all **90 Flutter tests passed** (seven new EMAIL tests), default release
web build passed, analysis reported no errors and the inherited
`saved_collections.dart:140` warning plus informational notices. The synthetic
recipient is absent from the default compiled bundle. CALL/TEXT and HTTPS
validator files are byte-identical to the #45 base. No remote branch was updated.
