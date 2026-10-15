-- 日次レポートの新規オブジェクトだけを外す。既存の表は残す。
-- 適用済みのときだけ、手で流す。

drop function if exists public.asc_daily_report_rpc(text, jsonb);

drop table if exists kpi.asc_report_posts;
drop table if exists kpi.asc_analytics_daily;
drop table if exists kpi.asc_daily_reviews;
drop table if exists kpi.asc_daily_sub_events;
drop table if exists kpi.asc_daily_subscription;
drop table if exists kpi.asc_daily_sales;
