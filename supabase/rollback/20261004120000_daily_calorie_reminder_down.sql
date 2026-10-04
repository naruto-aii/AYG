-- 20:00 の通知を戻す。食事、運動、体重、目標、ヘルスケアの測定値は消さない。
-- トークンと「その日に送った」記録、Health 上乗せの2列だけを消す。
-- 2回実行しても失敗しない。先にアプリを、このトークンを書かない版へ戻してから流す。

begin;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'daily-calorie-reminder';
  end if;
exception
  when undefined_table or undefined_object or invalid_schema_name then
    null;
  when others then
    raise notice 'daily calorie reminder cron unschedule skipped: %', sqlerrm;
end $$;

drop function if exists public.release_daily_calorie_reminder(uuid, date);
drop function if exists public.claim_daily_calorie_reminder(uuid, date);
drop function if exists public.daily_calorie_reminder_page(date, integer, uuid);

drop table if exists public.daily_reminder_deliveries;
drop table if exists public.user_push_tokens;

alter table public.health_snapshots
  drop column if exists activity_excess_kcal,
  drop column if exists activity_excess_on;

commit;
