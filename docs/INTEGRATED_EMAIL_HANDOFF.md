# Typed EMAIL on the shared local candidate

Local branch based on aa269559a7fabafa4fae49d6894f691142ea940a.
Adapted adapter from65ec4829a18f8e20dd0db56d3b601bbb7c1ede1f; no YouTube or
owner-upload changes imported. No backend/schema/dependency/release changes.

Normal TV2App -> HomeScreen -> TemplateScreen accepts an optional injected email
launcher for tests. Listing EMAIL calls the existing qualified availability gate
first; after a fresh response and Continue it reads the current resource by key,
then presents the recipient in Open email app?. Only Compose email invokes the
external-app launcher. Cancel does nothing. Withdrawn listing blocks; transport
failure remains reconnect/retry; removed EMAIL cannot launch, and an invalid
replacement is rejected. Existing basic and themed rendering both use this path.
Current themed UI omits unconfigured actions, including invalid EMAIL.

Synthetic configuration (not a default recipient):

```json
{"key":"email","type":"email","uri":null,
 "metadata":{"handoff":"device","address":"demo@example.invalid"}}
```

The adapter accepts one conservative ASCII mailbox; rejects recipient lists,
unknown metadata, control characters, URL/encoded/header/body/query injection.
It creates a plain mailto:recipient with no body/subject/CC/BCC/query/fragment.
Syntax validation is not mailbox ownership, authorization or deliverability.
The generic HTTPS validator remains unchanged. No address is built from a List
Number. No sending API exists; actual empty composer/draft behavior depends on
the platform handler and has not been exercised here. Missing handler or thrown
launcher produces manual fallback. Confirmation has duplicate-tap suppression.
Availability is checked at the existing action checkpoint, not continuously;
external apps or already sent content cannot be controlled or recalled by TV2.

## Verification

Existing adapter tests adapted only for current hidden-invalid-action behavior.
New email_availability_test.dart exercises actual TV2App: country context +1,
keypad529, ENTER, EMAIL, held exact1*529 lookup, Continue, then Compose email.
Nine cases cover valid empty compose intent, changed recipient, withdrawn,
removed, invalid, offline, cancellation at both prompts, and no handler. All use
example.invalid addresses and an injected launcher; no email client is opened.
Both gates assert zero launches until final user gesture. Changed-recipient case
asserts only the refreshed address appears and is handed off. Existing tests
cover strict contract, themes, duplicate confirmation, exceptions and320px/2xtext.

CALL/TEXT adapter, HTTPS launcher and availability-gate files are byte-identical
to base; their regression tests run alongside EMAIL. This is widget/UI evidence
and a release web compile, not browser/native mail-app or physical-device proof.
No live data, messages, DB/Des/Android changes, push or deployment.

Verified on Flutter3.50.0 / Dart3.14.0:
- Full suite185 passed, including9 new gated cases and7 adapter cases.
- Default normal-entrypoint release web build passed; no tutorial/sample config.
- main.dart.js SHA25632b122a1e888103bcaba4ada386dfb24ecb634e720db3e98f1f6e4a13e2a4678.
- Synthetic test addresses absent from the default compiled main.dart.js.
- Analysis completed with43 findings: no errors, four inherited warnings and39
  informational deprecations (including Material imports in imported adapter/test).
Logs retained at /workspace/tv2-local-integration-evidence/email-integration.
Initial test-port failures involved old text-ENTER/disabled-action assumptions
and scrolling without a settled frame; final tests use actual tooltip control,
current omitted-action behavior, and settled visible EMAIL. Runtime guards were
not relaxed to pass tests. Generated web runner files remain untracked.
