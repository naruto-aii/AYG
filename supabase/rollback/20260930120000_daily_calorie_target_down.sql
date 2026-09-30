-- 日次の食事目標で足した列だけを消す。行は消さない。2回実行しても失敗しない。
-- 先にアプリを、この列を読まない版へ戻してから流す。

begin;

alter table public.nutrition_settings
  drop constraint if exists nutrition_settings_calorie_target_mode_check;

alter table public.nutrition_settings
  drop column if exists calorie_target_mode,
  drop column if exists manual_target_kcal,
  drop column if exists manual_protein_g,
  drop column if exists manual_fat_g,
  drop column if exists manual_carb_g,
  drop column if exists auto_food_target_kcal,
  drop column if exists auto_food_target_on,
  drop column if exists auto_food_target_prior_kcal;

alter table public.health_snapshots
  drop column if exists weight_measured_at;

commit;
