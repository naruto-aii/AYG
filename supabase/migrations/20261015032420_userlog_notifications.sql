-- =====================================================================
-- カロナビの利用者チェックポイントを Slack へ知らせる（追加だけ）
--
-- このファイルは本番へ適用しない。適用順とバックフィルは
-- supabase/functions/README.md に書く。このファイルを流しても過去分は送らない。
--
-- 方針
--   * 既存の表・列・関数・RLS・トリガーの中身は変えない。トリガーを足すだけ。
--   * 送ったかどうかは新しい表 public.userlog_notifications_sent だけに書く。
--   * トリガーは pg_net で Edge Function userlog-notify を非同期に呼ぶ。
--     失敗は warning にして、元の INSERT は成功させる。
--   * Slack の Webhook URL もメンションも、このファイルには書かない。
--     URL は Edge Function の秘密 SLACK_USERLOG_WEBHOOK_URL。
--     呼び出しの合言葉は Vault の userlog_notify_secret と
--     Edge Function の秘密 USERLOG_NOTIFY_SECRET（同じ値、32 文字以上）。
--     関数の URL は Vault の project_url から組み立てる。
--   * pg_cron は有効にしない。pg_net は、サーバが提供しているときだけ有効にする。
-- =====================================================================

do $userlog_ext$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  else
    raise warning 'userlog: pg_net is not available on this server';
  end if;
end
$userlog_ext$;

create schema if not exists userlog;
comment on schema userlog is
  '利用者チェックポイントの Slack 通知。API には出さない。既存の表は変更しない。';
revoke all on schema userlog from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. 送信済み（同じ利用者・種類・元イベントは 1 回だけ）
-- ---------------------------------------------------------------------
create table if not exists public.userlog_notifications_sent (
  id bigint generated always as identity primary key,
  user_id uuid,
  checkpoint_type text not null,
  source_id text not null,
  status text not null default 'pending',
  claimed_at timestamptz not null default pg_catalog.timezone('utc', pg_catalog.now()),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default pg_catalog.timezone('utc', pg_catalog.now()),
  constraint userlog_notifications_sent_type check (
    checkpoint_type in (
      'install',
      'login',
      'onboarding_complete',
      'trial_start',
      'paid_start',
      'cancel',
      'expired',
      'refund'
    )
  ),
  constraint userlog_notifications_sent_source check (
    char_length(source_id) between 1 and 128
  ),
  constraint userlog_notifications_sent_status check (
    status in ('pending', 'sent', 'failed')
  ),
  constraint userlog_notifications_sent_error check (
    last_error is null or char_length(last_error) <= 200
  ),
  constraint userlog_notifications_sent_dedup
    unique nulls not distinct (user_id, checkpoint_type, source_id)
);

comment on table public.userlog_notifications_sent is
  'Slack へ出した利用者チェックポイント。再送とバックフィルが二重にならないようにする。広告には使わない。';

alter table public.userlog_notifications_sent enable row level security;
revoke all on table public.userlog_notifications_sent from public, anon, authenticated;
grant select, insert, update, delete on table public.userlog_notifications_sent to service_role;

-- ---------------------------------------------------------------------
-- 2. Edge Function から使う関数（定義は security invoker。秘密は返さない）
-- ---------------------------------------------------------------------
create or replace function public.userlog_context(
  p_user_id uuid,
  p_install_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_name text;
  v_excluded boolean := false;
  v_flag boolean;
begin
  if p_user_id is not null and pg_catalog.to_regclass('public.profiles') is not null then
    execute 'select display_name from public.profiles where user_id = $1'
      into v_name
      using p_user_id;
  end if;

  if p_user_id is not null and pg_catalog.to_regclass('kpi.excluded_user_ids') is not null then
    execute 'select exists (select 1 from kpi.excluded_user_ids where user_id = $1)'
      into v_flag
      using p_user_id;
    v_excluded := coalesce(v_flag, false);
  end if;

  if not v_excluded
     and p_install_id is not null
     and pg_catalog.to_regclass('kpi.excluded_install_ids') is not null then
    execute 'select exists (select 1 from kpi.excluded_install_ids where install_id = $1)'
      into v_flag
      using p_install_id;
    v_excluded := coalesce(v_flag, false);
  end if;

  if not v_excluded
     and p_user_id is not null
     and pg_catalog.to_regclass('public.users') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'users'
         and column_name = 'deleted_at'
     ) then
    execute 'select deleted_at is not null from public.users where id = $1'
      into v_flag
      using p_user_id;
    v_excluded := coalesce(v_flag, false);
  end if;

  return pg_catalog.jsonb_build_object(
    'display_name', v_name,
    'excluded', v_excluded
  );
end;
$function$;

create or replace function public.userlog_claim(
  p_user_id uuid,
  p_checkpoint_type text,
  p_source_id text
)
returns text
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_id bigint;
  v_status text;
  v_claimed timestamptz;
begin
  if p_checkpoint_type is null
     or p_source_id is null
     or char_length(p_source_id) < 1
     or char_length(p_source_id) > 128
     or p_checkpoint_type not in (
       'install',
       'login',
       'onboarding_complete',
       'trial_start',
       'paid_start',
       'cancel',
       'expired',
       'refund'
     ) then
    return 'rejected';
  end if;

  v_id := null;
  insert into public.userlog_notifications_sent (
    user_id, checkpoint_type, source_id, status, claimed_at
  ) values (
    p_user_id,
    p_checkpoint_type,
    p_source_id,
    'pending',
    pg_catalog.timezone('utc', pg_catalog.now())
  )
  on conflict on constraint userlog_notifications_sent_dedup do nothing
  returning id into v_id;
  if v_id is not null then
    return 'claimed';
  end if;

  select status, claimed_at
    into v_status, v_claimed
  from public.userlog_notifications_sent
  where user_id is not distinct from p_user_id
    and checkpoint_type = p_checkpoint_type
    and source_id = p_source_id
  for update;

  if v_status is null or v_status = 'sent' then
    return 'duplicate';
  end if;

  if v_status = 'failed'
     or (
       v_status = 'pending'
       and v_claimed < pg_catalog.timezone('utc', pg_catalog.now()) - interval '5 minutes'
     ) then
    v_id := null;
    update public.userlog_notifications_sent
    set status = 'pending',
        claimed_at = pg_catalog.timezone('utc', pg_catalog.now()),
        last_error = null
    where user_id is not distinct from p_user_id
      and checkpoint_type = p_checkpoint_type
      and source_id = p_source_id
      and status = v_status
    returning id into v_id;
    if v_id is not null then
      return 'retry';
    end if;
  end if;

  return 'duplicate';
end;
$function$;

create or replace function public.userlog_finish(
  p_user_id uuid,
  p_checkpoint_type text,
  p_source_id text,
  p_status text,
  p_error text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
begin
  if p_status not in ('sent', 'failed') then
    return;
  end if;
  update public.userlog_notifications_sent
  set status = p_status,
      sent_at = case
        when p_status = 'sent' then pg_catalog.timezone('utc', pg_catalog.now())
        else sent_at
      end,
      last_error = case
        when p_status = 'failed' then left(coalesce(p_error, 'delivery_failed'), 200)
        else null
      end
  where user_id is not distinct from p_user_id
    and checkpoint_type = p_checkpoint_type
    and source_id = p_source_id;
end;
$function$;

revoke all on function public.userlog_context(uuid, uuid) from public, anon, authenticated;
revoke all on function public.userlog_claim(uuid, text, text) from public, anon, authenticated;
revoke all on function public.userlog_finish(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.userlog_context(uuid, uuid) to service_role;
grant execute on function public.userlog_claim(uuid, text, text) to service_role;
grant execute on function public.userlog_finish(uuid, text, text, text, text) to service_role;

comment on function public.userlog_context(uuid, uuid) is
  '表示名と、KPI 除外または退会済みかどうか。メールアドレスは返さない。';
comment on function public.userlog_claim(uuid, text, text) is
  '通知の取り合い。claimed / retry / duplicate / rejected を返す。';
comment on function public.userlog_finish(uuid, text, text, text, text) is
  'Slack 送信の結果を sent または failed にする。本文は保存しない。';

-- ---------------------------------------------------------------------
-- 3. トリガーから Edge Function を呼ぶ（失敗しても元の INSERT は続ける）
-- ---------------------------------------------------------------------
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

create or replace function userlog.enqueue_json(p_body jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_url text;
  v_secret text;
begin
  if p_body is null or pg_catalog.jsonb_typeof(p_body) is distinct from 'object' then
    return false;
  end if;

  if pg_catalog.to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    raise warning 'userlog: pg_net http_post is not available';
    return false;
  end if;

  if pg_catalog.to_regclass('vault.decrypted_secrets') is null then
    raise warning 'userlog: vault is not available';
    return false;
  end if;

  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'project_url'
  limit 1;
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'userlog_notify_secret'
  limit 1;

  if v_url is null or btrim(v_url) = '' or v_secret is null or char_length(v_secret) < 32 then
    raise warning 'userlog: vault secrets project_url and userlog_notify_secret are required';
    return false;
  end if;

  perform net.http_post(
    url := rtrim(btrim(v_url), '/') || '/functions/v1/userlog-notify',
    body := p_body,
    headers := pg_catalog.jsonb_build_object(
      'Content-Type', 'application/json',
      'x-userlog-notify-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
  return true;
exception
  when others then
    raise warning 'userlog enqueue failed';
    return false;
end;
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

create or replace function userlog.on_store_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  begin
    if userlog.store_is_candidate(new.notification_type, new.subtype, new.verification_status) then
      perform userlog.enqueue_json(pg_catalog.jsonb_build_object(
        'kind', 'store',
        'source_id', new.notification_uuid
      ));
    end if;
  exception
    when others then
      raise warning 'userlog store notification skipped';
  end;
  return null;
end;
$function$;

revoke all on function userlog.store_is_candidate(text, text, text) from public;
revoke all on function userlog.enqueue_json(jsonb) from public;
revoke all on function userlog.on_app_event() from public;
revoke all on function userlog.on_auth_session() from public;
revoke all on function userlog.on_store_notification() from public;

grant usage on schema userlog to service_role;
grant execute on function userlog.on_app_event() to service_role;
grant execute on function userlog.on_auth_session() to service_role;
grant execute on function userlog.on_store_notification() to service_role;

do $userlog_auth_grant$
begin
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'supabase_auth_admin') then
    grant usage on schema userlog to supabase_auth_admin;
    grant execute on function userlog.on_auth_session() to supabase_auth_admin;
    grant execute on function userlog.on_app_event() to supabase_auth_admin;
    grant execute on function userlog.on_store_notification() to supabase_auth_admin;
  end if;
end
$userlog_auth_grant$;

drop trigger if exists userlog_app_events_insert on public.app_events;
create trigger userlog_app_events_insert
  after insert on public.app_events
  for each row
  when (new.event_name in ('app_install_first_open', 'onboarding_complete'))
  execute function userlog.on_app_event();

drop trigger if exists userlog_store_notifications_insert on public.store_server_notifications;
create trigger userlog_store_notifications_insert
  after insert on public.store_server_notifications
  for each row
  execute function userlog.on_store_notification();

drop trigger if exists userlog_auth_sessions_insert on auth.sessions;
create trigger userlog_auth_sessions_insert
  after insert on auth.sessions
  for each row
  execute function userlog.on_auth_session();

-- ---------------------------------------------------------------------
-- 4. 公開以降の取りこぼしを、通常の通知として 1 件ずつ積む。自動では走らない。
--    公開: 2026-10-14 20:17 UTC。二重送信は userlog_claim が止める。
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

notify pgrst, 'reload schema';
