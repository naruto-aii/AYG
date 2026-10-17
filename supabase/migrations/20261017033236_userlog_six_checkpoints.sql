-- =====================================================================
-- 利用者ログの Slack 投稿を 6 種類に絞る。
--
-- 出すもの: 新規会員登録、無料トライアル開始、有料開始、
--   トライアル解約、サブスク解約、アカウント削除。
-- やめるもの: インストール、ログイン、期限切れ、返金。
--
-- このファイルは本番へ適用しない。関数の配備が先、このファイルが後。
-- 適用時に過去分は送らない。既存の表の列・制約・行は変えない。
-- ログインは userlog_app_events_login_insert を外すだけ。関数は残す。
-- 解約の記録はこれまで通り cancel。文面の分け方は Edge Function が行う。
-- アカウント削除は新しい表で二重送信を止める。個人の識別子は書かない。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. インストールは積まない。新規会員登録だけ積む。
-- ---------------------------------------------------------------------
create or replace function userlog.on_app_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  begin
    if new.event_name = 'onboarding_complete' then
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
  when (new.event_name = 'onboarding_complete')
  execute function userlog.on_app_event();

-- ログインのトリガーだけ外す。userlog.on_install_login は残す。
do $userlog_drop_login$
declare
  r record;
begin
  for r in
    select n.nspname, c.relname
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where t.tgname = 'userlog_app_events_login_insert'
      and not t.tgisinternal
  loop
    execute format(
      'drop trigger if exists userlog_app_events_login_insert on %I.%I',
      r.nspname,
      r.relname
    );
  end loop;
end
$userlog_drop_login$;

-- ---------------------------------------------------------------------
-- 2. 期限切れと返金は候補にしない。有料開始と自動更新オフは残す。
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
      p_type in ('INITIAL_BUY', 'DID_RENEW')
      or (p_type = 'SUBSCRIBED' and p_subtype = 'INITIAL_BUY')
      or (p_type = 'DID_CHANGE_RENEWAL_STATUS' and p_subtype = 'AUTO_RENEW_DISABLED')
      or p_subtype = 'INITIAL_BUY'
    );
$function$;

-- ---------------------------------------------------------------------
-- 3. アカウント削除。行が増えたときだけ。集計の更新では送らない。
--    二重送信は新しい表。userlog_notifications_sent の種類は変えない。
-- ---------------------------------------------------------------------
create table if not exists public.userlog_account_deletion_sent (
  deleted_on date not null,
  plus_status text not null,
  plan text not null,
  account_age_bucket text not null,
  status text not null default 'pending',
  claimed_at timestamptz not null default pg_catalog.timezone('utc', pg_catalog.now()),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default pg_catalog.timezone('utc', pg_catalog.now()),
  constraint userlog_account_deletion_sent_pk
    primary key (deleted_on, plus_status, plan, account_age_bucket),
  constraint userlog_account_deletion_sent_status check (
    status in ('pending', 'sent', 'failed')
  ),
  constraint userlog_account_deletion_sent_error check (
    last_error is null or char_length(last_error) <= 200
  ),
  constraint userlog_account_deletion_sent_plus check (
    char_length(plus_status) between 1 and 16
  ),
  constraint userlog_account_deletion_sent_plan check (
    char_length(plan) between 1 and 64
  ),
  constraint userlog_account_deletion_sent_bucket check (
    char_length(account_age_bucket) between 1 and 16
  )
);

comment on table public.userlog_account_deletion_sent is
  'アカウント削除の Slack 送信済み。プランと期間の区分だけ。個人の識別子は持たない。';

alter table public.userlog_account_deletion_sent enable row level security;
revoke all on table public.userlog_account_deletion_sent from public, anon, authenticated;
grant select, insert, update, delete on table public.userlog_account_deletion_sent to service_role;

create or replace function public.userlog_account_deletion_claim(
  p_deleted_on date,
  p_plus_status text,
  p_plan text,
  p_age_bucket text
)
returns text
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_status text;
  v_claimed timestamptz;
  v_updated date;
begin
  if p_deleted_on is null
     or p_plus_status is null
     or p_plan is null
     or p_age_bucket is null
     or char_length(p_plus_status) < 1
     or char_length(p_plus_status) > 16
     or char_length(p_plan) < 1
     or char_length(p_plan) > 64
     or char_length(p_age_bucket) < 1
     or char_length(p_age_bucket) > 16
     or p_plus_status !~ '^[a-z]+$'
     or p_plan !~ '^[A-Za-z0-9._-]+$'
     or p_age_bucket !~ '^[0-9A-Za-z+][0-9A-Za-z+-]*$' then
    return 'rejected';
  end if;

  insert into public.userlog_account_deletion_sent (
    deleted_on, plus_status, plan, account_age_bucket, status, claimed_at
  ) values (
    p_deleted_on,
    p_plus_status,
    p_plan,
    p_age_bucket,
    'pending',
    pg_catalog.timezone('utc', pg_catalog.now())
  )
  on conflict on constraint userlog_account_deletion_sent_pk do nothing
  returning deleted_on into v_updated;
  if v_updated is not null then
    return 'claimed';
  end if;

  select status, claimed_at
    into v_status, v_claimed
  from public.userlog_account_deletion_sent
  where deleted_on = p_deleted_on
    and plus_status = p_plus_status
    and plan = p_plan
    and account_age_bucket = p_age_bucket
  for update;

  if v_status is null or v_status = 'sent' then
    return 'duplicate';
  end if;

  if v_status = 'failed'
     or (
       v_status = 'pending'
       and v_claimed < pg_catalog.timezone('utc', pg_catalog.now()) - interval '5 minutes'
     ) then
    v_updated := null;
    update public.userlog_account_deletion_sent
    set status = 'pending',
        claimed_at = pg_catalog.timezone('utc', pg_catalog.now()),
        last_error = null
    where deleted_on = p_deleted_on
      and plus_status = p_plus_status
      and plan = p_plan
      and account_age_bucket = p_age_bucket
      and status = v_status
    returning deleted_on into v_updated;
    if v_updated is not null then
      return 'retry';
    end if;
  end if;

  return 'duplicate';
end;
$function$;

create or replace function public.userlog_account_deletion_finish(
  p_deleted_on date,
  p_plus_status text,
  p_plan text,
  p_age_bucket text,
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
  update public.userlog_account_deletion_sent
  set status = p_status,
      sent_at = case
        when p_status = 'sent' then pg_catalog.timezone('utc', pg_catalog.now())
        else sent_at
      end,
      last_error = case
        when p_status = 'failed' then left(coalesce(p_error, 'delivery_failed'), 200)
        else null
      end
  where deleted_on = p_deleted_on
    and plus_status = p_plus_status
    and plan = p_plan
    and account_age_bucket = p_age_bucket;
end;
$function$;

revoke all on function public.userlog_account_deletion_claim(date, text, text, text)
  from public, anon, authenticated;
revoke all on function public.userlog_account_deletion_finish(date, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.userlog_account_deletion_claim(date, text, text, text) to service_role;
grant execute on function public.userlog_account_deletion_finish(date, text, text, text, text, text)
  to service_role;

comment on function public.userlog_account_deletion_claim(date, text, text, text) is
  'アカウント削除通知の取り合い。claimed / retry / duplicate / rejected を返す。個人の識別子は受け取らない。';
comment on function public.userlog_account_deletion_finish(date, text, text, text, text, text) is
  'アカウント削除の Slack 送信結果を sent または failed にする。本文は保存しない。';

create or replace function userlog.on_account_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  begin
    perform userlog.enqueue_json(pg_catalog.jsonb_build_object(
      'kind', 'account_deletion',
      'deleted_on', new.deleted_on,
      'plus_status', new.plus_status,
      'plan', new.plan,
      'account_age_bucket', new.account_age_bucket
    ));
  exception
    when others then
      raise warning 'userlog account deletion skipped';
  end;
  return null;
end;
$function$;

revoke all on function userlog.on_account_deletion() from public;
grant execute on function userlog.on_account_deletion() to service_role;
comment on function userlog.on_account_deletion() is
  'account_deletion_stats に行が増えたときだけ userlog-notify を呼ぶ。件数の更新では呼ばない。失敗しても挿入は続ける。';

do $userlog_deletion_trigger$
begin
  if pg_catalog.to_regclass('public.account_deletion_stats') is null then
    raise warning 'userlog: account_deletion_stats is missing; deletion trigger was not created';
  else
    drop trigger if exists userlog_account_deletion_insert on public.account_deletion_stats;
    create trigger userlog_account_deletion_insert
      after insert on public.account_deletion_stats
      for each row
      execute function userlog.on_account_deletion();
  end if;
end
$userlog_deletion_trigger$;

-- ---------------------------------------------------------------------
-- 4. 取りこぼしを積む関数も、やめた種類は対象にしない。適用時には走らない。
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
        where event_name = 'onboarding_complete'
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
  '公開以降の新規会員登録と購入通知を積む。インストール、ログイン、期限切れ、返金は積まない。適用時には走らない。';

notify pgrst, 'reload schema';
