-- 20261007094142 で足した保存期間と購入対応だけを外す。
-- app_events の行は消さない。月ごとの表も残す。
-- 先にこのファイルを流し、続けて 20261007094059_app_events_down.sql を流す。
-- 片方だけ戻さない。このファイルは削除の定期実行を止めるだけではない。

begin;

do $drop_trigger$
begin
  if to_regclass('public.app_events') is not null then
    execute 'drop trigger if exists app_events_before_insert on public.app_events';
  end if;
end
$drop_trigger$;

drop function if exists public.insert_app_events(jsonb);
drop function if exists public.maintain_app_events();
drop function if exists public.ensure_app_events_partition(date);
drop function if exists public.lock_app_events_partition(text);
drop function if exists public.app_events_before_insert();
drop function if exists public.remember_store_original_transaction(text, uuid, text);

drop table if exists public.app_events_rehome;
drop table if exists public.app_event_partitions;
drop table if exists public.app_event_user_days;
drop table if exists public.app_event_daily_totals;
drop table if exists public.store_original_transactions;

commit;
