-- harden_function_security（本番適用済み: version 20261007050424 = 2026-10-07 14:04 JST）
-- Supabase security advisor の警告を、関数の中身を変えずに直す。
--   1. function_search_path_mutable (10件): search_path を '' に固定する。
--      10関数の本文は、表と関数を public. 付きで参照し、それ以外は
--      pg_catalog の組み込み（coalesce, current_setting, timezone, now,
--      to_char, clock_timestamp, btrim と演算子）だけを使う。
--      pg_catalog は search_path が空でも必ず探されるので、動作は変わらない。
--   2. authenticated_security_definer_function_executable のうち
--      saved_foods_fill_voice(): トリガー専用の関数。トリガーの発火時には
--      EXECUTE 権限を確かめないので、authenticated の EXECUTE を外しても
--      saved_foods の保存はこれまでどおり動く。直接 RPC で呼ぶ道だけを閉じる。
-- 残す警告（意図どおり）:
--   - search_official_foods: Siri（ios/Runner/SiriVoiceLog.swift）がログイン前に
--     anon キーで呼ぶ。アプリ（SupabaseOfficialFoodRepository）は authenticated で呼ぶ。
--   - search_public_foods: アプリと Siri がログイン中のトークンで呼ぶ。中で auth.uid() を確かめる。
--   - publish_saved_food: アプリのマイ食品の公開。中で auth.uid() と本人の行を確かめる。
--   - rate_limit_buckets と *_backup_20260929 の2表: RLS 有効・ポリシー無し・
--     anon/authenticated に表の権限も無い。サーバー専用（利用者からは拒否）として意図どおり。
-- 表やデータは変えない。

alter function public.set_updated_at() set search_path = '';
alter function public.is_saved_food_publicly_visible(text, text, timestamp with time zone, text) set search_path = '';
alter function public.is_saved_food_reportable(text, text, timestamp with time zone) set search_path = '';
alter function public.get_publish_rate_limits() set search_path = '';
alter function public.enforce_saved_foods_owner_mutation() set search_path = '';
alter function public.enforce_saved_foods_visibility_path() set search_path = '';
alter function public.validate_saved_foods_public_row() set search_path = '';
alter function public.publish_rate_limit_bucket_keys() set search_path = '';
alter function public.enforce_food_reports_mutation() set search_path = '';
alter function public.validate_food_rating_target() set search_path = '';

revoke execute on function public.saved_foods_fill_voice() from public, anon, authenticated;
