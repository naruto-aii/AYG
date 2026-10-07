-- 20261007050424_harden_function_security を元に戻す。
-- 修正前の状態（backup/functions_before.sql の proconfig と ACL）:
--   10関数は proconfig なし（search_path 未設定）。
--   saved_foods_fill_voice() の ACL は {postgres=X, service_role=X, authenticated=X}。

alter function public.set_updated_at() reset search_path;
alter function public.is_saved_food_publicly_visible(text, text, timestamp with time zone, text) reset search_path;
alter function public.is_saved_food_reportable(text, text, timestamp with time zone) reset search_path;
alter function public.get_publish_rate_limits() reset search_path;
alter function public.enforce_saved_foods_owner_mutation() reset search_path;
alter function public.enforce_saved_foods_visibility_path() reset search_path;
alter function public.validate_saved_foods_public_row() reset search_path;
alter function public.publish_rate_limit_bucket_keys() reset search_path;
alter function public.enforce_food_reports_mutation() reset search_path;
alter function public.validate_food_rating_target() reset search_path;

grant execute on function public.saved_foods_fill_voice() to authenticated;
