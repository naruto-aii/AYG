-- 20:00 Asia/Tokyo。日本に夏時間は無いので、毎日 11:00 UTC。
-- このファイルはマイグレーションでは流さない。pg_cron と pg_net を有効にしてから、
-- ダッシュボードの SQL で1回実行する。URL と service role はここに書かない。
--
-- 先にデータベース設定へ入れる:
--   alter database postgres set app.daily_reminder_url = 'https://<project-ref>.supabase.co/functions/v1/daily-calorie-reminder';
--   alter database postgres set app.daily_reminder_bearer = '<service role key>';
--
-- 関数は日本時間の 20 時台以外では送らない。同じ人・同じ日本の日付は1通だけ。

select cron.schedule(
  'daily-calorie-reminder',
  '0 11 * * *',
  $$
  select net.http_post(
    url := current_setting('app.daily_reminder_url', true),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.daily_reminder_bearer', true)
    ),
    body := '{}'::jsonb
  );
  $$
);
