# TV2 / List Number — Read Me First (Astra technical handoff starter)

**Status:** DRAFT, not an authorization to launch or evidence of completed physical-device acceptance.  
**Snapshot date:** 2026-10-19. Reconfirm branch heads, deployments, CI, and external account configuration when the handoff actually happens.  
**Owner:** Sundara Technologies LLC; project: List Number TV2.

## 0. What Astra should do first

1. Read this document, the repository [README](../README.md), [backend API](../backend/src/app.py), [resolver repository boundary](../backend/src/repository.py), [identity grammar](../backend/src/identity_rules.py), [Flutter main entry](../TV2_flutter/lib/main.dart), [Flutter home screen](../TV2_flutter/lib/home_screen.dart), and [public-resource launcher](../TV2_flutter/lib/public_resource_launcher.dart).
2. Inspect current GitHub `main`, open pull requests, CI job details, and Render deployments. **Do not assume this snapshot remains current.**
3. Run automated checks and verify device-build artifacts. Do not mark any device acceptance item PASS solely because Flutter unit tests or debug APK compilation succeeded.
4. Ask for and integrate the user-curated historical archive, contractual records, and product/business materials **only when they are actually supplied**. Do not invent invention dates, chain of title, consent procedures, patent status, or legal conclusions.
5. Preserve the existing product invariants and prioritize reproducible mobile acceptance.

## 1. Authoritative engineering links

- Repository: https://github.com/JSweatman/TV2-Development
- Production/test resolver endpoint: https://tv2-development.onrender.com
- GitHub Actions: https://github.com/JSweatman/TV2-Development/actions
- Render service: `TV2-Development`, deployed from `main`; service ID `srv-dat19kt9fdbs73fh50a0`; Ohio region.
- Supabase-backed resolver read path: see `backend/src/repository.py`; avoid publishing project credentials or private data.

Key historical PRs (check their current state):
- #1 Supabase resolver migration / explicit NID: https://github.com/JSweatman/TV2-Development/pull/1
- #2 Country endpoint: https://github.com/JSweatman/TV2-Development/pull/2
- #3 Flutter restoration and selected NID persistence: https://github.com/JSweatman/TV2-Development/pull/3
- #4 Live smoke checks: https://github.com/JSweatman/TV2-Development/pull/4
- #5 Guarded HTTPS resource navigation: https://github.com/JSweatman/TV2-Development/pull/5
- #6 Retry live smoke checks during Render cold starts: https://github.com/JSweatman/TV2-Development/pull/6
- #7 Android debug build CI + acceptance checklist: https://github.com/JSweatman/TV2-Development/pull/7
- #8 Android build on main and README updates: https://github.com/JSweatman/TV2-Development/pull/8

## 2. Architecture — what exists

- **Flutter client** under `TV2_flutter/`, using HTTP resolver API calls and a local persisted NID selection.
- **FastAPI resolver** under `backend/src/`, endpoints `/`, `/health`, `/ready`, `/v1/countries`, `/v1/resolve`, `/v1/prefix`.
- **ResolverRepository boundary**: fixture mode for tests; Supabase RPC read path in deployed configuration; PostgreSQL adapter retained for portability. Supabase uses narrowly scoped public metadata RPCs `resolver_get_listing` and `resolver_prefix`. Do not broaden resolver access into protected CDD, credentials, consent records, or private communications data.
- **Render** deploys the FastAPI backend from `main`. The Flutter client is *not* deployed as a phone app by updating Render.
- **Public-resource launcher** accepts syntactically constrained HTTPS destinations, rejects local/invalid hostnames and unsupported ports, and handles launcher refusal/errors. This is not website-content verification, DNS public-IP verification, or a guarantee against malicious external destinations.
- **Live smoke suite** checks resolver health, country listing, US/India namespace fixtures, Global Code and prefix matches against the deployed API; retries transient cold-start conditions.

## 3. Non-negotiable List Number behavior

- **NO hardcoded default country NID `1`.** The user selects a country/NID explicitly from server-driven options; this persists locally until changed.
- Same base number under different NIDs may legitimately resolve to different identity records; US `1`, Japan `81`, France `33`, and India `91` are not interchangeable namespaces.
- An explicit qualified namespace or Global Code uses its own syntax; the country code is context, not a fixed global prefix.
- Country-specific telephone-number protection and verification belong in enrollment/consent/policy services, not the basic resolver grammar. Legitimate assigned active telephone-number holders must retain their rights, including the right not to participate.
- Landing pages are **external experiences**. The resolver should manage identity, policy/permissions, and routing—not become a full website builder or data warehouse.
- Lean-core principle: identity, resolution, permissions/access rules, routing and lightweight orchestration; partner for mature capabilities.
- Country code is also a language/context cue; desired translation behavior is **not yet verified in TV2** and must be tested rather than presumed.

## 4. State of validation at drafting

The most recently confirmed runs on PR #7's development head `5d09671...` passed **backend**, **Flutter**, **live-smoke**, and **Android debug APK** workflows. An Android debug artifact of approximately 73 MB was uploaded; CI artifacts are temporary and expire. PR #7 was merged as `c1ee2c5...` on 2026-10-19. PR #8 was open/pending verification at the time this document was prepared; confirm current state.

The running Render service deployed `c1ee2c5...` successfully on 2026-10-19. Recheck the deployed commit before claiming a later deployment.

**NOT YET VERIFIED:** physical Android installation/use, iOS simulator compile, physical iPhone/TestFlight use, production signing, translation prompt, complete CDD/consent workflows, CALL/VIDEO/TEXT provider sessions, production mobile release package.

## 5. Runbooks for safe verification

Local backend tests (requires Python 3.12 + dependencies):
```sh
cd backend
python -m pip install -r src/requirements.txt pytest
TV2_REPOSITORY=fixture pytest -q tests
```

Live integration test **targets the current deployed resolver and depends on provisioned fixture records**:
```sh
python scripts/live_smoke_test.py
```

Flutter tests (requires Flutter stable):
```sh
cd TV2_flutter
flutter pub get
flutter test
```

Android test build: inspect the `android-debug-build` GitHub Actions workflow. The workflow generates a temporary Android runner using `flutter create` because the native platform directories are not yet checked in, builds `app-debug.apk`, and uploads a short-lived artifact. This **does not** represent production signing, a stable app ID, or completed installation testing.

iOS: a macOS/Xcode environment, generated and properly configured iOS runner, simulator validation, appropriate signing/distribution, and a physical iPhone acceptance session are separate pending tasks. Do not purchase Apple Developer Program membership until the physical distribution path requires it.

Environment configuration: `TV2_REPOSITORY=supabase`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` are expected in the Render service; never paste actual keys into this file or into chat transcripts. Mobile API base can be set using `--dart-define=TV2_API_BASE_URL=...`. Confirm secrets and access scopes privately in the appropriate provider consoles.

## 6. Mobile acceptance gates

For each platform independently (Android / iOS): record **PASS, FAIL, NOT TESTED**, device/OS/build identifier, test fixture, timestamp, evidence, and any GitHub issue.

1. Clean install; app loads; **no implicit US NID**.
2. Explicit country selection and persistence after force-close/relaunch.
3. Switch US/India known fixtures to verify namespace isolation; provision separate JP/FR fixtures before claiming JP/FR `101` scenario passed.
4. Progressive prefix and exact resolution; correct resources and buttons.
5. Allowed HTTPS launch, invalid/unsafe URL refusal, graceful launcher error, back-to-app navigation.
6. Offline/network recovery, loading/error UI, low-memory/resume behavior, accessibility text scaling.
7. Actual foreign-language landing page opening and intended translation-prompt behavior.
8. HOME double-press/two-second-hold behavior only when implemented; otherwise mark DEFERRED and explain.
9. CALL/VIDEO/TEXT and CDD only when those integrations exist; never confuse a configured capability indicator with a working provider session.

## October 30 Supabase migration safety note

Read the [October 30 Data API grants and security audit](SUPABASE_OCT30_GRANTS_REVIEW.md) before creating or resetting database schemas. Existing TV2 tables retain their grants, but new `public` tables need explicit role grants and deliberate RLS in their migrations. The audit also identifies broad legacy privileges that should be reviewed in a separate tested change, not revoked as an unverified hotfix.

## 7. Blockers / follow-on engineering

- Check CI/merge status for PR #8; if necessary, correct failed workflow and retest before merging.
- Establish **checked-in**, reviewed Android and iOS native runners with stable identifiers, platform permissions, proper app links, and signing strategy.
- Produce reproducible Android test packages, then collect real-device evidence. Arrange hosted macOS/Xcode and iPhone testing later.
- Build out complete permissions/consent/CDD boundary and provider integrations without placing protected data on the public resolver.
- Define content classification (personal/business, adult/restricted/NSFW), partner-hosted landing-page flows, and access decisions at enrollment/routing layer.
- Confirm HOME gesture specification and translation behavior with user/device testing.
- Audit logs, resource navigation threats, internationalization, accessibility, provisioning, monitoring, privacy, and recovery procedures before launch.
- Consolidate the user's historical materials, Fiverr development contracts/logo provenance, invention timeline, and IP documents only after user provides/approves their inclusion.

## 8. Handoff readiness rule

**Not Astra-handoff-ready** at this checkpoint. This file is a preliminary engineering index, **not** the complete cross-project historical archive, operational runbook, legal/IP package, or acceptance report.

An actual handoff packet should contain:
- Frozen, cited revision manifest (repository SHA, deployed SHA, CI runs, native build/artifact identifiers).
- Product requirements and business decisions with clear source/version/date; no invented legal status.
- Secrets/access inventory (providers, account owners, scopes, recovery procedure) **without literal passwords or tokens**.
- Architecture diagrams, schema migrations and RPC contracts; policy/data separation evidence.
- PASS/FAIL/NOT TESTED device matrices and residual-security-risk register.
- Prioritized execution backlog and explicit user decisions still needed.
- Curated historical archive index and chain-of-title review notes.

**First rule for Astra:** verify reality at transfer time and preserve prior decisions rather than repeating or replacing completed work.
