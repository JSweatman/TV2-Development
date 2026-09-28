# TV2 Engineering Status — 2026-09-25

## Executive status
The first general-purpose identity-resolution foundation is now materially stronger than the 2026-09-23 checkpoint. The backend has a tested local fixture mode and a PostgreSQL repository implementation, the API contract no longer exposes CDD/private WebRTC routing, and the Flutter source has been converted from a hardcoded local JAZ resolver to a backend-driven progressive client.

**Backend unit/contract result:** `25 passed, 12 subtests passed`.

**Neon PostgreSQL production schema:** `LIVE` and verified on 2026-09-28. Neutral resolver fixtures are loaded; exact/prefix/resource SQL read paths were executed successfully against Neon.

**Real localhost HTTP verification:** `PASS` using a live Uvicorn process and fixture repository. Verified readiness, progressive resolution, exact local resolution, explicit foreign-country namespace, Global Code namespace, configured resource exposure, CDD absence, and not-found behavior.

These results do **not** establish PostgreSQL, Flutter compilation, devices, AWS, communications sessions, or production security.

## Implemented/verified in backend
1. **Base-only 15-character rule** — country context and TLDx no longer consume the base List Number allowance.
2. **Strict exact parser** — malformed characters, ambiguous STAR use, adjacent symbols, trailing base symbols, empty TLDx, etc. are rejected.
3. **Progressive parser** — permits safe transitional composition states such as `1*`, `*`, `700@`, and `529.` without ever treating them as exact resolvable identities.
4. **Namespace behavior** — default country, explicit country (`91*...`), and Global Code (`*...`) are distinct.
5. **Progressive resolution** — bounded/deterministic matches; exact flag; `has_more`; globally unambiguous `qualified_input`.
6. **No namespace enumeration on marker-only input** — empty base returns zero matches.
7. **Generic resource architecture** — resources are normalized records (`key`, `type`, optional public URI, public metadata) rather than fixture-specific fields.
8. **Private routing protection** — CALL/VIDEO/TEXT can be advertised as configured capabilities with no internal provider destination in the public resolver response.
9. **CDD separation** — public API models/schema contain no CDD payload or CDD flag.
10. **Resolution state** — only `active` records are returned in PostgreSQL mode; draft/suspended/retired records are excluded.
11. **Repository boundary** — deterministic fixture repository for local development plus PostgreSQL repository for real database mode.
12. **Readiness endpoint** — `/ready` verifies repository availability separately from process `/health`.
13. **Country-policy socket** — country-specific base length, initial language/locale, and telephone namespace policy can be added later without rewriting resolver grammar. No unapproved country rules are shipped.

## Flutter source now implements (not yet compiled here)
- 16-key keypad exactly as the approved 4x4 layout: `1 2 3 @` / `4 5 6 /` / `7 8 9 -` / `* 0 # .`.
- Configurable resolver API URL via `TV2_API_BASE_URL`.
- Default country context via `TV2_DEFAULT_COUNTRY` plus temporary test editor.
- 250 ms progressive lookup debounce.
- Stale-response suppression so older network responses cannot overwrite newer input.
- Exact vs prefix result display.
- Backend-driven listing/resources/buttons; no production hardcoded identity fixture.
- Loading/error/timeout/unavailable-server states.
- Generic template/resource display.
- CALL enabled only when a call capability is configured; absent capability uses exact approved failure wording: `The call cannot be completed.`
- Source tests for input rules, JSON models, and a backend-driven widget path.

## Database design changes
The resolver schema is now capability-oriented:
- `listings`: namespace identity + display/entity/template + resolution state.
- `listing_resources`: arbitrary configured public capabilities; private provider routes deliberately excluded.
- `listing_buttons`: up to nine slots mapped to actual configured resources.

This avoids making restaurant, JAZ, NFL, social-page, or communications-provider examples part of the database architecture.

## Generic test fixtures
Fixtures deliberately exercise different rules:
- same base in different country namespaces;
- same base in Global Code namespace;
- exact/prefix collision;
- optional TLDx;
- symbol-containing base;
- listings with communication capabilities;
- listings with public media/web resource only;
- listing with no resources.

## Still unverified / blocked
- **PostgreSQL runtime:** Neon PostgreSQL is now provisioned and the production schema/fixtures are live. Direct SQL verification passed. Full FastAPI→psycopg→Neon runtime remains unverified because this execution container cannot install `psycopg` (network/DNS is unavailable).
- **Flutter runtime:** Flutter/Dart SDK unavailable here; code/tests are unexecuted. Android/iOS runner directories are also not generated in this source checkpoint; `scripts/bootstrap_flutter.sh` is provided to create them with the installed Flutter SDK.
- **AWS:** deferred for TV2 development. Neon is serving PostgreSQL; Render is connected as the intended development API host.
- **Real communications:** no WebRTC signaling, STUN/TURN, mobile call state, push notification, VIDEO session, or async TEXT delivery yet.
- **CDD/CSL:** architecture boundary defined; live gateway/consent/audit/client packet path not implemented.
- **Production security:** authentication where appropriate, rate limiting/abuse controls, enrollment/trust verification, security headers/gateway policy, audit/monitoring, load/failure testing remain.
- **External resource invocation:** generic public URI is returned and displayed; native URL/media launch adapter remains to be added/tested on Flutter devices.

## Next quality gates
1. Compile and execute Flutter tests in a Flutter-capable environment; correct all compile/runtime issues.
2. Deploy the FastAPI backend to Render with the Neon `DATABASE_URL`, then execute the API acceptance cases against the live Postgres repository.
3. Connect Flutter emulator/device to the running backend and verify progressive → exact → template/resource journey.
4. Add native public-resource launcher adapter and verify safe URI handling.
5. Implement communications service interface/adapter separately from resolver, then real WebRTC CALL/VIDEO and async TEXT.
6. Implement CDD Gateway/consent/audit as a separate protected service.
7. Add abuse controls, observability, failure isolation, and security tests.
8. Deploy only after AWS verification and guided review of each resource.

## Astra handoff principle
Astra should independently reproduce every claimed pass. Any item above labeled unverified remains unverified until Astra (or this model in a capable environment) executes it successfully.


## Infrastructure update — 2026-09-28
- Neon project `TV2 Development` is connected. Production branch has `listings`, `listing_resources`, and `listing_buttons`.
- Neutral fixtures loaded across domestic, foreign-country, Global Code, TLDx, symbol-containing, and resource-capability cases.
- Direct Neon checks verified exact identity lookup, progressive-prefix ordering, resources, and button relationships.
- Render workspace `List Number TV2` is connected and currently has no services.
- `render.yaml` and `RENDER_DEPLOYMENT.md` are included. Render deployment is blocked only by the absence of a Git repository/source URL, not by AWS.
- A Neon-managed `tv2_resolver` role was created while testing least-privilege runtime access; Neon automatically grants it `neon_superuser`, so it is NOT accepted as a production least-privilege solution. A separate raw PostgreSQL `tv2_runtime` role was created with SELECT-only grants and read-only defaults, but its password cannot be safely provisioned through the current connector. This remains a deployment-security gate.
