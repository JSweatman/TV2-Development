-- REVIEW ONLY: never run automatically or as part of application startup.
-- Applies to the audited v2 time-gated RPCs; does not alter signatures or ACLs.
BEGIN;
SET LOCAL lock_timeout = '3s';
DO $guard$
DECLARE signature text; source text; revised text; predicate text;
        before_acl aclitem[]; before_owner oid; fn oid;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
   'public.resolver_get_listing(text,text,text)',
   'public.resolver_prefix(text,text,text,integer)'] LOOP
  fn := to_regprocedure(signature);
  IF fn IS NULL THEN RAISE EXCEPTION 'Expected resolver signature missing'; END IF;
  SELECT pg_get_functiondef(oid),proacl,proowner INTO source,before_acl,before_owner
    FROM pg_proc WHERE oid=fn AND prosecdef AND provolatile='s';
  IF source IS NULL OR strpos(source,'/* tv2-window-gate-v2 */')=0 THEN
   RAISE EXCEPTION 'Expected audited time-gated resolver missing; review catalog';
  END IF;
  predicate := CASE WHEN signature LIKE '%resolver_prefix(%'
    THEN 'l.resolution_state=''active''' ELSE 'resolution_state=''active''' END;
  IF strpos(source,'/* tv2-public-visibility-v1 */')>0 THEN
   IF strpos(source,predicate || CASE WHEN signature LIKE '%resolver_prefix(%'
     THEN ' AND l.visibility=''public'' /* tv2-public-visibility-v1 */'
     ELSE ' AND visibility=''public'' /* tv2-public-visibility-v1 */' END)=0 THEN
    RAISE EXCEPTION 'Visibility marker without expected predicate';
   END IF;
   CONTINUE;
  END IF;
  IF (length(source)-length(replace(source,predicate,'')))/length(predicate)<>1 THEN
   RAISE EXCEPTION 'Ambiguous resolution predicate; manual review required';
  END IF;
  revised := replace(source,predicate,predicate || CASE WHEN signature LIKE '%resolver_prefix(%'
    THEN ' AND l.visibility=''public'' /* tv2-public-visibility-v1 */'
    ELSE ' AND visibility=''public'' /* tv2-public-visibility-v1 */' END);
  EXECUTE revised;
  IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=fn AND proacl IS NOT DISTINCT FROM before_acl AND proowner=before_owner) THEN
   RAISE EXCEPTION 'Function ownership/ACL changed';
  END IF;
 END LOOP;
END $guard$;
COMMIT;
