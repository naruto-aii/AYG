-- Undo 20261006210000. Search goes back to the strict result, then fuzzy.

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
begin
  return query
  select * from public.search_official_foods_strict(p_query, p_limit);
  if found then
    return;
  end if;
  return query
  select * from public.search_official_foods_fuzzy(p_query, p_limit);
end;
$function$;

DROP FUNCTION IF EXISTS public.food_search_form_rank(text);
DROP FUNCTION IF EXISTS public.food_search_cook_rank(text, text);
DROP FUNCTION IF EXISTS public.food_search_drop_cook(text);
