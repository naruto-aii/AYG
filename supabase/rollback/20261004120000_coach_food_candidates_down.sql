-- 今日のコーチの候補表だけを戻す。
-- official_foods と食事の行は消さない。2回実行しても失敗しない。

begin;

drop policy if exists coach_food_candidates_select_authenticated
  on public.coach_food_candidates;

drop table if exists public.coach_food_candidates;

commit;
