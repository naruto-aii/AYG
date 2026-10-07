-- =====================================================================
-- 操作の記録を集計して、古い月の表を消す定期実行（追加だけ）
-- 置き場所: supabase/migrations/20261008090300_app_events_retention_schedule.sql
--
-- このファイルはリポジトリに置くだけです。本番には適用しません。
--
-- 適用の前提（この順番）
--   1. 20261008090200_app_events_retention.sql が適用済み。
--   2. 社長が「拡張機能 pg_cron を有効にしてよい」と承認している。
--
-- 毎日 UTC 18:15（日本時間 3:15）。売上の取り込み（UTC 0:30 と 6:30）とは時刻をずらす。
-- 処理はデータベース内で完結する。秘密の値は使わない。
-- =====================================================================

create extension if not exists pg_cron;

select cron.schedule(
  'app-events-retention-daily',
  '15 18 * * *',
  $$select public.maintain_app_events();$$
);
