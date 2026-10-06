-- Reverse 20261006120000_siri_official_food_search.sql.
-- Drops the spoken aliases added for Siri and returns search execute
-- to authenticated only.

delete from public.official_food_aliases
where source = 'siri_spoken_v1';

revoke all on function public.search_official_foods(text, integer) from public, anon, authenticated;
grant execute on function public.search_official_foods(text, integer) to authenticated;
