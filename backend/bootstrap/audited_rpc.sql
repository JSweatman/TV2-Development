-- Exact catalog function bodies observed 2026-11-26; no row data.
DO $$ BEGIN IF current_database() <> 'tv2_bootstrap_proof' THEN RAISE EXCEPTION 'Disposable proof database only'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.resolver_get_listing(p_country_code text, p_base text, p_tldx text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_listing public.listings%rowtype;
  v_resources jsonb;
  v_buttons jsonb;
begin
  select * into v_listing
  from public.listings
  where resolution_state='active' AND (starts_at IS NULL OR starts_at <= statement_timestamp()) AND (expires_at IS NULL OR expires_at > statement_timestamp()) /* tv2-window-gate-v2 */
    and country_code is not distinct from p_country_code
    and list_number=p_base
    and tldx is not distinct from p_tldx
  limit 1;

  if not found then
    return null;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'key', r.resource_key,
      'type', r.resource_type,
      'uri', r.public_uri,
      'metadata', r.public_metadata
    ) order by r.resource_key
  ), '[]'::jsonb)
  into v_resources
  from public.listing_resources r
  where r.listing_id=v_listing.id and r.enabled=true;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'slot', b.slot,
      'label', b.label,
      'resource_key', r.resource_key
    ) order by b.slot
  ), '[]'::jsonb)
  into v_buttons
  from public.listing_buttons b
  join public.listing_resources r
    on r.id=b.resource_id and r.enabled=true
  where b.listing_id=v_listing.id;

  return jsonb_build_object(
    'country_code', v_listing.country_code,
    'list_number', v_listing.list_number,
    'tldx', v_listing.tldx,
    'display_name', v_listing.display_name,
    'entity_type', v_listing.entity_type,
    'template_key', v_listing.template_key,
    'resources', v_resources,
    'buttons', v_buttons
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.resolver_prefix(p_country_code text, p_base text, p_tldx_prefix text DEFAULT NULL::text, p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_exact desc, q.sort_len, q.list_number, q.tldx nulls first), '[]'::jsonb)
  from (
    select
      l.country_code,
      l.list_number,
      l.tldx,
      l.display_name,
      l.entity_type,
      case
        when p_tldx_prefix is null
          then (l.list_number=p_base and l.tldx is null)
        else (l.list_number=p_base and l.tldx=p_tldx_prefix)
      end as sort_exact,
      case
        when p_tldx_prefix is null then char_length(l.list_number)
        else char_length(coalesce(l.tldx,''))
      end as sort_len
    from public.listings l
    where l.resolution_state='active' AND (l.starts_at IS NULL OR l.starts_at <= statement_timestamp()) AND (l.expires_at IS NULL OR l.expires_at > statement_timestamp()) /* tv2-window-gate-v2 */
      and l.country_code is not distinct from p_country_code
      and (
        (p_tldx_prefix is null and p_base <> '' and l.list_number like replace(replace(replace(p_base,'\','\\'),'%','\%'),'_','\_') || '%' escape '\')
        or
        (p_tldx_prefix is not null and p_base <> '' and l.list_number=p_base
         and l.tldx like replace(replace(replace(p_tldx_prefix,'\','\\'),'%','\%'),'_','\_') || '%' escape '\')
      )
    order by sort_exact desc, sort_len, l.list_number, l.tldx nulls first, l.id
    limit least(greatest(p_limit,1),20) + 1
  ) q;
$function$;

-- Local proof is owner-only; this does NOT reproduce hosted grants/RLS.
REVOKE ALL ON FUNCTION public.resolver_get_listing(text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolver_prefix(text,text,text,integer) FROM PUBLIC;
