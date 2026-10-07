-- パーソナルコーチ (β) で足した候補列だけを戻す。
-- 行、official_foods、食事、運動は消さない。2回実行しても失敗しない。

begin;

alter table public.coach_food_candidates
  drop column if exists portion_source,
  drop column if exists portion_options,
  drop column if exists is_bread_or_noodle,
  drop column if exists is_starchy_side,
  drop column if exists is_green_yellow_vegetable,
  drop column if exists coach_subrole,
  drop column if exists coach_role,
  drop column if exists is_active;

commit;
