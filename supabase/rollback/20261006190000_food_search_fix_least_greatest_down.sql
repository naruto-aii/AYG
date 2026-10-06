-- Undo 20261006190000. Puts pg_catalog.least/greatest back.
-- Do not run this on production: that database already uses the unqualified form,
-- and restoring the qualified calls brings back the search error.

CREATE OR REPLACE FUNCTION public.food_search_edit_distance(p_left text, p_right text)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  left_text text := coalesce(p_left, '');
  right_text text := coalesce(p_right, '');
  left_len integer := pg_catalog.char_length(left_text);
  right_len integer := pg_catalog.char_length(right_text);
  prev integer[];
  curr integer[];
  i integer;
  j integer;
  cost integer;
  del integer;
  ins integer;
  rep integer;
begin
  if left_len > 16
     or right_len > 16
     or pg_catalog.abs(left_len - right_len) > 2 then
    return 99;
  end if;
  prev := pg_catalog.array_fill(0, array[right_len + 1]);
  for j in 0..right_len loop
    prev[j + 1] := j;
  end loop;
  for i in 1..left_len loop
    curr := pg_catalog.array_fill(0, array[right_len + 1]);
    curr[1] := i;
    for j in 1..right_len loop
      if pg_catalog.substr(left_text, i, 1) = pg_catalog.substr(right_text, j, 1) then
        cost := 0;
      else
        cost := 1;
      end if;
      del := prev[j + 1] + 1;
      ins := curr[j] + 1;
      rep := prev[j] + cost;
      curr[j + 1] := pg_catalog.least(del, ins, rep);
    end loop;
    prev := curr;
  end loop;
  return prev[right_len + 1];
end;
$function$;

CREATE OR REPLACE FUNCTION public.search_official_foods_fuzzy(p_query text, p_limit integer DEFAULT 30)
 RETURNS TABLE(food_code text, food_group text, index_no text, name text, display_name text, reading text, base_amount numeric, unit_type text, refuse_pct numeric, kcal numeric, protein_g numeric, fat_g numeric, carb_g numeric, fiber_g numeric, salt_eq_g numeric, matched_alias text, matched_alias_reading text, match_rank integer, is_candidate boolean, candidate_rank integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_query text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_limit integer := pg_catalog.least(pg_catalog.greatest(coalesce(p_limit, 30), 0), 100);
begin
  if pg_catalog.char_length(v_query) < 3
     or pg_catalog.char_length(v_query) > 16
     or v_limit = 0 then
    return;
  end if;

  return query
  with scored as (
    select
      f.food_code,
      f.food_group,
      f.index_no,
      f.name,
      f.display_name,
      f.reading,
      f.base_amount,
      f.unit_type,
      f.refuse_pct,
      f.kcal,
      f.protein_g,
      f.fat_g,
      f.carb_g,
      f.fiber_g,
      f.salt_eq_g,
      null::text as matched_alias,
      null::text as matched_alias_reading,
      false as is_candidate,
      public.food_search_edit_distance(f.normalized_name, v_query) as edit_distance
    from public.official_foods f
    where pg_catalog.char_length(f.normalized_name)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(f.normalized_name, v_query) between 1 and 2
    union all
    select
      f.food_code,
      f.food_group,
      f.index_no,
      f.name,
      f.display_name,
      f.reading,
      f.base_amount,
      f.unit_type,
      f.refuse_pct,
      f.kcal,
      f.protein_g,
      f.fat_g,
      f.carb_g,
      f.fiber_g,
      f.salt_eq_g,
      null::text,
      null::text,
      false,
      public.food_search_edit_distance(f.spoken_normalized, v_query)
    from public.official_foods f
    where f.spoken_normalized is not null
      and pg_catalog.char_length(f.spoken_normalized)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(f.spoken_normalized, v_query) between 1 and 2
    union all
    select
      f.food_code,
      f.food_group,
      f.index_no,
      f.name,
      f.display_name,
      f.reading,
      f.base_amount,
      f.unit_type,
      f.refuse_pct,
      f.kcal,
      f.protein_g,
      f.fat_g,
      f.carb_g,
      f.fiber_g,
      f.salt_eq_g,
      a.alias,
      a.reading,
      true,
      public.food_search_edit_distance(a.normalized, v_query)
    from public.official_food_aliases a
    join public.official_foods f on f.food_code = a.food_code
    where pg_catalog.char_length(a.normalized)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(a.normalized, v_query) between 1 and 2
  ),
  best as (
    select distinct on (scored.food_code)
      scored.*
    from scored
    order by scored.food_code, scored.edit_distance, scored.matched_alias
  ),
  close as (
    select best.*
    from best
    where best.edit_distance = 1
       or (
         best.edit_distance = 2
         and pg_catalog.char_length(v_query) >= 5
         and not exists (
           select 1 from best as nearer where nearer.edit_distance = 1
         )
       )
  )
  select
    close.food_code,
    close.food_group,
    close.index_no,
    close.name,
    close.display_name,
    close.reading,
    close.base_amount,
    close.unit_type,
    close.refuse_pct,
    close.kcal,
    close.protein_g,
    close.fat_g,
    close.carb_g,
    close.fiber_g,
    close.salt_eq_g,
    close.matched_alias,
    close.matched_alias_reading,
    3,
    true,
    close.edit_distance
  from close
  order by close.edit_distance, close.food_code
  limit v_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.search_public_foods(p_query text, p_limit integer DEFAULT 50)
 RETURNS TABLE(user_id uuid, food_id text, visibility text, status text, moderation_status text, name text, normalized_name text, base_amount numeric, unit_type text, serving_unit_label text, kcal_per_base double precision, protein_per_base double precision, fat_per_base double precision, carb_per_base double precision, source_type text, barcode text, brand text, supplementary_weight text, official_food_code text, official_food_name text, source_attribution text, copied_from_food_id text, copied_from_owner_user_id uuid, use_count integer, last_used_at timestamp with time zone, report_count integer, version integer, created_at timestamp with time zone, updated_at timestamp with time zone, deleted_at timestamp with time zone, match_rank integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_name text := pg_catalog.lower(
    pg_catalog.regexp_replace(pg_catalog.btrim(v_raw), '[[:space:]]+', ' ', 'g')
  );
  v_voice text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_barcode text := pg_catalog.btrim(v_raw);
  v_limit integer := pg_catalog.least(pg_catalog.greatest(coalesce(p_limit, 50), 0), 100);
  v_pattern text;
  v_prefix text;
  v_voice_pattern text;
  v_voice_prefix text;
begin
  if auth.uid() is null or v_limit = 0 then
    return;
  end if;
  if v_name = '' and v_barcode = '' then
    return;
  end if;

  v_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(pg_catalog.replace(v_name, '\', '\\'), '%', '\%'),
         '_',
         '\_'
       )
    || '%';
  v_prefix :=
    pg_catalog.replace(
      pg_catalog.replace(pg_catalog.replace(v_name, '\', '\\'), '%', '\%'),
      '_',
      '\_'
    )
    || '%';

  return query execute format(
    $sql$
    select
      sf.user_id,
      sf.food_id,
      sf.visibility,
      sf.status,
      sf.moderation_status,
      sf.name,
      sf.normalized_name,
      sf.base_amount,
      sf.unit_type,
      sf.serving_unit_label,
      sf.kcal_per_base,
      sf.protein_per_base,
      sf.fat_per_base,
      sf.carb_per_base,
      sf.source_type,
      sf.barcode,
      sf.brand,
      sf.supplementary_weight,
      sf.official_food_code,
      sf.official_food_name,
      sf.source_attribution,
      sf.copied_from_food_id,
      sf.copied_from_owner_user_id,
      sf.use_count,
      sf.last_used_at,
      sf.report_count,
      sf.version,
      sf.created_at,
      sf.updated_at,
      sf.deleted_at,
      case
        when sf.normalized_name = %L or sf.barcode = %L then 0
        when sf.normalized_name ilike %L escape '\' then 1
        else 2
      end as match_rank
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and public.is_saved_food_visible_to_viewer(sf.user_id)
      and (
        sf.normalized_name = %L
        or sf.normalized_name ilike %L escape '\'
        or (%L <> '' and sf.barcode = %L)
      )
    order by 31, sf.updated_at desc nulls last, sf.food_id
    limit %s
    $sql$,
    v_name, v_barcode, v_prefix,
    v_name, v_pattern, v_barcode, v_barcode,
    v_limit
  );
  if found then
    return;
  end if;

  if v_voice = '' then
    return;
  end if;

  v_voice_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(pg_catalog.replace(v_voice, '\', '\\'), '%', '\%'),
         '_',
         '\_'
       )
    || '%';
  v_voice_prefix :=
    pg_catalog.replace(
      pg_catalog.replace(pg_catalog.replace(v_voice, '\', '\\'), '%', '\%'),
      '_',
      '\_'
    )
    || '%';

  return query execute format(
    $sql$
    select
      sf.user_id, sf.food_id, sf.visibility, sf.status, sf.moderation_status,
      sf.name, sf.normalized_name, sf.base_amount, sf.unit_type,
      sf.serving_unit_label, sf.kcal_per_base, sf.protein_per_base,
      sf.fat_per_base, sf.carb_per_base, sf.source_type, sf.barcode,
      sf.brand, sf.supplementary_weight, sf.official_food_code,
      sf.official_food_name, sf.source_attribution, sf.copied_from_food_id,
      sf.copied_from_owner_user_id, sf.use_count, sf.last_used_at,
      sf.report_count, sf.version, sf.created_at, sf.updated_at, sf.deleted_at,
      case
        when sf.voice_normalized = %L then 0
        when sf.voice_normalized like %L escape '\' then 1
        else 2
      end
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and public.is_saved_food_visible_to_viewer(sf.user_id)
      and sf.voice_normalized like %L escape '\'
    order by 31, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
    limit %s
    $sql$,
    v_voice, v_voice_prefix, v_voice_pattern, v_limit
  );
  if found then
    return;
  end if;

  if pg_catalog.char_length(v_voice) < 3 or pg_catalog.char_length(v_voice) > 16 then
    return;
  end if;

  return query
  select
    sf.user_id, sf.food_id, sf.visibility, sf.status, sf.moderation_status,
    sf.name, sf.normalized_name, sf.base_amount, sf.unit_type,
    sf.serving_unit_label, sf.kcal_per_base, sf.protein_per_base,
    sf.fat_per_base, sf.carb_per_base, sf.source_type, sf.barcode,
    sf.brand, sf.supplementary_weight, sf.official_food_code,
    sf.official_food_name, sf.source_attribution, sf.copied_from_food_id,
    sf.copied_from_owner_user_id, sf.use_count, sf.last_used_at,
    sf.report_count, sf.version, sf.created_at, sf.updated_at, sf.deleted_at,
    2 + public.food_search_edit_distance(sf.voice_normalized, v_voice)
  from public.saved_foods sf
  where public.is_saved_food_publicly_visible(
          sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
        )
    and public.is_saved_food_visible_to_viewer(sf.user_id)
    and sf.voice_normalized is not null
    and pg_catalog.char_length(sf.voice_normalized)
        between pg_catalog.char_length(v_voice) - 2
            and pg_catalog.char_length(v_voice) + 2
    and public.food_search_edit_distance(sf.voice_normalized, v_voice) = 1
  order by 31, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
  limit v_limit;
end;
$function$;
