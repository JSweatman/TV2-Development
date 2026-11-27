# Public-only resolver defense — REVIEW ONLY

Stacked on #67's minimal bootstrap, not a migration applied anywhere. No hosted
listing rows or private endpoints were requested. Parent reported a separate
aggregate check with zero currently eligible nonpublic rows; that is not relied
on for filtering and was not repeated here.

## Behavior

The public exact and prefix RPCs must require all of:
`visibility='public'`, `resolution_state='active'`, start <= statement time
(or NULL), expiry > statement time (or NULL). Unknown/NULL visibility is not
public. Nonpublic records must look like absent records, with no name, resources
or destination in the response. This remains a public resolver even when a
caller happens to hold an authenticated key: no authenticated/private lookup
path, owner exceptions, RTA policy or new grant is invented.

`public_visibility.sql` preserves the current function signatures, definitions
except the additional predicate, SECURITY DEFINER/search_path and time gates.
It requires the audited time-gate marker and one expected resolution predicate,
checks repeat application, uses a transaction/lock timeout and checks ACL/owner
preservation. It neither alters tables nor changes grants/RLS. An unexpected
catalog must fail for manual review rather than broad text substitution.
The existing audited_rpc.sql remains an unchanged historical snapshot of the
observed gap; the local runner explicitly applies the defense afterward.

FixtureRepository reads optional visibility/state/time metadata and filters it.
Omitted fixture metadata retains the existing public/active/permanent defaults
for backward-compatible synthetic fixtures only. Supabase mode depends on the
reviewed RPC SQL; a Python-only rollout cannot fix its SQL disclosure gap.
Direct Postgres exact and both prefix forms apply the same predicates. A legacy
001-only database lacks visibility/start/expiry columns: it will fail rather
than silently ignore them. Use the disposable baseline to test; reviewing any
real schema upgrade is a separate action, not an automatic default-public
backfill. Existing migrations and hosted data are untouched.

## Reproduce locally

```
cd backend
TV2_REPOSITORY=fixture python -m pytest -q tests
cd ..
python scripts/test_disposable_bootstrap.py
```

Use an environment containing the existing backend dependencies for the second
command (its direct-query check imports repository.py). The runner requires the
cached pinned Docker image and creates no ports/network connections. It first
verifies the audited old snapshot, then applies the review SQL twice and tests
public eligibility, state/time boundaries and nonpublic exclusion. It also
executes the actual direct Postgres repository query text/parameters through
psql, checking all three forms against public/private/restricted/invitation-only
synthetic rows. API tests prove no hidden name/destination in exact/prefix JSON.

## Approval, rollout and rollback gates (not performed)

Before any hosted action, capture current signatures, function definitions,
owner/ACL and schema metadata again; diff the exact proposal and check the
current time gates. Keep those backups private to the approved operation.
Validate a synthetic canary and normal public resolution after an independently
approved atomic SQL application. Python/SQL deployment order must be coordinated
because Supabase filtering is in RPCs while direct Postgres requires columns.
No editor that can set visibility should ship ahead of that gate.

Prefer fix-forward if a defect appears. Blindly restoring the old RPCs reopens
the nonpublic visibility gap. A rollback requires separate review and a
fail-closed public-resolver disable/maintenance plan before restoring the
captured definitions; preserve ACLs and time gates, then rerun synthetic tests.
Do not use the historical snapshot as an automatic live rollback script.

Limits: disposable Postgres 15 and synthetic fixtures, not live Supabase 17.11,
PostgREST/anon/RLS integration, browser/device proof or full-schema restoration.
No hosted changes, private data, seed, credential, grant or policy copied.
