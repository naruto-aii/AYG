-- =====================================================================
-- ログイン通知を、利用者とインストールの組で 1 回にする。
--
-- このファイルは本番へ適用しない。適用順は supabase/functions/README.md。
-- 既存の表・パーティションの列は変えない。行の追加も、このファイルではしない。
--
-- 順番
--   1. ログイン行の source_id を、決められるときだけインストール ID に書き換える。
--   2. そのあとで auth.sessions のトリガーを外し、app_events の挿入から送る。
-- 失敗は warning にして、元の INSERT は成功させる。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 既存のログイン行。利用者のインストール ID がちょうど 1 つのときだけ。
--    決められない行、一意キーがぶつかる行は残す。個人の識別子は書かない。
-- ---------------------------------------------------------------------
create or replace function userlog.remap_login_installs()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  r record;
begin
  for r in
    select sent.id, picked.install_id
    from public.userlog_notifications_sent as sent
    join (
      select events.user_id, min(events.install_id::text) as install_id
      from public.app_events as events
      where events.user_id is not null
        and events.install_id is not null
      group by events.user_id
      having count(distinct events.install_id) = 1
    ) as picked
      on picked.user_id = sent.user_id
    where sent.checkpoint_type = 'login'
      and sent.source_id is distinct from picked.install_id
  loop
    begin
      update public.userlog_notifications_sent
      set source_id = r.install_id
      where id = r.id
        and checkpoint_type = 'login';
    exception
      when unique_violation then
        null;
    end;
  end loop;
end;
$function$;

revoke all on function userlog.remap_login_installs() from public;
comment on function userlog.remap_login_installs() is
  'ログイン行の source_id を、インストール ID が 1 つに決まる利用者だけ書き換える。';

do $userlog_remap_now$
begin
  perform userlog.remap_login_installs();
end
$userlog_remap_now$;

-- ---------------------------------------------------------------------
-- 2. 1 回の INSERT（最大 100 行）を 1 つの文として見る。
--    組ごとに、送信済み行が無く、この文の外に同じ組が無いときだけ 1 回呼ぶ。
--    user_id / install_id が無い行は無視する。
-- ---------------------------------------------------------------------
create or replace function userlog.on_install_login()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  r record;
begin
  begin
    for r in
      select
        incoming.user_id,
        incoming.install_id,
        min(incoming.occurred_at) as occurred_at
      from new_rows as incoming
      where incoming.user_id is not null
        and incoming.install_id is not null
      group by incoming.user_id, incoming.install_id
    loop
      begin
        if exists (
          select 1
          from public.userlog_notifications_sent as sent
          where sent.user_id = r.user_id
            and sent.checkpoint_type = 'login'
            and sent.source_id = r.install_id::text
        ) then
          continue;
        end if;

        if exists (
          select 1
          from public.app_events as events
          where events.user_id = r.user_id
            and events.install_id = r.install_id
            and not exists (
              select 1
              from new_rows as batch_rows
              where batch_rows.event_id = events.event_id
                and batch_rows.occurred_at = events.occurred_at
            )
        ) then
          continue;
        end if;

        perform userlog.enqueue_json(pg_catalog.jsonb_build_object(
          'kind', 'install_login',
          'source_id', r.install_id,
          'user_id', r.user_id,
          'install_id', r.install_id,
          'occurred_at', r.occurred_at
        ));
      exception
        when others then
          raise warning 'userlog install login skipped';
      end;
    end loop;
  exception
    when others then
      raise warning 'userlog install login skipped';
  end;
  return null;
end;
$function$;

revoke all on function userlog.on_install_login() from public;
grant execute on function userlog.on_install_login() to service_role;
comment on function userlog.on_install_login() is
  '1 回の INSERT に入った利用者とインストールの組が、その文の外にまだ無いときだけ userlog-notify を呼ぶ。失敗しても挿入は続ける。';

do $userlog_login_grant$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'supabase_auth_admin') then
    grant execute on function userlog.on_install_login() to supabase_auth_admin;
  end if;
end
$userlog_login_grant$;

drop trigger if exists userlog_app_events_login_insert on public.app_events;
create trigger userlog_app_events_login_insert
  after insert on public.app_events
  referencing new table as new_rows
  for each statement
  execute function userlog.on_install_login();

drop trigger if exists userlog_auth_sessions_insert on auth.sessions;
drop function if exists userlog.on_auth_session();

-- ---------------------------------------------------------------------
-- 3. 取りこぼしのログインは app_events の組。セッション行は見ない。
--    適用時には走らない。sent の組は積まない。failed は送り直せる。
-- ---------------------------------------------------------------------
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
