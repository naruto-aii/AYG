-- function_search_path_mutable を、関数の中身を変えずに直す。
-- 対象は 20261008140000 から 20261008210000 で足した関数。
-- 20261008160100、20261008193000（cook_recipes）、20261008200000 は関数を作っていない。
-- 本番には適用しない。手順は docs/release/migrations.md。

alter function public.meal_photo_analyses_guard_update()
  set search_path = public, pg_temp;

alter function public.delete_meal_photo_analyses_on_account_close()
  set search_path = public, pg_temp;

alter function public.meal_text_lookups_guard_update()
  set search_path = public, pg_temp;

alter function public.delete_meal_text_lookups_on_account_close()
  set search_path = public, pg_temp;

alter function public.delete_ai_feature_uses_on_account_close()
  set search_path = public, pg_temp;

alter function public.delete_ai_food_results_on_account_close()
  set search_path = public, pg_temp;

alter function public.record_ai_food_result_outcome(uuid, boolean, text, text, numeric, numeric, numeric, numeric)
  set search_path = public, pg_temp;

alter function public.ai_data_consents_stamp()
  set search_path = public, pg_temp;

alter function public.delete_ai_data_consent_on_account_close()
  set search_path = public, pg_temp;
