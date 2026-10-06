-- Reverse 20261006180000_food_search_readings.sql.
-- Restores search_official_foods to the strict function from
-- 20260929180000 / 20261006120000 and drops the spoken columns.

begin;

drop function if exists public.search_public_foods(text, integer);
drop function if exists public.search_official_foods(text, integer);
drop function if exists public.search_official_foods_fuzzy(text, integer);

alter function public.search_official_foods_strict(text, integer)
  rename to search_official_foods;

revoke all on function public.search_official_foods(text, integer)
  from public, anon, authenticated;
grant execute on function public.search_official_foods(text, integer) to anon;
grant execute on function public.search_official_foods(text, integer) to authenticated;

delete from public.official_food_aliases
where source in (
  'karonavi_spoken_seed_v1',
  'spoken_manual_v1',
  'spoken_generated_v1'
);

drop trigger if exists saved_foods_fill_voice on public.saved_foods;
drop function if exists public.saved_foods_fill_voice();

drop trigger if exists official_foods_fill_spoken on public.official_foods;
drop function if exists public.official_foods_fill_spoken();

alter table public.saved_foods
  drop column if exists voice_reading,
  drop column if exists voice_katakana,
  drop column if exists voice_normalized;

alter table public.official_foods
  drop column if exists spoken_name,
  drop column if exists spoken_reading,
  drop column if exists spoken_katakana,
  drop column if exists spoken_normalized;

drop function if exists public.official_food_spoken_name(text);
drop function if exists public.hiragana_to_katakana(text);
drop function if exists public.food_search_edit_distance(text, text);

commit;
