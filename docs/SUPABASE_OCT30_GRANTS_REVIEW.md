# Supabase Data API grants — October 30, 2026 change: TV2 security review

**Date:** 2026-10-20; read-only live audit.  
**Project:** List Number TV2 (Supabase); project ref `wzfvdkcqpanekotfwcbm`.  
**Status:** Review/plan only. **No database grants, policies, tables, functions, or project settings were changed during this audit.**  
**Source:** [Supabase official changelog](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically) and [Securing your Data API](https://supabase.com/docs/guides/api/securing-your-api).

## What changes

On **2026-10-30**, Supabase stops automatically granting access to **new** `public` schema tables for existing projects. Existing table grants and RLS policies stay in place. Data API callers need appropriate explicit `GRANT` statements in the same migration as table creation, in addition to RLS and suitable policies. Schema recreate/reset and fresh development branches need the same explicit grants.

A `42501 permission denied for table` API error may include the missing grant in its hint. Do **not** apply broad grants just because an error suggests one: first decide whether that role should be authorized to access the table at all.

## TV2 read-only observations on 2026-10-20

The project is `ACTIVE_HEALTHY`, PostgreSQL 17. Eleven? **No: exactly six** base tables currently exist in `public`, and **all six have RLS enabled**:

| Table | Anonymous SELECT privilege | RLS | Intended direct exposure / notes |
| --- | --- | --- | --- |
| `country_namespaces` | Yes | On | Intentional public read of active country namespace rows; the existing FastAPI backend reads this via Data API |
| `listings` | Yes | On | Direct read restricted by owner policy; public resolver listings are returned by narrow `resolver_get_listing`/`resolver_prefix` RPC functions |
| `listing_destinations` | Yes | On | Owner-only direct read policy; no current rows |
| `user_platform_settings` | Yes | On | Owner-only SELECT/INSERT/UPDATE policies; current phone's NID setting is persisted locally by Flutter |
| `listing_resources` | No | On | Public direct grant withheld; no direct RLS policy; public subset exposed only through resolver RPC |
| `listing_buttons` | No | On | Same boundary as listing_resources |

**Legacy over-grants identified:** `country_namespaces`, `listings`, `listing_destinations`, and `user_platform_settings` currently have `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, and `TRIGGER` privileges granted to both `anon` and `authenticated`, in addition to `SELECT`. This is *not* equivalent to successful API writes: RLS policies limit normal row operations. However **TRUNCATE and REFERENCES are not governed by RLS** (PostgreSQL documentation), and SQL functions operating as these roles can potentially invoke privileged operations. These legacy privileges merit a carefully scoped revoke review and regression testing, separate from the October 30 compatibility change. Do not assume the Data API exposes a TRUNCATE endpoint; it does not use that privilege.

**Existing resolver functions:** `public.resolver_get_listing` and `public.resolver_prefix` are `SECURITY DEFINER` and callable by `anon` and `authenticated`. Their observed definitions filter `resolution_state='active'` and return selected public identity/resource metadata; this is intentional for today's unauthenticated resolver workflow, not carte-blanche to expose private tables. Supabase Security Advisor warns about both; changes to these functions' signature, return shape, ownership, or grants require public-boundary and smoke-test review. A separate `resolve_list_number` function is not executable by `anon` or `authenticated`.

**Current DB default ACL:** `postgres` and `supabase_admin` currently have broad default privilege entries in `public` for anonymous/authenticated roles on future tables, sequences and functions. Supabase plans to change the defaults for new objects; do not depend on today's defaults or assume legacy privilege behavior will be consistent across local resets.

**Security Advisor at review time:** two INFO findings for `listing_resources`/`listing_buttons` (RLS enabled without policies because they are not meant to be directly exposed) and warnings for the two publicly executable SECURITY DEFINER RPCs described above. Treat these as documented intentional choices requiring review, not permission to suppress all warnings indiscriminately. Remediation reference: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable

## Default for future TV2 migrations

1. Classify the new data **before** creating a table: public resolver-safe, authenticated owner-private, restricted/consent/CDD, or internal service-only.
2. Put protected CDD, consent evidence, personal documents and private provider credentials/routing in **non-exposed private schemas** with restricted server-side access. No automatic client access; do not expose private tables because a library's Data API call gets `42501`.
3. For deliberately public metadata tables only, enable RLS and add the minimal relevant policy; explicitly grant `SELECT` to `anon` only if truly public. No broad anonymous write privileges.
4. For owner-private tables needed via the Data API, explicitly grant only needed commands to `authenticated`, enable RLS, and use ownership conditions including explicit `WITH CHECK` for inserts/updates. Do not assume `TO authenticated` alone restricts which user's rows are accessible.
5. Audit the `TRUNCATE`, `REFERENCES`, `TRIGGER` and other extra privileges left by existing schema defaults, particularly for `anon`/`authenticated`. Revoke excess privileges **only in a reviewed migration with before/after functional and privilege tests**, not as part of an unrelated email-response hotfix.
6. For API functions, restrict `EXECUTE` to intended roles and explicitly scrutinize `SECURITY DEFINER` and its effective `search_path`; it bypasses RLS in important common cases.
7. Test from both `anon` and authenticated contexts as appropriate. Run backend and live resolver smoke tests after every permissions change; failures may be either missing GRANT or RLS/policy mismatch. Inspect Supabase Security Advisor again.

Illustrative **migration pattern only** (not a migration to apply; substitute real table, columns and policy):

```sql
-- Create a *new* intentionally public read-only catalogue table.
-- This is a conceptual example; do not run verbatim.
create table public.example_public_catalogue (
  id bigint generated always as identity primary key,
  active boolean not null default false
);
alter table public.example_public_catalogue enable row level security;
create policy example_catalogue_read
  on public.example_public_catalogue
  for select to anon, authenticated
  using (active = true);
grant select on table public.example_public_catalogue to anon, authenticated;
-- Explicitly audit/revoke any additional grants inherited from older defaults.
```

For private enrollment/consent services the correct pattern is different: keep the table **non-exposed** and define narrowly scoped server-side authorization paths, rather than simply copying the above template.

## Next actions (not yet executed)

- Preserve current application stability through October 30; no immediate grant change required for existing working tables.
- Update any new schema migration to include *purpose-specific* explicit grants, RLS policies, and privilege regression checks.
- Plan separate least-privilege clean-up for existing overly broad grants, after testing; decide owner/admin mutation interfaces first.
- Recheck live Supabase grants and advisors after the platform rollout.
- Include this review in the [Astra Read Me First](ASTRA_READ_ME_FIRST.md) handoff, and do not infer that a successful demo proves privacy and authorization controls are production-ready.

**Do not copy service-role secrets, Supabase database passwords, or authenticated user data into GitHub.**
