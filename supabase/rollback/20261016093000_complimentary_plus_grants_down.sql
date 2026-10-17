-- rollback for 20261016093000_complimentary_plus_grants
-- 付与表と関数だけを消す。加入、通知、KPI、利用者ログは戻さない（この変更はそれらを書き換えていない）。

drop function if exists public.current_complimentary_plus();
drop function if exists public.user_has_complimentary_plus(uuid);
drop function if exists private.user_has_complimentary_plus(uuid);
drop table if exists public.calonavi_plus_complimentary_grants;
