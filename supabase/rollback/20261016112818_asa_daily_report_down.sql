-- Apple Ads 日次の新規オブジェクトだけを外す。既存の表は残す。
-- 適用済みのときだけ、手で流す。

drop function if exists public.asa_daily_report_rpc(text, jsonb);

drop table if exists kpi.asa_daily_keywords;
drop table if exists kpi.asa_daily_campaigns;
drop table if exists kpi.asa_report_posts;
