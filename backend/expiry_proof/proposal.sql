-- REVIEW PROPOSAL ONLY. Not an automatic migration. Existing grants unchanged.
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS expires_at timestamptz NULL;

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
    AND (expires_at IS NULL OR expires_at > statement_timestamp())
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
      AND (l.expires_at IS NULL OR l.expires_at > statement_timestamp())
      AND l.country_code IS NOT DISTINCT FROM p_country_code
      AND (
        (p_tldx_prefix IS NULL AND p_base <> '' AND l.list_number LIKE replace(replace(replace(p_base,'\','\\'),'%','\%'),'_','\_') || '%' ESCAPE '\')
        OR
        (p_tldx_prefix IS NOT NULL AND p_base <> '' AND l.list_number=p_base
         AND l.tldx LIKE replace(replace(replace(p_tldx_prefix,'\','\\'),'%','\%'),'_','\_') || '%' ESCAPE '\')
      )
    ORDER BY sort_exact DESC, sort_len, l.list_number, l.tldx NULLS FIRST, l.id
    LIMIT least(greatest(p_limit,1),20) + 1
  ) q;
$$;
