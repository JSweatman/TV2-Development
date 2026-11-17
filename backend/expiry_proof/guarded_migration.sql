-- Root-reviewed/manual execution only. Transactional and repeatable.
-- Alters ONLY the two existing RPC bodies; no grant/owner/security rewrite.
BEGIN;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS expires_at timestamptz NULL;
DO $migration$
DECLARE
  signature text;
  fn oid;
  before_row record;
  after_row record;
  definition text;
  pattern text := $p$WHERE ([a-zA-Z_][a-zA-Z_0-9]*\.)?resolution_state\s*=\s*'active'$p$;
  matches integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public'
      AND table_name='listings' AND column_name='expires_at'
      AND data_type='timestamp with time zone' AND is_nullable='YES'
      AND column_default IS NULL) THEN
    RAISE EXCEPTION 'Unexpected expires_at column; review required';
  END IF;
  FOREACH signature IN ARRAY ARRAY['public.resolver_get_listing(text,text,text)',
                                   'public.resolver_prefix(text,text,text,integer)'] LOOP
    fn := to_regprocedure(signature);
    IF fn IS NULL THEN RAISE EXCEPTION 'Missing existing RPC %', signature; END IF;
    SELECT proowner,proacl,prosecdef,proconfig,provolatile,prorettype INTO before_row FROM pg_proc WHERE oid=fn;
    definition := pg_get_functiondef(fn);
    IF definition LIKE '%/* tv2-expiry-gate-v1 */%' THEN
      CONTINUE; -- only our tagged change is idempotent
    END IF;
    IF definition ~* 'expires_at' THEN RAISE EXCEPTION 'Existing expiry logic needs manual review'; END IF;
    SELECT count(*) INTO matches FROM regexp_matches(definition,pattern,'gi');
    IF matches <> 1 THEN RAISE EXCEPTION 'Unexpected RPC shape %: % matches', signature,matches; END IF;
    definition := regexp_replace(definition,pattern,
      $r$\& AND (\1expires_at IS NULL OR \1expires_at > statement_timestamp()) /* tv2-expiry-gate-v1 */$r$,'i');
    EXECUTE definition;
    SELECT proowner,proacl,prosecdef,proconfig,provolatile,prorettype INTO after_row FROM pg_proc WHERE oid=fn;
    IF before_row IS DISTINCT FROM after_row THEN
      RAISE EXCEPTION 'RPC security/signature attributes changed: %', signature;
    END IF;
  END LOOP;
END;
$migration$;
COMMIT;
