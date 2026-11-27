\set ON_ERROR_STOP on
BEGIN;
INSERT INTO listings(country_code,list_number,tldx,display_name,entity_type) VALUES
 ('1','529',NULL,'Synthetic One','business'),
 ('91','529',NULL,'Synthetic India','business'),
 (NULL,'529',NULL,'Synthetic Global','business'),
 ('1','529','news','Synthetic Suffix','business'),
 ('1','5290',NULL,'Synthetic Longer','business');
DO $$
DECLARE c text; suffix text; item jsonb; rows jsonb; state text;
BEGIN
 FOR c,suffix IN SELECT country_code,tldx FROM listings WHERE list_number IN ('529','5290') LOOP
  -- Every full identity is unique, including global and suffix identities.
  BEGIN
   INSERT INTO listings(country_code,list_number,tldx,display_name,entity_type)
   VALUES(c,'529',suffix,'Duplicate','business');
   RAISE EXCEPTION 'duplicate accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
 END LOOP;
 FOREACH c IN ARRAY ARRAY['1','91',NULL] LOOP
  item := resolver_get_listing(c,'529',NULL);
  rows := resolver_prefix(c,'529',NULL,10);
  ASSERT item IS NOT NULL, 'exact missing';
  ASSERT EXISTS(SELECT 1 FROM jsonb_array_elements(rows) r WHERE r->>'list_number'='529' AND r->>'tldx' IS NULL AND (r->>'country_code') IS NOT DISTINCT FROM c), 'prefix disagrees';
 END LOOP;
 ASSERT resolver_get_listing('1','529','news')->>'display_name'='Synthetic Suffix';
 ASSERT jsonb_array_length(resolver_prefix('1','529','ne',10))=1;
 ASSERT jsonb_array_length(resolver_prefix('1','529',NULL,10))=3;
 ASSERT resolver_get_listing('1','52',NULL) IS NULL, 'partial number must not exact-resolve';
 ASSERT resolver_get_listing('91','5290',NULL) IS NULL, 'namespace isolation';
 FOREACH state IN ARRAY ARRAY['draft','suspended','retired'] LOOP
  UPDATE listings SET resolution_state=state WHERE country_code='91';
  ASSERT resolver_get_listing('91','529',NULL) IS NULL;
  ASSERT resolver_prefix('91','529',NULL,10)='[]'::jsonb;
 END LOOP;
 UPDATE listings SET resolution_state='active' WHERE country_code='91';
 -- Both functions use statement_timestamp: this DO statement freezes the clock
 -- so inclusive start / exclusive expiry can be checked at the exact boundary.
 UPDATE listings SET starts_at=statement_timestamp()+interval '1 second' WHERE country_code='91';
 ASSERT resolver_get_listing('91','529',NULL) IS NULL;
 ASSERT resolver_prefix('91','529',NULL,10)='[]'::jsonb;
 UPDATE listings SET starts_at=statement_timestamp(),expires_at=statement_timestamp()+interval '1 second' WHERE country_code='91';
 ASSERT resolver_get_listing('91','529',NULL) IS NOT NULL, 'exact opening';
 ASSERT jsonb_array_length(resolver_prefix('91','529',NULL,10))=1;
 UPDATE listings SET starts_at=statement_timestamp()-interval '1 second',expires_at=statement_timestamp() WHERE country_code='91';
 ASSERT resolver_get_listing('91','529',NULL) IS NULL, 'exact expiry';
 ASSERT resolver_prefix('91','529',NULL,10)='[]'::jsonb;
 UPDATE listings SET expires_at=statement_timestamp()-interval '1 second' WHERE country_code='91';
 ASSERT resolver_get_listing('91','529',NULL) IS NULL;
 ASSERT resolver_prefix('91','529',NULL,10)='[]'::jsonb;
 ASSERT resolver_get_listing('1','529',NULL) IS NOT NULL, 'permanent unaffected';
 -- Deliberately document the existing RPC gap, not a desired privacy policy.
 UPDATE listings SET starts_at=NULL,expires_at=NULL,visibility='private' WHERE country_code='91';
 ASSERT resolver_get_listing('91','529',NULL) IS NOT NULL, 'audited visibility behavior drifted';
 ASSERT jsonb_array_length(resolver_prefix('91','529',NULL,10))=1;
END $$;
INSERT INTO listing_resources(listing_id,resource_key,resource_type,enabled)
 SELECT id,'web','web',false FROM listings WHERE country_code='91';
DO $$ BEGIN
 ASSERT resolver_get_listing('91','529',NULL)->'resources'='[]'::jsonb;
END $$;
ROLLBACK;
