-- TV2 Supabase transition migration
-- Mirrors the live Supabase changes applied on 2026-10-12.
-- Public resolver data only. Protected CDD, credentials, consent, and private
-- communications routing remain outside the resolver boundary.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS country_code text,
  ADD COLUMN IF NOT EXISTS list_number varchar(15),
  ADD COLUMN IF NOT EXISTS tldx text,
  ADD COLUMN IF NOT EXISTS entity_type varchar(40),
  ADD COLUMN IF NOT EXISTS template_key varchar(80) NOT NULL DEFAULT 'basic',
  ADD COLUMN IF NOT EXISTS resolution_state varchar(20) NOT NULL DEFAULT 'active';

UPDATE public.listings
SET country_code = COALESCE(country_code, nid),
    list_number = COALESCE(list_number, local_identifier),
    entity_type = COALESCE(entity_type, listing_type),
    resolution_state = CASE
      WHEN status = 'active' THEN 'active'
      WHEN status = 'suspended' THEN 'suspended'
      ELSE 'draft'
    END
WHERE country_code IS NULL
   OR list_number IS NULL
   OR entity_type IS NULL;

ALTER TABLE public.listings
  ALTER COLUMN list_number SET NOT NULL,
  ALTER COLUMN entity_type SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_listing_namespace_v2
  ON public.listings (COALESCE(country_code,'__GLOBAL__'), list_number, COALESCE(tldx,'__NONE__'));

CREATE INDEX IF NOT EXISTS ix_listing_resolution_v2
  ON public.listings(country_code, list_number)
  WHERE resolution_state='active';

CREATE TABLE IF NOT EXISTS public.listing_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  resource_key varchar(60) NOT NULL,
  resource_type varchar(40) NOT NULL,
  public_uri text,
  public_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  enabled boolean NOT NULL DEFAULT true,
  UNIQUE(listing_id, resource_key)
);

CREATE TABLE IF NOT EXISTS public.listing_buttons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 9),
  label varchar(40),
  resource_id uuid NOT NULL REFERENCES public.listing_resources(id) ON DELETE CASCADE,
  UNIQUE(listing_id, slot)
);

ALTER TABLE public.listing_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listing_buttons ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.listing_resources FROM anon, authenticated;
REVOKE ALL ON public.listing_buttons FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.resolver_get_listing(
  p_country_code text,
  p_base text,
  p_tldx text DEFAULT null
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing public.listings%ROWTYPE;
  v_resources jsonb;
  v_buttons jsonb;
BEGIN
  SELECT * INTO v_listing
  FROM public.listings
  WHERE resolution_state='active'
    AND country_code IS NOT DISTINCT FROM p_country_code
    AND list_number=p_base
    AND tldx IS NOT DISTINCT FROM p_tldx
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN null;
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'key', r.resource_key,
      'type', r.resource_type,
      'uri', r.public_uri,
      'metadata', r.public_metadata
    ) ORDER BY r.resource_key
  ), '[]'::jsonb)
  INTO v_resources
  FROM public.listing_resources r
  WHERE r.listing_id=v_listing.id AND r.enabled=true;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'slot', b.slot,
      'label', b.label,
      'resource_key', r.resource_key
    ) ORDER BY b.slot
  ), '[]'::jsonb)
  INTO v_buttons
  FROM public.listing_buttons b
  JOIN public.listing_resources r
    ON r.id=b.resource_id AND r.enabled=true
  WHERE b.listing_id=v_listing.id;

  RETURN jsonb_build_object(
    'country_code', v_listing.country_code,
    'list_number', v_listing.list_number,
    'tldx', v_listing.tldx,
    'display_name', v_listing.display_name,
    'entity_type', v_listing.entity_type,
    'template_key', v_listing.template_key,
    'resources', v_resources,
    'buttons', v_buttons
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.resolver_prefix(
  p_country_code text,
  p_base text,
  p_tldx_prefix text DEFAULT null,
  p_limit integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    jsonb_agg(to_jsonb(q) ORDER BY q.sort_exact DESC, q.sort_len, q.list_number, q.tldx NULLS FIRST),
    '[]'::jsonb
  )
  FROM (
    SELECT
      l.country_code,
      l.list_number,
      l.tldx,
      l.display_name,
      l.entity_type,
      CASE
        WHEN p_tldx_prefix IS NULL
          THEN (l.list_number=p_base AND l.tldx IS NULL)
        ELSE (l.list_number=p_base AND l.tldx=p_tldx_prefix)
      END AS sort_exact,
      CASE
        WHEN p_tldx_prefix IS NULL THEN char_length(l.list_number)
        ELSE char_length(COALESCE(l.tldx,''))
      END AS sort_len
    FROM public.listings l
    WHERE l.resolution_state='active'
      AND l.country_code IS NOT DISTINCT FROM p_country_code
      AND (
        (p_tldx_prefix IS NULL AND p_base <> '' AND l.list_number LIKE replace(replace(replace(p_base,'\\','\\\\'),'%','\\%'),'_','\\_') || '%' ESCAPE '\\')
        OR
        (p_tldx_prefix IS NOT NULL AND p_base <> '' AND l.list_number=p_base
         AND l.tldx LIKE replace(replace(replace(p_tldx_prefix,'\\','\\\\'),'%','\\%'),'_','\\_') || '%' ESCAPE '\\')
      )
    ORDER BY sort_exact DESC, sort_len, l.list_number, l.tldx NULLS FIRST, l.id
    LIMIT least(greatest(p_limit,1),20) + 1
  ) q;
$$;

REVOKE ALL ON FUNCTION public.resolver_get_listing(text,text,text) FROM public;
REVOKE ALL ON FUNCTION public.resolver_prefix(text,text,text,integer) FROM public;
GRANT EXECUTE ON FUNCTION public.resolver_get_listing(text,text,text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_prefix(text,text,text,integer) TO anon, authenticated;
