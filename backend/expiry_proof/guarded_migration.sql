-- Root-reviewed/manual execution only. Transactional and repeatable.
-- Alters ONLY the two existing RPC bodies; no grant/owner/security rewrite.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS starts_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz NULL;
DO $migration$
DECLARE
  signature text;
  fn oid;
  before_row record;
  after_row record;
  definition text;
  pattern text := $p$WHERE ([a-zA-Z_][a-zA-Z_0-9]*\.)?resolution_state\s*=\s*'active'$p$;
  matches integer;
  clock_column text;
  qualifier text;
  gate text;
BEGIN
  FOREACH clock_column IN ARRAY ARRAY['starts_at','expires_at'] LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='listings' AND column_name=clock_column
        AND data_type='timestamp with time zone' AND is_nullable='YES'
        AND column_default IS NULL AND is_generated='NEVER') THEN
      RAISE EXCEPTION 'Unexpected clock column %; review required', clock_column;
    END IF;
  END LOOP;
  FOREACH signature IN ARRAY ARRAY['public.resolver_get_listing(text,text,text)',
                                   'public.resolver_prefix(text,text,text,integer)'] LOOP
    fn := to_regprocedure(signature);
    IF fn IS NULL THEN RAISE EXCEPTION 'Missing existing RPC %', signature; END IF;
    SELECT proowner,proacl,prosecdef,proconfig,provolatile,prorettype INTO before_row FROM pg_proc WHERE oid=fn;
    definition := pg_get_functiondef(fn);
    IF before_row.provolatile <> 's' OR before_row.prorettype <> 'jsonb'::regtype
       OR NOT before_row.prosecdef
       OR before_row.proconfig IS DISTINCT FROM ARRAY['search_path=public']::text[] THEN
      RAISE EXCEPTION 'Unexpected RPC catalog attributes: %', signature;
    END IF;
    SELECT count(*) INTO matches FROM regexp_matches(definition,pattern,'gi');
    IF matches <> 1 THEN RAISE EXCEPTION 'Unexpected RPC shape %: % matches', signature,matches; END IF;
    qualifier := COALESCE((regexp_match(definition,pattern,'i'))[1], '');
    gate := format(' AND (%1$sstarts_at IS NULL OR %1$sstarts_at <= statement_timestamp()) AND (%1$sexpires_at IS NULL OR %1$sexpires_at > statement_timestamp()) /* tv2-window-gate-v2 */', qualifier);
    -- A tag alone never permits skipping review: strip only the exact canonical
    -- predicate, reject all remaining clock references/tags, then reinsert it.
    definition := replace(definition,gate,'');
    IF definition ~* 'starts_at|expires_at|tv2-window-gate|tv2-expiry-gate' THEN
      RAISE EXCEPTION 'Unrecognized clock logic requires manual review: %', signature;
    END IF;
    definition := regexp_replace(definition,pattern, E'\\&' || gate,'i');
    EXECUTE definition;
    SELECT proowner,proacl,prosecdef,proconfig,provolatile,prorettype INTO after_row FROM pg_proc WHERE oid=fn;
    IF before_row IS DISTINCT FROM after_row THEN
      RAISE EXCEPTION 'RPC security/signature attributes changed: %', signature;
    END IF;
  END LOOP;
END;
$migration$;
COMMIT;
