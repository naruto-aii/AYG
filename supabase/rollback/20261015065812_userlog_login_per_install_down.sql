-- ログイン通知を、auth.sessions の挿入へ戻す。
-- app_events の文単位トリガー（REFERENCING NEW TABLE）も外す。
-- 既存の表・列・pg_net は残す。書き換えた source_id は戻さない。
-- 元のセッション ID は残していない。このファイルは本番では手で流す。

drop trigger if exists userlog_app_events_login_insert on public.app_events;
drop function if exists userlog.on_install_login();
drop function if exists userlog.remap_login_installs();

create or replace function userlog.on_auth_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  begin
    perform userlog.enqueue_json(pg_catalog.jsonb_build_object(
      'kind', 'session',
      'source_id', new.id,
      'user_id', new.user_id,
      'occurred_at', new.created_at
    ));
  exception
    when others then
      raise warning 'userlog session skipped';
  end;
  return null;
end;
$function$;

revoke all on function userlog.on_auth_session() from public;
grant execute on function userlog.on_auth_session() to service_role;

do $userlog_auth_grant$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'supabase_auth_admin') then
    grant usage on schema userlog to supabase_auth_admin;
    grant execute on function userlog.on_auth_session() to supabase_auth_admin;
  end if;
end
$userlog_auth_grant$;

drop trigger if exists userlog_auth_sessions_insert on auth.sessions;
create trigger userlog_auth_sessions_insert
  after insert on auth.sessions
  for each row
  execute function userlog.on_auth_session();

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
  end if;

  if pg_catalog.to_regclass('auth.sessions') is not null then
    for r in
      execute $q$
        select id, user_id, created_at
        from auth.sessions
        where created_at >= $1
        order by created_at
      $q$
      using v_since
    loop
      begin
        if userlog.enqueue_json(pg_catalog.jsonb_build_object(
          'kind', 'session',
          'source_id', r.id,
          'user_id', r.user_id,
          'occurred_at', r.created_at
        )) then
          v_count := v_count + 1;
        end if;
      exception
        when others then
          raise warning 'userlog backfill session skipped';
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
  '公開以降のチェックポイントを通常の通知として積む。適用時には走らない。二重送信は claim が止める。';
