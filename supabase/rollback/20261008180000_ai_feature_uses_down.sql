-- 20261008180000_ai_feature_uses を戻す。自炊コーチの回数は残らない。食事の行は残る。
drop table if exists public.cook_coach_cache;
drop trigger if exists delete_ai_feature_uses_on_account_close on public.users;
drop function if exists public.delete_ai_feature_uses_on_account_close();
drop view if exists kpi.ai_feature_uses;
drop table if exists public.ai_feature_uses;
