-- When a query already names the cook method but the whole string misses,
-- search the food without that ending and put the matching cook first.
-- Queries that already hit are unchanged.

CREATE OR REPLACE FUNCTION public.food_search_drop_cook(p_query text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
declare
  v_text text := pg_catalog.replace(
    pg_catalog.replace(pg_catalog.btrim(coalesce(p_query, '')), ' ', ''),
    '　',
    ''
  );
  v_next text;
  v_suffix text;
  v_suffixes text[] := array[
    'のから揚げ', 'から揚げ', 'の唐揚げ', '唐揚げ', 'の天ぷら', '天ぷら',
    'のてんぷら', 'てんぷら', 'のフライ', 'フライ', 'の揚げ', '揚げ',
    'のからあげ', 'からあげ', 'の焼き', '焼き', '焼いた', 'の焼', '焼',
    'のやき', 'やいた', 'やき', 'のゆで', 'ゆでた', 'ゆで', 'の茹で', '茹で',
    'の水煮', '水煮', 'の蒸し', '蒸し', 'のむし', 'むし', 'のソテー', 'ソテー',
    'の生', '生'
  ];
begin
  loop
    v_next := null;
    foreach v_suffix in array v_suffixes loop
      if pg_catalog.char_length(v_text) > pg_catalog.char_length(v_suffix)
         and pg_catalog.right(v_text, pg_catalog.char_length(v_suffix)) = v_suffix then
        v_next := pg_catalog.left(
          v_text,
          pg_catalog.char_length(v_text) - pg_catalog.char_length(v_suffix)
        );
        exit;
      end if;
    end loop;
    exit when v_next is null;
    v_text := v_next;
  end loop;
  while pg_catalog.char_length(v_text) > 1
    and pg_catalog.right(v_text, 1) = 'の' loop
    v_text := pg_catalog.left(v_text, pg_catalog.char_length(v_text) - 1);
  end loop;
  return v_text;
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_search_cook_rank(p_display text, p_query text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  select case
    when p_query ~ '(から揚げ|唐揚げ|天ぷら|てんぷら|フライ|揚げ|からあげ)'
      and coalesce(p_display, '') ~ '(から揚げ|唐揚げ|天ぷら|てんぷら|フライ|揚げ|からあげ)'
      then 0
    when p_query ~ '(焼き|焼|やき|ソテー)'
      and coalesce(p_display, '') ~ '(焼き|焼|やき|ソテー)'
      then 0
    when p_query ~ '(ゆで|茹で|水煮)'
      and coalesce(p_display, '') ~ '(ゆで|茹で|水煮)'
      then 0
    when p_query ~ '(蒸し|むし)'
      and coalesce(p_display, '') ~ '(蒸し|むし)'
      then 0
    when p_query ~ '生'
      and coalesce(p_display, '') ~ '生'
      and p_query !~ '生揚'
      then 0
    else 1
  end;
$function$;

-- 同じ調理の中では、和牛・若鶏を前、輸入・乳用と脂身そのものを後ろにする。
CREATE OR REPLACE FUNCTION public.food_search_form_rank(p_display text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  select case
    when coalesce(p_display, '') ~ '脂身（' then 3
    when coalesce(p_display, '') ~ '(和牛|若鶏|若どり)' then 0
    when coalesce(p_display, '') ~ '(輸入|乳用)' then 2
    else 1
  end;
$function$;

CREATE OR REPLACE FUNCTION public.search_official_foods(p_query text, p_limit integer DEFAULT 30)
RETURNS TABLE(
  food_code text,
  food_group text,
  index_no text,
  name text,
  display_name text,
  reading text,
  base_amount numeric,
  unit_type text,
  refuse_pct numeric,
  kcal numeric,
  protein_g numeric,
  fat_g numeric,
  carb_g numeric,
  fiber_g numeric,
  salt_eq_g numeric,
  matched_alias text,
  matched_alias_reading text,
  match_rank integer,
  is_candidate boolean,
  candidate_rank integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_query text := pg_catalog.left(pg_catalog.btrim(coalesce(p_query, '')), 64);
  v_stem text;
begin
  return query
  select * from public.search_official_foods_strict(v_query, p_limit);
  if found then
    return;
  end if;

  v_stem := public.food_search_drop_cook(v_query);
  if v_stem is not null
     and v_stem <> v_query
     and pg_catalog.char_length(v_stem) >= 2 then
    return query
    select
      r.food_code,
      r.food_group,
      r.index_no,
      r.name,
      r.display_name,
      r.reading,
      r.base_amount,
      r.unit_type,
      r.refuse_pct,
      r.kcal,
      r.protein_g,
      r.fat_g,
      r.carb_g,
      r.fiber_g,
      r.salt_eq_g,
      r.matched_alias,
      r.matched_alias_reading,
      r.match_rank,
      r.is_candidate,
      r.candidate_rank
    from (
      select
        s.*,
        row_number() over () as ord,
        public.food_search_cook_rank(s.display_name, v_query) as cook_rank,
        public.food_search_form_rank(s.display_name) as form_rank
      from public.search_official_foods_strict(v_stem, 100) s
    ) r
    order by r.cook_rank, r.form_rank, r.ord
    limit least(greatest(coalesce(p_limit, 30), 0), 100);
    if found then
      return;
    end if;
  end if;

  return query
  select * from public.search_official_foods_fuzzy(v_query, p_limit);
end;
$function$;
