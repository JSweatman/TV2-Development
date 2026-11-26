# Open listing availability guard (review only)

Based on #64 d6a28e6b460be5c780d8abeb092ef31e63a9f5b8 (runtime identical
to tested 88d615f55e10aa0a6ace7c5a89a2a6766b235706; added country regression). Separate branch;
#64, #69 and #70 remain unchanged. Backend/browser proof uses #69
22aa61dcd344d1622cde85133117c86834c416e3, disposable synthetic Postgres only.

Normal HomeScreen now wraps each opened TemplateScreen in ListingAvailabilityGate
using its existing ResolverApi. Standalone TemplateScreen/ListingVideoPanel test
fixtures may omit the callback; the normal application path always supplies it.
Exact checks use the original (country, number, suffix), including global scope.
Returned identity must match. No timer, polling or server contract change.

New Website/Social/resource-row actions, CALL/TEXT and other actions through the
shared resource handler check first. Media Load and Play/Replay check first;
Pause/Dismiss/exit remain immediate. A successful check presents Continue/Cancel;
Continue invokes the action in a fresh user gesture, using the current resource
key/URI. This additional tap is intentional to preserve browser popup/media
activation after the async request. No external page is monitored or controlled.
If a refreshed resource disappears, no old resource is launched. Changed media
URIs reset the old controller; the visitor may need to Load the new clip.

On actual reported backgrounding, pending checks/prompts are invalidated and
cached details are hidden. Existing player lifecycle handling pauses playback.
On reported resume, one new exact check runs; it never automatically resumes
playback or executes a pending action. Definitive not_found removes details and
media; transport/malformed-result errors use a distinct reconnect/retry screen.
Back still returns to the keypad. Retry only refreshes; it does not replay actions.
Generation checks prevent late responses from reviving unavailable/disposed data.

Scope: local Save/Address Book collections are not reauthorized by this patch.
The keypad's independent CALL path is outside an already-open listing and is not
changed here. Provider embeds remain unsupported as before. No authenticated
access policy, offline cache policy or entitlement rules are introduced.

Limits: absence of browser lifecycle signals means no resume check can run;
new deliberate resource/media actions still check. No guarantee against changes
between check and Continue, or after opening a destination. Already-fetched bytes,
external tabs and captured content cannot be recalled. Resource servers must
independently enforce any required delivery controls.

Validation: listing_availability_test.dart covers definitive withdrawal for
Website/Load, distinct retry errors, active gesture-confirmed Website/Load/Play,
reported pause/resume and late superseded responses. Existing tests exercise
shared typed CALL/TEXT handling, URI restrictions and keypad/navigation behavior.
Synthetic Chromium verification is recorded separately with actual normal
main.dart -> FastAPI -> disposable Postgres and intercepted inert Website/MP4
only. It does not claim physical-device, installed-PWA or hosted verification.

Browser observed: active Website opened after Continue; media Load then Play
advanced playback after their explicit confirmations. After suspension, B exact
and prefix excluded the record; A Website and fresh Load were blocked with zero
new resource requests. A deliberate 503 showed reconnect/retry, not withdrawal.
Reported lifecycle/stale-response and CALL/TEXT/Social blocking are widget-tested.
