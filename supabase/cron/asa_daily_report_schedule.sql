-- =====================================================================
-- asa-daily-report を 30 分おきに呼ぶ予定
--
-- これはマイグレーションではない。supabase/migrations の外に置く。
-- このファイルをリポジトリに入れても、pg_cron には登録されない。
-- 拡張機能の有効化、関数の配備、秘密の登録が済んだあとに、承認を得てから
-- 手で流す。このファイル自体は実行しない。
--
-- 前提
--   1. pg_cron と pg_net は、別途承認されたうえで有効になっている。
--      このファイルでは create extension しない。
--   2. Edge Function asa-daily-report が配備済み。
--   3. Vault に既存の名前で入っている。
--        project_url
--        store_import_secret  … Edge Function の STORE_IMPORT_SECRET と同じ値
--      値はここに書かない。
--   4. Edge Function の秘密が入っている。
--        ASA_CLIENT_ID, ASA_TEAM_ID, ASA_KEY_ID, ASA_PRIVATE_KEY, ASA_ORG_ID
--        SLACK_DAILY_REPORT_WEBHOOK_URL  … 送り先は Slack の #calonavi-daily-report
--
-- 時刻は UTC。日本時間は +9 時間。
--   06:00 JST = 21:00 UTC
--   23:30 JST = 14:30 UTC
--   */30 0-14,21-23 * * * は、この範囲の毎時 0 分と 30 分。
--   00:00〜05:30 JST（UTC 15:00〜20:30）は呼ばない。
-- 関数側でも、日本時間の日付が終わって 6 時間たつまでは投稿しない。
-- =====================================================================

select cron.schedule(
  'asa-daily-report',
  '*/30 0-14,21-23 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/asa-daily-report',
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
