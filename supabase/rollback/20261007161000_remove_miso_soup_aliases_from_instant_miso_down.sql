-- 即席みそへ戻した味噌汁の口語別名。20261007161000 で消した6行だけ。

begin;

insert into public.official_food_aliases (
  food_code, alias, reading, normalized, is_candidate, candidate_rank,
  note, source, is_group, priority
)
select
  spoken.food_code,
  spoken.alias,
  spoken.reading,
  public.normalize_food_search_text(spoken.alias),
  spoken.is_candidate,
  spoken.candidate_rank,
  spoken.note,
  spoken.source,
  false,
  case when spoken.is_candidate then 40 else 10 end
from (
  values
  ('17049', '味噌汁', 'みそしる', true, 1, '成分表に一杯分は無い。即席みそを候補にする', 'spoken_manual_v1'),
  ('17049', 'みそ汁', 'みそしる', true, 1, '即席みそ', 'spoken_manual_v1'),
  ('17049', 'みそしる', 'みそしる', true, 1, '即席みそ', 'spoken_manual_v1'),
  ('17049', 'お味噌汁', 'おみそしる', true, 1, '即席みそ', 'spoken_manual_v1'),
  ('17050', '味噌汁', 'みそしる', true, 2, '即席みそ ペースト', 'spoken_manual_v1'),
  ('17050', 'みそしる', 'みそしる', true, 2, '即席みそ ペースト', 'spoken_manual_v1')
) as spoken(food_code, alias, reading, is_candidate, candidate_rank, note, source)
where exists (
  select 1
  from public.official_foods as food
  where food.food_code = spoken.food_code
)
on conflict (food_code, normalized) do nothing;

commit;
