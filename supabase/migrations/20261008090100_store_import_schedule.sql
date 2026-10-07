-- =====================================================================
-- App Store データの自動取り込みの定期実行（追加だけ）
-- 置き場所: supabase/migrations/20261008090100_store_import_schedule.sql
--
-- 適用の前提（この順番）
--   1. 社長が「拡張機能 pg_cron と pg_net を有効にしてよい」と承認している。
--      （2026-10-07 時点の本番: どちらも「利用可能・未導入」。supabase_vault は導入済み）
--   2. Edge Function の store-analytics-import / store-sales-import が配備済み。
--   3. Vault に次の 2 つの秘密が登録済み（名前は固定）:
--        project_url          … https://vdzzusqisymtejcjnikb.supabase.co
--        store_import_secret  … Edge Function の秘密 STORE_IMPORT_SECRET と同じ値
--      ※ 値はこのファイルに書かない。登録はダッシュボードかクラウドエージェントの
--        安全な手順で行う（社長の承認後）。
--
-- 時刻は UTC。日本時間では +9 時間。
--   分析レポート: 毎時 15 分（未取り込みの segment を少しずつ取り込む。1 回の実行時間の上限対策）
--   売上レポート: 毎日 UTC 0:30 と 6:30（日本時間 9:30 と 15:30）。過去 14 日分の欠けを毎回確認。
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 同名の予定があれば置き換える（cron.schedule は同名だと上書き）
select cron.schedule(
  'store-analytics-import-hourly',
  '15 * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/store-analytics-import',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-store-import-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'store_import_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

select cron.schedule(
  'store-sales-import-twice-daily',
  '30 0,6 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/store-sales-import',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-store-import-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'store_import_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
