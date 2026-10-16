-- =====================================================================
-- リリース日より前の日次レポート行を消す
--
-- これはマイグレーションではない。ここに置いても本番では実行されない。
-- 社長が内容を確認したあと、本番で手で流す。
--
-- 対象は data_date が 2026-10-14 以前の行。
-- 2026-10-15 以降は残す。親 SKU の表は日付の実績ではないので消さない。
-- =====================================================================

delete from kpi.asc_report_posts
where data_date < date '2026-10-15';

delete from kpi.asc_daily_sales
where data_date < date '2026-10-15';

delete from kpi.asc_daily_subscription
where data_date < date '2026-10-15';

delete from kpi.asc_daily_sub_events
where data_date < date '2026-10-15';

delete from kpi.asc_daily_reviews
where data_date < date '2026-10-15';

delete from kpi.asc_analytics_daily
where data_date < date '2026-10-15';
