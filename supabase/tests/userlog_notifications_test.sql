-- userlog のトリガーは、通知先が失敗しても元の INSERT を成功させる。
-- 同じ (user_id, checkpoint_type, source_id) は 1 行だけになる。
-- このファイルは本番に流さない。

create schema if not exists vault;
create table if not exists vault.decrypted_secrets (
  name text primary key,
  decrypted_secret text
);
insert into vault.decrypted_secrets (name, decrypted_secret) values
  ('project_url', 'http://127.0.0.1:54321'),
  ('userlog_notify_secret', repeat('a', 32))
on conflict (name) do update set decrypted_secret = excluded.decrypted_secret;

create schema if not exists net;
create sequence if not exists public.userlog_test_http_calls;
create table if not exists public.userlog_test_mode (
  fail boolean not null
);
insert into public.userlog_test_mode (fail)
select true
where not exists (select 1 from public.userlog_test_mode);

create table if not exists public.userlog_test_http_log (
  id bigint generated always as identity primary key,
  body jsonb not null
);

create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 2000
)
returns bigint
language plpgsql
as $function$
begin
  perform nextval('public.userlog_test_http_calls');
  if (select fail from public.userlog_test_mode) then
    raise exception 'webhook failed';
  end if;
  insert into public.userlog_test_http_log (body) values (coalesce(body, '{}'::jsonb));
  return 1;
end;
$function$;

do $test$
declare
  v_calls bigint;
  v_uid uuid := '11111111-1111-4111-8111-111111111111';
  v_install uuid := '22222222-2222-4222-8222-222222222222';
  v_event uuid := '33333333-3333-4333-8333-333333333333';
  v_other uuid := '44444444-4444-4444-8444-444444444444';
  v_session uuid := '55555555-5555-4555-8555-555555555555';
  v_notice uuid := '66666666-6666-4666-8666-666666666666';
  v_ignored uuid := '77777777-7777-4777-8777-777777777777';
  v_claim text;
begin
  insert into public.users (id) values (v_uid);
  insert into public.profiles (user_id, display_name) values (v_uid, '花子');

  update public.userlog_test_mode set fail = true;
  select last_value into v_calls from public.userlog_test_http_calls;

  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (v_event, v_uid, 'app_install_first_open', timestamptz '2026-10-14 20:17:00+00', v_install);
  if (select count(*) from public.app_events where event_id = v_event) <> 1 then
    raise exception 'app_events insert was rolled back when the webhook failed';
  end if;
  if (select last_value from public.userlog_test_http_calls) <= v_calls
     and not (select is_called from public.userlog_test_http_calls) then
    raise exception 'failed webhook was not attempted';
  end if;

  select last_value into v_calls from public.userlog_test_http_calls;
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (v_other, v_uid, 'app_open', timestamptz '2026-10-14 21:00:00+00', v_install);
  if (select count(*) from public.app_events where event_id = v_other) <> 1 then
    raise exception 'unrelated app_events insert failed';
  end if;
  if (select last_value from public.userlog_test_http_calls) <> v_calls then
    raise exception 'unrelated app event called the webhook';
  end if;

  insert into auth.sessions (id, user_id, created_at)
  values (v_session, v_uid, timestamptz '2026-10-14 20:18:00+00');
  if (select count(*) from auth.sessions where id = v_session) <> 1 then
    raise exception 'session insert was rolled back when the webhook failed';
  end if;

  insert into public.store_server_notifications (
    notification_uuid, notification_type, subtype, verification_status, user_id, received_at
  ) values (
    v_notice, 'DID_RENEW', null, 'verified', v_uid, timestamptz '2026-10-14 20:19:00+00'
  );
  if (select count(*) from public.store_server_notifications where notification_uuid = v_notice) <> 1 then
    raise exception 'store notification insert was rolled back when the webhook failed';
  end if;

  select last_value into v_calls from public.userlog_test_http_calls;
  insert into public.store_server_notifications (
    notification_uuid, notification_type, verification_status, received_at
  ) values (
    v_ignored, 'UNVERIFIED', 'failed', timestamptz '2026-10-14 20:20:00+00'
  );
  if (select last_value from public.userlog_test_http_calls) <> v_calls then
    raise exception 'unverified store notification called the webhook';
  end if;

  select public.userlog_claim(v_uid, 'install', v_event::text) into v_claim;
  if v_claim <> 'claimed' then
    raise exception 'first claim was %', v_claim;
  end if;
  select public.userlog_claim(v_uid, 'install', v_event::text) into v_claim;
  if v_claim <> 'duplicate' then
    raise exception 'second claim was %', v_claim;
  end if;
  if (
    select count(*) from public.userlog_notifications_sent
    where checkpoint_type = 'install' and source_id = v_event::text
  ) <> 1 then
    raise exception 'duplicate checkpoint was stored more than once';
  end if;

  select public.userlog_claim(null, 'cancel', v_notice::text) into v_claim;
  select public.userlog_claim(null, 'cancel', v_notice::text) into v_claim;
  if v_claim <> 'duplicate' then
    raise exception 'null user claim was %', v_claim;
  end if;
  if (
    select count(*) from public.userlog_notifications_sent
    where user_id is null and checkpoint_type = 'cancel' and source_id = v_notice::text
  ) <> 1 then
    raise exception 'null user_id did not dedup';
  end if;

  perform public.userlog_finish(v_uid, 'install', v_event::text, 'failed', 'delivery_failed');
  select public.userlog_claim(v_uid, 'install', v_event::text) into v_claim;
  if v_claim <> 'retry' then
    raise exception 'failed claim did not retry: %', v_claim;
  end if;
  perform public.userlog_finish(v_uid, 'install', v_event::text, 'sent', null);
  select public.userlog_claim(v_uid, 'install', v_event::text) into v_claim;
  if v_claim <> 'duplicate' then
    raise exception 'sent claim was not duplicate: %', v_claim;
  end if;

  if (public.userlog_context(v_uid, null) ->> 'display_name') <> '花子' then
    raise exception 'display name was not read';
  end if;
  if (public.userlog_context(v_uid, null) ->> 'excluded') <> 'false' then
    raise exception 'ordinary user was excluded';
  end if;
  insert into public.kpi_excluded_users (user_id, reason) values (v_uid, 'developer');
  if (public.userlog_context(v_uid, null) ->> 'excluded') <> 'true' then
    raise exception 'kpi exclusion was not applied';
  end if;
  delete from public.kpi_excluded_users where user_id = v_uid;
  update public.users set deleted_at = timezone('utc', now()) where id = v_uid;
  if (public.userlog_context(v_uid, null) ->> 'excluded') <> 'true' then
    raise exception 'deleted account was not excluded';
  end if;

  set local role service_role;
  select public.userlog_claim(v_uid, 'login', v_session::text) into v_claim;
  if v_claim <> 'claimed' then
    raise exception 'service role claim was %', v_claim;
  end if;
  reset role;

  set local role anon;
  begin
    perform count(*) from public.userlog_notifications_sent;
    raise exception 'anon read the notification ledger';
  exception
    when insufficient_privilege then
      null;
  end;
  begin
    perform public.userlog_claim(v_uid, 'login', v_session::text);
    raise exception 'anon claimed a notification';
  exception
    when insufficient_privilege then
      null;
  end;
  reset role;

  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    '88888888-8888-4888-8888-888888888888',
    v_uid,
    'app_install_first_open',
    timestamptz '2026-10-14 20:16:00+00',
    v_install
  );
  if (select count(*) from public.app_events where occurred_at < timestamptz '2026-10-14 20:17:00+00') <> 1 then
    raise exception 'pre-release event was not stored';
  end if;

  update public.userlog_test_mode set fail = false;
  delete from public.userlog_test_http_log;
  if userlog.enqueue_backfill() < 1 then
    raise exception 'backfill queued nothing';
  end if;
  if not exists (
    select 1 from public.userlog_test_http_log
    where body ->> 'source_id' = v_event::text
  ) then
    raise exception 'backfill missed a post-release install';
  end if;
  if exists (
    select 1 from public.userlog_test_http_log
    where body ->> 'source_id' = '88888888-8888-4888-8888-888888888888'
  ) then
    raise exception 'backfill queued a pre-release install';
  end if;
end
$test$;
