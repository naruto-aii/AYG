-- =====================================================================
-- 日本時間 2026-10-15 の誤った 0 件を消し、取り直せるようにする
--
-- これはマイグレーションではない。ここに置いても本番では実行されない。
-- 関数を再配備し、下のマイグレーションを適用したあと、社長が手で流す。
-- マイグレーションは supabase/migrations/20261017014500_asc_daily_report_revise_posted.sql
--
-- いまの 2026-10-15 は、太平洋時間 10/14 の売上ファイルが「売上なし」だったのに
-- 0 件として保存し、Slack に投稿した行。購読ファイルには無料体験がある。
-- asc_report_posts の flash / 2026-10-15 が posted のままだと、数字が同じあいだは送らない。
-- その予約行と、0 で保存した 2026-10-15 の集計行を消す。
--
-- 再配備した関数は、期限では確定しない。
-- 太平洋時間 10/14 の売上と購読の両方に製品行が入るまで、日本時間 10/15 は
-- 保存も投稿もしない。購読だけ行があり売上が空のままなら、より新しい日の
-- 売上ファイルが出ても 0 件としては投稿しない。
-- 売上も購読も空の日だけ、より新しい日の同じ種類に製品行が出てから 0 として出す。
--
-- いったん投稿した日は 3 日のあいだ取り直す。数字が変わった実行だけ、
-- Slack に訂正を 1 通出す。変わらなければ出さない。
-- この SQL のあと関数を 1 回呼んでも、売上ファイルが空なら Slack は出ない。
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
