-- 日次の食事目標。列の追加だけ。既存行は NULL のまま。
-- 戻す手順: supabase/rollback/20260930120000_daily_calorie_target_down.sql

alter table public.nutrition_settings
  add column if not exists calorie_target_mode text,
  add column if not exists manual_target_kcal double precision,
  add column if not exists manual_protein_g double precision,
  add column if not exists manual_fat_g double precision,
  add column if not exists manual_carb_g double precision,
  add column if not exists auto_food_target_kcal double precision,
  add column if not exists auto_food_target_on date,
  add column if not exists auto_food_target_prior_kcal double precision;

alter table public.nutrition_settings
  drop constraint if exists nutrition_settings_calorie_target_mode_check;

alter table public.nutrition_settings
  add constraint nutrition_settings_calorie_target_mode_check
  check (
    calorie_target_mode is null
    or calorie_target_mode in ('automatic', 'manual')
  );

comment on column public.nutrition_settings.calorie_target_mode is
  'automatic は日次の式。manual は手入力の kcal と PFC。未設定は automatic。';

comment on column public.nutrition_settings.auto_food_target_kcal is
  '自動計算の直近の食事目標。前日比 ±150 kcal の基準。手入力中は更新しない。';

alter table public.health_snapshots
  add column if not exists weight_measured_at timestamptz;

comment on column public.health_snapshots.weight_measured_at is
  'Health の体重サンプルの測定時刻。同期した時刻ではない。';
