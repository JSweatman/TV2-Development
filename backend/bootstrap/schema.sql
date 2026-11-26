-- Minimal disposable resolver contract proof, NOT a production migration.
-- Never replay historical 003 after 001. No users/listings are copied.
DO $$ BEGIN
 IF current_database() <> 'tv2_bootstrap_proof' THEN
  RAISE EXCEPTION 'Only the dedicated disposable proof database is supported';
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.listings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 country_code text,
 list_number varchar(15) NOT NULL CHECK (char_length(list_number) BETWEEN 1 AND 15),
 tldx text,
 display_name text,
 entity_type varchar(40) NOT NULL,
 template_key varchar(80) NOT NULL DEFAULT 'basic',
 resolution_state varchar(20) NOT NULL DEFAULT 'active'
   CHECK (resolution_state IN ('draft','active','suspended','retired')),
 visibility text NOT NULL DEFAULT 'public'
   CHECK (visibility IN ('public','restricted','invitation_only','private')),
 starts_at timestamptz,
 expires_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_listing_namespace_v2 ON public.listings
 (COALESCE(country_code,'__GLOBAL__'),list_number,COALESCE(tldx,'__NONE__'));
CREATE TABLE IF NOT EXISTS public.listing_resources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
 resource_key varchar(60) NOT NULL,
 resource_type varchar(40) NOT NULL,
 public_uri text,
 public_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 enabled boolean NOT NULL DEFAULT true,
 UNIQUE(listing_id,resource_key)
);
CREATE TABLE IF NOT EXISTS public.listing_buttons (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
 slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 9),
 label varchar(40),
 resource_id uuid NOT NULL REFERENCES public.listing_resources(id) ON DELETE CASCADE,
 UNIQUE(listing_id,slot)
);
