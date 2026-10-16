-- =====================================================================
-- 2026-10-15 の速報を、次の実行で 1 回だけ出し直す
--
-- これはマイグレーションではない。ここに置いても本番では実行されない。
-- 関数を再配備したあと、社長が手で流す。
--
-- asc_report_posts の flash / 2026-10-15 が posted のままだと、同じ日は送らない。
-- その予約行と、0 で保存した 2026-10-15 の集計行を消す。
-- 次に成功した実行が取り直し、Slack に 1 回投稿し、posted を付け直す。
-- 失敗した実行は failed のまま残り、待ってからもう一度だけ取り直す。
--
-- 日本時間 2026-10-17 5:00 より前は、10/15 のファイルを未確定として投稿しない。
-- この SQL のあと、その時刻を過ぎてから関数を 1 回呼ぶ。
-- cron が有効なら、日本時間 6:00 の回が同じ投稿をする。先に成功した方が 1 回だけ送る。
-- =====================================================================

delete from kpi.asc_report_posts
where report_type = 'flash'
  and data_date = date '2026-10-15';

delete from kpi.asc_daily_sales
where data_date = date '2026-10-15';

delete from kpi.asc_daily_subscription
where data_date = date '2026-10-15';

delete from kpi.asc_daily_sub_events
where data_date = date '2026-10-15';

delete from kpi.asc_daily_reviews
where data_date = date '2026-10-15';

delete from kpi.asc_analytics_daily
where data_date = date '2026-10-15';
