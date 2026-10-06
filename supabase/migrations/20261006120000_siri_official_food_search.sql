-- Siri looks up the food composition table with the anon key, before a
-- user session exists. search_official_foods is security definer and
-- reads only official_foods and official_food_aliases. Granting execute
-- to anon does not open saved foods, entries, or any other user table:
-- those stay revoked, and this function never selects them.
-- Spoken aliases point a few common names at one representative row.
-- Confirmed aliases (is_candidate false) sort ahead of the group
-- candidates already stored for the same word.

revoke all on function public.search_official_foods(text, integer) from public;
grant execute on function public.search_official_foods(text, integer) to anon;
grant execute on function public.search_official_foods(text, integer) to authenticated;

insert into public.official_food_aliases (
  food_code,
  alias,
  reading,
  normalized,
  priority,
  note,
  source,
  is_candidate,
  candidate_rank
)
select
  food.food_code,
  spoken.alias,
  spoken.reading,
  spoken.normalized,
  10,
  spoken.note,
  'siri_spoken_v1',
  false,
  null
from (
  values
    ('11220', 'とりむね', 'とりむね', 'とりむね', '話し言葉。皮なしの生を代表にする'),
    ('11220', 'むね肉', 'むねにく', 'むね肉', '話し言葉。皮なしの生を代表にする'),
    ('11220', '胸肉', 'むねにく', '胸肉', '話し言葉。皮なしの生を代表にする')
) as spoken(food_code, alias, reading, normalized, note)
join public.official_foods as food
  on food.food_code = spoken.food_code
on conflict (food_code, normalized) do nothing;
