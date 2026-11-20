# Optional AI World Takeover Probability Index widget (prototype)

This is an **isolated, static landing-page prototype**, not a change to the Flutter keypad or a live deployment.

## Embed on a landing page

Host `ai-takeover-index.js` over HTTPS and add:

```html
<script defer src="/ai-index/ai-takeover-index.js"></script>
<ai-takeover-index enabled="true"
  src="https://YOUR-PUBLISHING-HOST.example/ai-index/current.json"></ai-takeover-index>
```

Opt-out: omit `enabled` or set `enabled="false"`; no fetch occurs. The host site's owner-settings system must save the per-page opt-in and render the attribute from that setting. `demo.html` uses localStorage for demonstration **only** (not cross-device or owner-account persistence).

The data document shape is:

```json
{"level":2,"commentary":"A short satirical explanation.","published_at":"2026-11-20T14:00:00Z","status":"published"}
```

Only integers 1 through 5 are valid; level descriptions are fixed by code. `status: "demo"` makes the demo disclaimer visible. The widget escapes the untrusted commentary by rendering it as text; invalid/unreachable data generates a fallback. Disable caching or apply a short TTL on the publishing host.

## 1400Z publishing gap

A ChatGPT daily automation is scheduled for **14:00 UTC** to issue a new bulletin, but that automation **does not currently write this JSON to production**. The bundled `current.json` is intentionally marked `demo`. A separately authorized scheduler/publisher must:
1. generate or obtain an approved satirical daily bulletin;
2. validate integer level, length-limited commentary, and UTC publication timestamp;
3. atomically publish `current.json` at 14:00 UTC, keeping prior known-good data if publishing fails;
4. ensure all landing pages fetch the same globally shared feed;
5. verify publication observability and avoid embedding secrets or write credentials in the browser.

Deployment needs a confirmed landing-page host and owner-settings persistence mechanism. Avoid coupling index publication to the identity resolver, and do not claim the score has scientific meaning. Related issue: #53.
