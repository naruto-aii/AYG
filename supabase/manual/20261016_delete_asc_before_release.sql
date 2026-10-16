-- =====================================================================
-- リリース日より前の日次レポート行を消す
--
-- これはマイグレーションではない。ここに置いても本番では実行されない。
-- 社長が内容を確認したあと、本番で手で流す。
--
-- いま入っている data_date は、初回実行が太平洋時間のレポート日のまま保存した日付。
-- 2026-10-14 以前を消す。2026-10-15 以降は、出し直し用の別 SQL が扱う。
-- 親 SKU の表は日付の実績ではないので消さない。
--
-- 太平洋時間 10/14 のファイル（トライアルを含む）は、消したあとに失われない。
-- 再配備した関数は、そのファイルを日本時間 2026-10-15 として取り直す。
-- 日次ファイルに時刻が無いので、ファイルの中のリリース前の数時間は分けられない。
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
