-- Undo 20261006200000. Restores the caller-limit bug and the looser fuzzy match.
-- Does not restore pg_catalog.least/greatest; that hotfix stays.

CREATE OR REPLACE FUNCTION public.search_official_foods_strict(p_query text, p_limit integer DEFAULT 30)
 RETURNS TABLE(food_code text, food_group text, index_no text, name text, display_name text, reading text, base_amount numeric, unit_type text, refuse_pct numeric, kcal numeric, protein_g numeric, fat_g numeric, carb_g numeric, fiber_g numeric, salt_eq_g numeric, matched_alias text, matched_alias_reading text, match_rank integer, is_candidate boolean, candidate_rank integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  -- Character cap, same as OfficialFoodLimits.maxQueryLength. Applied
  -- before normalization so a huge argument never enters the per-character
  -- loop. The pattern is inlined as a literal so the planner can use the
  -- gin_trgm_ops indexes on the stored columns.
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_query text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_pattern text;
  v_prefix text;
  v_limit integer := least(greatest(coalesce(p_limit, 30), 0), 100);
begin
  if v_query = '' or v_limit = 0 then
    return;
  end if;

  -- Group words (牛肉, 肉, 魚, チキン, …) return every member.
  -- The client asks for 30, which would hide the rest.
  if exists (
    select 1
    from public.official_food_aliases as group_alias
    where group_alias.is_group
      and (
        group_alias.normalized = v_query
        or group_alias.normalized_reading = v_query
      )
  ) then
    v_limit := 800;
  end if;

  v_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(
           pg_catalog.replace(v_query, '\', '\\'),
           '%',
           '\%'
         ),
         '_',
         '\_'
       )
    || '%';
  v_prefix :=
    pg_catalog.replace(
      pg_catalog.replace(
        pg_catalog.replace(v_query, '\', '\\'),
        '%',
        '\%'
      ),
      '_',
      '\_'
    )
    || '%';

  -- One indexed column per arm. OR would hide the index, and wrapping the
  -- column in normalize_food_search_text would too. normalized_name and
  -- aliases.normalized are already the search key. Human reading keeps
  -- the long vowel. normalized_reading is the search key.
  return query execute format(
    $sql$
    with hits as (
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
        100 as priority,
        false as is_candidate,
        null::integer as candidate_rank,
        case
          when f.normalized_name = %L then 0
          when pg_catalog.strpos(f.normalized_name, %L) = 1 then 1
          when pg_catalog.strpos(f.normalized_name, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_foods f
      where f.normalized_name like %L escape '\'
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
        null::text as matched_alias,
        null::text as matched_alias_reading,
        100 as priority,
        false as is_candidate,
        null::integer as candidate_rank,
        case
          when f.normalized_reading = %L then 0
          when pg_catalog.strpos(f.normalized_reading, %L) = 1 then 1
          when pg_catalog.strpos(f.normalized_reading, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_foods f
      where exists (
        select 1
        from pg_catalog.regexp_split_to_table(coalesce(f.reading, ''), ' ') as token
        where public.normalize_food_search_text(token) = %L
           or public.normalize_food_search_text(token) like %L escape '\'
      )
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
        a.priority,
        a.is_candidate,
        a.candidate_rank,
        case
          when a.normalized = %L then 0
          when pg_catalog.strpos(a.normalized, %L) = 1 then 1
          when pg_catalog.strpos(a.normalized, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_food_aliases a
      join public.official_foods f on f.food_code = a.food_code
      where a.normalized like %L escape '\'
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
        a.priority,
        a.is_candidate,
        a.candidate_rank,
        case
          when a.normalized_reading = %L then 0
          when pg_catalog.strpos(a.normalized_reading, %L) = 1 then 1
          when pg_catalog.strpos(a.normalized_reading, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_food_aliases a
      join public.official_foods f on f.food_code = a.food_code
      where exists (
        select 1
        from pg_catalog.regexp_split_to_table(coalesce(a.reading, ''), ' ') as token
        where public.normalize_food_search_text(token) = %L
           or public.normalize_food_search_text(token) like %L escape '\'
      )
    ),
    matched as (
      select *
      from hits
      where rank_value < 9
    ),
    best as (
      select distinct on (matched.food_code)
        matched.*
      from matched
      order by
        matched.food_code,
        matched.rank_value,
        matched.is_candidate,
        matched.candidate_rank nulls last,
        (matched.matched_alias is null),
        matched.priority,
        matched.matched_alias
    )
    select
      best.food_code,
      best.food_group,
      best.index_no,
      best.name,
      best.display_name,
      best.reading,
      best.base_amount,
      best.unit_type,
      best.refuse_pct,
      best.kcal,
      best.protein_g,
      best.fat_g,
      best.carb_g,
      best.fiber_g,
      best.salt_eq_g,
      best.matched_alias,
      best.matched_alias_reading,
      best.rank_value,
      best.is_candidate,
      best.candidate_rank
    from best
    order by
      best.rank_value,
      best.is_candidate,
      best.candidate_rank nulls last,
      (best.matched_alias is null),
      best.priority,
      best.food_code
    limit %s
    $sql$,
    v_query, v_query, v_query, v_pattern,
    v_query, v_query, v_query, v_query, v_prefix,
    v_query, v_query, v_query, v_pattern,
    v_query, v_query, v_query, v_query, v_prefix,
    v_limit
  );
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
  v_limit integer := least(greatest(coalesce(p_limit, 30), 0), 100);
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
  v_limit integer := least(greatest(coalesce(p_limit, 50), 0), 100);
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


delete from public.official_food_aliases
where source in ('morphology_v1', 'colloquial_v1');

create or replace function public.official_foods_fill_normalized_reading()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'official_foods' then
    new.normalized_reading := public.normalize_food_search_text(new.reading);
  else
    new.normalized_reading := public.normalize_food_search_text(coalesce(new.reading, new.alias));
  end if;
  return new;
end;
$$;

revoke all on function public.official_foods_fill_normalized_reading() from public, anon, authenticated;

drop index if exists public.official_foods_reading_tokens_idx;
drop index if exists public.official_food_aliases_reading_tokens_idx;
alter table public.official_foods drop column if exists reading_tokens;
alter table public.official_food_aliases drop column if exists reading_tokens;

create or replace function public.saved_foods_fill_voice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.voice_normalized := public.normalize_food_search_text(new.name);
  new.voice_reading := new.voice_normalized;
  new.voice_katakana := public.hiragana_to_katakana(new.voice_normalized);
  return new;
end;
$$;

revoke all on function public.saved_foods_fill_voice() from public, anon, authenticated;
grant execute on function public.saved_foods_fill_voice() to authenticated;

update public.saved_foods
set name = name;

drop function if exists public.expand_public_food_voice(text);
drop table if exists public.food_search_spellings;

