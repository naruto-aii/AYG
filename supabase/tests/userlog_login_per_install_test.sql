-- ログインは利用者とインストールの組で 1 回。このファイルは本番に流さない。

begin;

select plan(28);

select hasnt_trigger(
  'auth',
  'sessions',
  'userlog_auth_sessions_insert',
  'auth.sessions has no userlog trigger'
);

select has_trigger(
  'public',
  'app_events',
  'userlog_app_events_login_insert',
  'app_events has the install login trigger'
);

select ok(
  (
    select pg_get_triggerdef(t.oid) ilike '%for each statement%'
      and pg_get_triggerdef(t.oid) ilike '%referencing new table%'
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'app_events'
      and t.tgname = 'userlog_app_events_login_insert'
      and not t.tgisinternal
  ),
  'login trigger reads one insert as a batch'
);

select has_trigger(
  'public',
  'app_events',
  'userlog_app_events_insert',
  'install and onboarding trigger remains'
);

do $pair$
begin
  delete from public.userlog_test_http_log;
  update public.userlog_test_mode set fail = false;
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c1111111-1111-4111-8111-111111111111',
    'a1111111-1111-4111-8111-111111111111',
    'app_open',
    timestamptz '2026-10-15 00:00:00+00',
    'b1111111-1111-4111-8111-111111111111'
  );
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c1111111-1111-4111-8111-111111111112',
    'a1111111-1111-4111-8111-111111111111',
    'app_open',
    timestamptz '2026-10-15 00:01:00+00',
    'b1111111-1111-4111-8111-111111111111'
  );
end
$pair$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'a1111111-1111-4111-8111-111111111111'
      and body ->> 'source_id' = 'b1111111-1111-4111-8111-111111111111'
  ),
  1,
  'the same user and install notifies once'
);

do $new_install$
begin
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c1111111-1111-4111-8111-111111111113',
    'a1111111-1111-4111-8111-111111111111',
    'app_open',
    timestamptz '2026-10-15 00:02:00+00',
    'b2222222-2222-4222-8222-222222222222'
  );
end
$new_install$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'a1111111-1111-4111-8111-111111111111'
      and body ->> 'source_id' = 'b2222222-2222-4222-8222-222222222222'
  ),
  1,
  'a new install id notifies'
);

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'a1111111-1111-4111-8111-111111111111'
      and body ->> 'source_id' = 'b1111111-1111-4111-8111-111111111111'
  ),
  1,
  'the first install was not notified again'
);

do $other_user$
begin
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c1111111-1111-4111-8111-111111111114',
    'a9999999-9999-4999-8999-999999999999',
    'app_open',
    timestamptz '2026-10-15 00:03:00+00',
    'b1111111-1111-4111-8111-111111111111'
  );
end
$other_user$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'a9999999-9999-4999-8999-999999999999'
      and body ->> 'source_id' = 'b1111111-1111-4111-8111-111111111111'
  ),
  1,
  'another user on the same install notifies once'
);

do $batch_same$
begin
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values
    (
      'cb111111-1111-4111-8111-111111111111',
      'ab111111-1111-4111-8111-111111111111',
      'app_open',
      timestamptz '2026-10-15 06:00:00+00',
      'bb111111-1111-4111-8111-111111111111'
    ),
    (
      'cb111111-1111-4111-8111-111111111112',
      'ab111111-1111-4111-8111-111111111111',
      'app_open',
      timestamptz '2026-10-15 06:01:00+00',
      'bb111111-1111-4111-8111-111111111111'
    ),
    (
      'cb111111-1111-4111-8111-111111111113',
      'ab111111-1111-4111-8111-111111111111',
      'app_open',
      timestamptz '2026-10-15 06:02:00+00',
      'bb111111-1111-4111-8111-111111111111'
    );
end
$batch_same$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'ab111111-1111-4111-8111-111111111111'
      and body ->> 'source_id' = 'bb111111-1111-4111-8111-111111111111'
  ),
  1,
  'one insert with several rows for a new pair notifies once'
);

do $batch_seen$
begin
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values
    (
      'cb111111-1111-4111-8111-111111111114',
      'ab111111-1111-4111-8111-111111111111',
      'app_open',
      timestamptz '2026-10-15 06:03:00+00',
      'bb111111-1111-4111-8111-111111111111'
    ),
    (
      'cb111111-1111-4111-8111-111111111115',
      'ab111111-1111-4111-8111-111111111111',
      'app_open',
      timestamptz '2026-10-15 06:04:00+00',
      'bb111111-1111-4111-8111-111111111111'
    );
end
$batch_seen$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'ab111111-1111-4111-8111-111111111111'
      and body ->> 'source_id' = 'bb111111-1111-4111-8111-111111111111'
  ),
  1,
  'a later batch for an already-seen pair does not notify'
);

do $batch_mixed$
begin
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values
    (
      'cb222222-2222-4222-8222-222222222221',
      'ab222222-2222-4222-8222-222222222222',
      'app_open',
      timestamptz '2026-10-15 07:00:00+00',
      'bb222222-2222-4222-8222-222222222222'
    ),
    (
      'cb222222-2222-4222-8222-222222222222',
      'ab222222-2222-4222-8222-222222222222',
      'app_open',
      timestamptz '2026-10-15 07:01:00+00',
      'bb222222-2222-4222-8222-222222222222'
    ),
    (
      'cb333333-3333-4333-8333-333333333333',
      'ab222222-2222-4222-8222-222222222222',
      'app_open',
      timestamptz '2026-10-15 07:02:00+00',
      'bb333333-3333-4333-8333-333333333333'
    );
end
$batch_mixed$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'ab222222-2222-4222-8222-222222222222'
  ),
  2,
  'one insert with two new pairs notifies twice'
);

do $nulls$
begin
  create temp table if not exists userlog_pgtap_mark (label text primary key, n integer not null);
  insert into userlog_pgtap_mark (label, n)
  values ('before_null', (select count(*)::int from public.userlog_test_http_log))
  on conflict (label) do update set n = excluded.n;
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c0000000-0000-4000-8000-000000000001',
    null,
    'app_open',
    timestamptz '2026-10-15 00:04:00+00',
    'b1111111-1111-4111-8111-111111111111'
  );
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c0000000-0000-4000-8000-000000000002',
    'a1111111-1111-4111-8111-111111111111',
    'app_open',
    timestamptz '2026-10-15 00:05:00+00',
    null
  );
  insert into auth.sessions (id, user_id, created_at)
  values (
    'd9999999-9999-4999-8999-999999999999',
    'a1111111-1111-4111-8111-111111111111',
    timestamptz '2026-10-15 00:06:00+00'
  );
end
$nulls$;

select is(
  (select count(*)::int from public.userlog_test_http_log),
  (select n from userlog_pgtap_mark where label = 'before_null'),
  'null ids and auth.sessions do not notify'
);

do $remap$
begin
  alter table public.app_events disable trigger userlog_app_events_login_insert;
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values
    (
      'c2222222-2222-4222-8222-222222222221',
      'a2222222-2222-4222-8222-222222222222',
      'app_open',
      timestamptz '2026-10-15 01:00:00+00',
      'b3333333-3333-4333-8333-333333333333'
    ),
    (
      'c3333333-3333-4333-8333-333333333331',
      'a3333333-3333-4333-8333-333333333333',
      'app_open',
      timestamptz '2026-10-15 01:00:00+00',
      'b4444444-4444-4444-8444-444444444444'
    ),
    (
      'c3333333-3333-4333-8333-333333333332',
      'a3333333-3333-4333-8333-333333333333',
      'app_open',
      timestamptz '2026-10-15 01:01:00+00',
      'b5555555-5555-4555-8555-555555555555'
    ),
    (
      'c5555555-5555-4555-8555-555555555551',
      'a5555555-5555-4555-8555-555555555555',
      'app_open',
      timestamptz '2026-10-15 01:00:00+00',
      'b6666666-6666-4666-8666-666666666666'
    );
  insert into public.userlog_notifications_sent (user_id, checkpoint_type, source_id, status)
  values
    ('a2222222-2222-4222-8222-222222222222', 'login', 'd1111111-1111-4111-8111-111111111111', 'sent'),
    ('a3333333-3333-4333-8333-333333333333', 'login', 'd2222222-2222-4222-8222-222222222222', 'sent'),
    ('a4444444-4444-4444-8444-444444444444', 'login', 'd3333333-3333-4333-8333-333333333333', 'sent'),
    ('a5555555-5555-4555-8555-555555555555', 'login', 'd4444444-4444-4444-8444-444444444444', 'sent'),
    ('a5555555-5555-4555-8555-555555555555', 'login', 'd5555555-5555-4555-8555-555555555555', 'sent');
  alter table public.app_events enable trigger userlog_app_events_login_insert;
  perform userlog.remap_login_installs();
end
$remap$;

select is(
  (
    select source_id
    from public.userlog_notifications_sent
    where user_id = 'a2222222-2222-4222-8222-222222222222'
      and checkpoint_type = 'login'
  ),
  'b3333333-3333-4333-8333-333333333333',
  'one install id rewrites the login row'
);

select is(
  (
    select count(*)::int
    from public.userlog_notifications_sent
    where user_id = 'a2222222-2222-4222-8222-222222222222'
      and checkpoint_type = 'login'
  ),
  1,
  'remap does not add a login row'
);

select is(
  (
    select source_id
    from public.userlog_notifications_sent
    where user_id = 'a3333333-3333-4333-8333-333333333333'
      and checkpoint_type = 'login'
  ),
  'd2222222-2222-4222-8222-222222222222',
  'two install ids leave the login row'
);

select is(
  (
    select source_id
    from public.userlog_notifications_sent
    where user_id = 'a4444444-4444-4444-8444-444444444444'
      and checkpoint_type = 'login'
  ),
  'd3333333-3333-4333-8333-333333333333',
  'a user with no events stays unresolved'
);

select is(
  (
    select count(*)::int
    from public.userlog_notifications_sent
    where user_id = 'a5555555-5555-4555-8555-555555555555'
      and checkpoint_type = 'login'
  ),
  2,
  'a key collision does not drop a login row'
);

select is(
  (
    select count(*)::int
    from public.userlog_notifications_sent
    where user_id = 'a5555555-5555-4555-8555-555555555555'
      and checkpoint_type = 'login'
      and source_id = 'b6666666-6666-4666-8666-666666666666'
  ),
  1,
  'one of the colliding login rows carries the install id'
);

do $after$
begin
  delete from public.userlog_test_http_log;
  delete from public.app_events
  where user_id = 'a2222222-2222-4222-8222-222222222222';
  insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
  values (
    'c2222222-2222-4222-8222-222222222229',
    'a2222222-2222-4222-8222-222222222222',
    'app_open',
    timestamptz '2026-10-15 02:00:00+00',
    'b3333333-3333-4333-8333-333333333333'
  );
end
$after$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'source_id' = 'b3333333-3333-4333-8333-333333333333'
  ),
  0,
  'a rewritten login row does not notify again'
);

select is(
  public.userlog_claim(
    'a2222222-2222-4222-8222-222222222222',
    'login',
    'b3333333-3333-4333-8333-333333333333'
  ),
  'duplicate',
  'claim stays duplicate after remap'
);

do $backfill$
begin
  delete from public.userlog_test_http_log;
  perform userlog.enqueue_backfill();
end
$backfill$;

select is(
  (
    select count(*)::int
    from public.userlog_test_http_log
    where body ->> 'kind' = 'install_login'
      and body ->> 'user_id' = 'a2222222-2222-4222-8222-222222222222'
      and body ->> 'source_id' = 'b3333333-3333-4333-8333-333333333333'
  ),
  0,
  'backfill does not enqueue a sent install login'
);

select lives_ok(
  $sql$
  do $inner$
  begin
    update public.userlog_test_mode set fail = true;
    begin
      insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
      values (
        'c6666666-6666-4666-8666-666666666661',
        'a6666666-6666-4666-8666-666666666666',
        'app_open',
        timestamptz '2026-10-15 03:00:00+00',
        'b7777777-7777-4777-8777-777777777777'
      );
      update public.userlog_test_mode set fail = false;
    exception
      when others then
        update public.userlog_test_mode set fail = false;
        raise;
    end;
  end
  $inner$
  $sql$,
  'app_events insert succeeds when pg_net fails'
);

select is(
  (
    select count(*)::int
    from public.app_events
    where event_id = 'c6666666-6666-4666-8666-666666666661'
  ),
  1,
  'the app_events row remains when pg_net fails'
);

select lives_ok(
  $sql$
  do $inner$
  declare
    v_url text;
    v_secret text;
  begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets
    where name = 'project_url';
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'userlog_notify_secret';
    delete from vault.decrypted_secrets
    where name in ('project_url', 'userlog_notify_secret');
    begin
      insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
      values (
        'c7777777-7777-4777-8777-777777777771',
        'a7777777-7777-4777-8777-777777777777',
        'app_open',
        timestamptz '2026-10-15 03:01:00+00',
        'b8888888-8888-4888-8888-888888888888'
      );
    exception
      when others then
        insert into vault.decrypted_secrets (name, decrypted_secret) values
          ('project_url', v_url),
          ('userlog_notify_secret', v_secret)
        on conflict (name) do update set decrypted_secret = excluded.decrypted_secret;
        raise;
    end;
    insert into vault.decrypted_secrets (name, decrypted_secret) values
      ('project_url', v_url),
      ('userlog_notify_secret', v_secret)
    on conflict (name) do update set decrypted_secret = excluded.decrypted_secret;
  end
  $inner$
  $sql$,
  'app_events insert succeeds when vault secrets are missing'
);

select is(
  (
    select count(*)::int
    from public.app_events
    where event_id = 'c7777777-7777-4777-8777-777777777771'
  ),
  1,
  'the app_events row remains when vault secrets are missing'
);

select lives_ok(
  $sql$
  do $inner$
  begin
    alter function net.http_post(text, jsonb, jsonb, jsonb, integer)
      rename to http_post_disabled;
    begin
      insert into public.app_events (event_id, user_id, event_name, occurred_at, install_id)
      values (
        'c8888888-8888-4888-8888-888888888881',
        'a8888888-8888-4888-8888-888888888888',
        'app_open',
        timestamptz '2026-10-15 03:02:00+00',
        'b9999999-9999-4999-8999-999999999999'
      );
    exception
      when others then
        alter function net.http_post_disabled(text, jsonb, jsonb, jsonb, integer)
          rename to http_post;
        raise;
    end;
    alter function net.http_post_disabled(text, jsonb, jsonb, jsonb, integer)
      rename to http_post;
  end
  $inner$
  $sql$,
  'app_events insert succeeds when pg_net is unavailable'
);

select is(
  (
    select count(*)::int
    from public.app_events
    where event_id = 'c8888888-8888-4888-8888-888888888881'
  ),
  1,
  'the app_events row remains when pg_net is unavailable'
);

select lives_ok(
  $sql$
  do $inner$
  declare
    v_pairs integer;
    v_rows integer;
  begin
    create table public.userlog_pgtap_parts (
      event_id uuid not null,
      user_id uuid,
      install_id uuid,
      occurred_at timestamptz not null,
      primary key (event_id, occurred_at)
    ) partition by range (occurred_at);
    create table public.userlog_pgtap_parts_oct
      partition of public.userlog_pgtap_parts
      for values from ('2026-10-01') to ('2026-11-01');
    create table public.userlog_pgtap_parts_nov
      partition of public.userlog_pgtap_parts
      for values from ('2026-11-01') to ('2026-12-01');
    create table public.userlog_pgtap_part_log (
      pairs integer not null,
      batch_rows integer not null
    );
    create function public.userlog_pgtap_on_part()
    returns trigger
    language plpgsql
    as $fn$
    begin
      insert into public.userlog_pgtap_part_log (pairs, batch_rows)
      select count(*)::integer, (select count(*)::integer from new_rows)
      from (
        select user_id, install_id
        from new_rows
        where user_id is not null
          and install_id is not null
        group by user_id, install_id
      ) as pairs;
      return null;
    end
    $fn$;
    create trigger userlog_pgtap_parts_insert
      after insert on public.userlog_pgtap_parts
      referencing new table as new_rows
      for each statement
      execute function public.userlog_pgtap_on_part();
    insert into public.userlog_pgtap_parts (event_id, user_id, install_id, occurred_at)
    values
      (
        'cc111111-1111-4111-8111-111111111111',
        'ac111111-1111-4111-8111-111111111111',
        'bc111111-1111-4111-8111-111111111111',
        timestamptz '2026-10-15 08:00:00+00'
      ),
      (
        'cc111111-1111-4111-8111-111111111112',
        'ac111111-1111-4111-8111-111111111111',
        'bc111111-1111-4111-8111-111111111111',
        timestamptz '2026-10-16 08:00:00+00'
      ),
      (
        'cc111111-1111-4111-8111-111111111113',
        'ac111111-1111-4111-8111-111111111111',
        'bc222222-2222-4222-8222-222222222222',
        timestamptz '2026-11-02 08:00:00+00'
      );
    select pairs, batch_rows into v_pairs, v_rows
    from public.userlog_pgtap_part_log;
    if v_pairs is distinct from 2 or v_rows is distinct from 3 then
      raise exception 'partition batch saw % pairs and % rows', v_pairs, v_rows;
    end if;
    if (select count(*) from public.userlog_pgtap_part_log) is distinct from 1 then
      raise exception 'partition insert fired the statement trigger more than once';
    end if;
  end
  $inner$
  $sql$,
  'a partitioned table statement trigger sees the whole insert'
);

select * from finish();

rollback;
