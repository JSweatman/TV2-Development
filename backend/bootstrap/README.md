# Disposable resolver bootstrap proof

This is a **minimal audited resolver bootstrap**, not a production migration,
Supabase project restore, or editor-ready schema. Existing 001/002/003 files are
unchanged. Never run 003 sequentially after 001: its legacy columns/UUID model
are prerequisites, not changes that 001 creates.

Run from repository root:

```
python3 scripts/test_disposable_bootstrap.py
```

Requires Docker and the already-cached pinned Postgres 15 image in the script.
No pull, public port, remote connection, persistent volume or credential is used.
The script creates a uniquely named, network-disabled disposable container,
uses the dedicated `tv2_bootstrap_proof` database, runs schema + audited RPCs +
assertions twice, checks the wrong-database guard, then removes its container
and anonymous volume. Local trust auth is confined to that isolated container.
SQL files have database-name guards; these are accident guards, not permission
boundaries. Do not run them against any hosted database.

## What was audited (read-only, 2026-11-26)

Canonical List Number TV2 project metadata, PostgreSQL 17.11:
- public listings has UUID id, nullable country_code/tldx, required list_number
  and entity_type, starts_at/expires_at, resolution_state and visibility.
- `uq_listing_namespace_v2` uses country/base/suffix with NULL sentinels.
- Legacy nid/local_identifier are still required. owner_user_id references
  auth.users; no non-internal listing triggers were reported.
- Listings/resources/buttons/country_namespaces have RLS enabled, not forced.
- Two resolver RPCs are STABLE SECURITY DEFINER with fixed public search_path;
  EXECUTE ACL lists postgres, anon, authenticated and service_role.
- Exact and prefix RPC bodies are captured unchanged in audited_rpc.sql, with
  a disposable-database guard and local owner-only execution added around them.
  The local proof revokes default PUBLIC execute; it deliberately does NOT
  reproduce hosted auth roles, policies or grant behavior.

Only system catalogs/information_schema were queried: no listing, user,
resource, credential or private row was read/copied. The checked-in SQL contains
function definitions and synthetic tests only. No catalog change occurred.

## Verified locally

Postgres 15 (not the hosted 17.11 runtime), fresh install and rerun:
- Same digits allowed under +1 and +91; separate NULL/global and suffix identity.
- Duplicate national/global/suffixed full identities rejected. Prefix overlap
  529 vs 5290 remains legal; partial 52 never exact-resolves to 529.
- Exact/prefix agreement and namespace isolation.
- draft/suspended/retired records hidden; permanent active records unaffected.
- Before opening hidden; exact opening visible; before closing visible;
  exact closing and after closing hidden in both RPCs. A single DO statement
  uses statement_timestamp so equality boundaries are deterministic.
- Disabled resources excluded.
- Wrong database rejected, and assertion fixture rows roll back after each run.

## Material gaps before any editor / hosted activation

1. **Visibility:** audited RPCs filter resolution_state and clock only, not the
   separate visibility column. The test documents current behavior by asserting
   an active synthetic private row is returned by both RPCs. This is not an
   endorsement or privacy guarantee. No real private row was checked. Agree and
   review a publication/visibility rule before an editor can create such rows.
2. **Legacy writes:** minimal bootstrap omits legacy nid/local_identifier,
   listing_type/account_tier/status/metadata, owner FK, timestamps and auxiliary
   indexes. Real writes still require legacy mandatory columns; there is no
   observed trigger synchronizing legacy and current identity fields. Canonical
   editor write semantics and backfill policy remain unresolved.
3. **Authorization:** no Auth users/schema, RLS policies, hosted role grants,
   Storage, owner onboarding or write APIs are restored/tested. Tests execute as
   local owner, not anon/authenticated. Do not treat this as permission parity.
4. **Country catalog:** omitted, with no seed copied or applied. This proof is
   exact/prefix SQL only; current country RPC/API metadata is a separate concern.
5. **Whole-number format:** this reproduces existing text identity uniqueness,
   not new normalization (e.g. stripping leading zeroes). Existing resolver
   identity parsing remains authoritative; no normalization policy invented.
6. **Time migrations:** live RPC snapshot includes window-gate-v2, which main's
   historical 003 lacks. This snapshot is only a local reproducibility proof,
   not an instruction to overwrite current hosted functions.

The existing docker-compose.dev.yml selects postgres explicitly (so #66's
mode default does not affect it), but its ./sql mount does not point to the
versioned backend/sql directory. Do not rely on that old compose setup for
canonical restoration. This isolated runner avoids it; it is not repaired here.
