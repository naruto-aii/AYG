-- =====================================================================
-- 操作の記録を集計して、古い月の表を消す定期実行（追加だけ）
-- 置き場所: supabase/migrations/20261008090300_app_events_retention_schedule.sql
--
-- このファイルはリポジトリに置くだけです。本番には適用しません。
--
-- 適用の前提（この順番）
--   1. 20261007094142_app_events_retention.sql が適用済み。
--   2. 20261007095347_app_events_rollup_additive.sql が適用済み。
--   3. 20261008090260_app_events_closed_month.sql が適用済み。
--      これを飛ばすと、集計済みの月への再送が二重に足される。
--   4. 社長が「拡張機能 pg_cron を有効にしてよい」と承認している。
--
-- 毎日 UTC 18:15（日本時間 3:15）。売上の取り込み（UTC 0:30 と 6:30）とは時刻をずらす。
-- 処理はデータベース内で完結する。秘密の値は使わない。
-- =====================================================================

do $guard$
begin
  if to_regprocedure('public.app_event_month_is_aggregated(timestamptz)') is null
     or to_regprocedure('public.maintain_app_events()') is null
     or position(
       'public.app_event_month_is_aggregated'
       in pg_get_functiondef('public.maintain_app_events()'::regprocedure)
     ) = 0
     or position(
       'app_event_daily_totals.event_count + excluded.event_count'
       in pg_get_functiondef('public.maintain_app_events()'::regprocedure)
     ) = 0 then
    raise exception '20261008090260_app_events_closed_month を先に適用してください';
  end if;
end
$guard$;

create extension if not exists pg_cron;

select cron.schedule(
  'app-events-retention-daily',
  '15 18 * * *',
  $$select public.maintain_app_events();$$
);
