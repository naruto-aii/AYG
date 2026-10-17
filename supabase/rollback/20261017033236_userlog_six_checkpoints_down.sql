-- 6 種類への絞り込みを戻す。このファイルは本番では手で流す。
-- 既存の送信済み行は残す。アカウント削除用の新しい表は落とす。
-- 個人の識別子は書かない。

drop trigger if exists userlog_account_deletion_insert on public.account_deletion_stats;
drop function if exists userlog.on_account_deletion();
drop function if exists public.userlog_account_deletion_claim(date, text, text, text);
drop function if exists public.userlog_account_deletion_finish(date, text, text, text, text, text);
drop table if exists public.userlog_account_deletion_sent;

create or replace function userlog.store_is_candidate(
  p_type text,
  p_subtype text,
  p_status text
)
returns boolean
language sql
immutable
set search_path = ''
as $function$
  select p_status = 'verified'
    and (
      p_type in ('INITIAL_BUY', 'DID_RENEW', 'EXPIRED', 'REFUND')
      or (p_type = 'SUBSCRIBED' and p_subtype = 'INITIAL_BUY')
      or (p_type = 'DID_CHANGE_RENEWAL_STATUS' and p_subtype = 'AUTO_RENEW_DISABLED')
      or p_subtype = 'INITIAL_BUY'
    );
$function$;

create or replace function userlog.on_app_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  begin
    if new.event_name in ('app_install_first_open', 'onboarding_complete') then
      perform userlog.enqueue_json(pg_catalog.jsonb_build_object(
        'kind', 'app_event',
        'source_id', new.event_id,
        'user_id', new.user_id,
        'install_id', new.install_id,
        'event_name', new.event_name,
        'occurred_at', new.occurred_at
      ));
    end if;
  exception
    when others then
      raise warning 'userlog app_event skipped';
  end;
  return null;
end;
$function$;

drop trigger if exists userlog_app_events_insert on public.app_events;
create trigger userlog_app_events_insert
  after insert on public.app_events
  for each row
  when (new.event_name in ('app_install_first_open', 'onboarding_complete'))
  execute function userlog.on_app_event();

drop trigger if exists userlog_app_events_login_insert on public.app_events;
create trigger userlog_app_events_login_insert
  after insert on public.app_events
  referencing new table as new_rows
  for each statement
  execute function userlog.on_install_login();

create or replace function userlog.enqueue_backfill()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_since timestamptz := timestamptz '2026-10-14 20:17:00+00';
  v_count integer := 0;
  r record;
begin
  if pg_catalog.to_regclass('public.app_events') is not null then
    for r in
      execute $q$
        select event_id, user_id, install_id, event_name, occurred_at
        from public.app_events
        where event_name in ('app_install_first_open', 'onboarding_complete')
          and occurred_at >= $1
        order by occurred_at
      $q$
      using v_since
    loop
      begin
        if userlog.enqueue_json(pg_catalog.jsonb_build_object(
          'kind', 'app_event',
          'source_id', r.event_id,
          'user_id', r.user_id,
          'install_id', r.install_id,
          'event_name', r.event_name,
          'occurred_at', r.occurred_at
        )) then
          v_count := v_count + 1;
        end if;
      exception
        when others then
          raise warning 'userlog backfill app_event skipped';
      end;
    end loop;

    for r in
      execute $q$
        select events.user_id, events.install_id, min(events.occurred_at) as occurred_at
        from public.app_events as events
        where events.user_id is not null
          and events.install_id is not null
          and events.occurred_at >= $1
          and not exists (
            select 1
            from public.userlog_notifications_sent as sent
            where sent.user_id = events.user_id
              and sent.checkpoint_type = 'login'
              and sent.source_id = events.install_id::text
              and sent.status = 'sent'
          )
        group by events.user_id, events.install_id
        order by min(events.occurred_at)
      $q$
      using v_since
    loop
      begin
        if userlog.enqueue_json(pg_catalog.jsonb_build_object(
          'kind', 'install_login',
          'source_id', r.install_id,
          'user_id', r.user_id,
          'install_id', r.install_id,
          'occurred_at', r.occurred_at
        )) then
          v_count := v_count + 1;
        end if;
      exception
        when others then
          raise warning 'userlog backfill install login skipped';
      end;
    end loop;
  end if;

  if pg_catalog.to_regclass('public.store_server_notifications') is not null then
    for r in
      execute $q$
        select notification_uuid, notification_type, subtype, verification_status,
               signed_date, received_at
        from public.store_server_notifications
        where coalesce(signed_date, received_at) >= $1
        order by coalesce(signed_date, received_at)
      $q$
      using v_since
    loop
      begin
        if userlog.store_is_candidate(r.notification_type, r.subtype, r.verification_status)
           and userlog.enqueue_json(pg_catalog.jsonb_build_object(
             'kind', 'store',
             'source_id', r.notification_uuid
           )) then
          v_count := v_count + 1;
        end if;
      exception
        when others then
          raise warning 'userlog backfill store skipped';
      end;
    end loop;
  end if;

  return v_count;
end;
$function$;

revoke all on function userlog.enqueue_backfill() from public;
comment on function userlog.enqueue_backfill() is
  '公開以降のチェックポイントを通常の通知として積む。ログインは app_events の組。適用時には走らない。';

notify pgrst, 'reload schema';
