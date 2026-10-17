-- KPI 除外の件数。作り直し（新しい user_id、同じ provider_id）、
-- 退会（deleted_at。メールの書き換えには頼らない）、ふつうの利用者。
-- サンプルの識別子だけを使う。本番のログイン識別子は書かない。

insert into auth.users (id, email, created_at) values
  ('00000000-0000-0000-0000-000000000001', 'ordinary@example.test', timezone('utc', now())),
  ('00000000-0000-0000-0000-000000000002', 'ceo-apple@example.test', timezone('utc', now())),
  ('00000000-0000-0000-0000-000000000003', 'ceo-google@example.test', timezone('utc', now())),
  ('00000000-0000-0000-0000-000000000004', 'deleted-ordinary@example.test', timezone('utc', now())),
  ('00000000-0000-0000-0000-000000000005', 'deleted+00000000-0000-0000-0000-000000000005@invalid.local', timezone('utc', now())),
  ('00000000-0000-0000-0000-000000000006', 'deleted+00000000-0000-0000-0000-000000000006@invalid.local', timezone('utc', now()));

insert into public.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'ordinary@example.test'),
  ('00000000-0000-0000-0000-000000000002', 'ceo-apple@example.test'),
  ('00000000-0000-0000-0000-000000000003', 'ceo-google@example.test'),
  ('00000000-0000-0000-0000-000000000004', 'deleted-ordinary@example.test'),
  ('00000000-0000-0000-0000-000000000005', null),
  ('00000000-0000-0000-0000-000000000006', 'deleted+00000000-0000-0000-0000-000000000006@invalid.local');

insert into auth.identities (user_id, provider, provider_id) values
  ('00000000-0000-0000-0000-000000000001', 'google', 'ordinary-google-sub'),
  ('00000000-0000-0000-0000-000000000002', 'apple', 'ceo-apple-sub'),
  ('00000000-0000-0000-0000-000000000003', 'google', 'ceo-google-sub');

-- 退会関数が残す印。004 はメールを書き換えていない。005 は書き換え済み。
update public.users
set deleted_at = timezone('utc', now())
where id in (
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000005'
);

insert into public.profiles (user_id, birth_date, gender, height_cm, weight_kg) values
  ('00000000-0000-0000-0000-000000000001', '1990-01-01', 'other', 170, 60),
  ('00000000-0000-0000-0000-000000000002', '1990-01-01', 'other', 170, 60),
  ('00000000-0000-0000-0000-000000000003', '1990-01-01', 'other', 170, 60);

insert into public.plus_funnel_events (user_id, event) values
  ('00000000-0000-0000-0000-000000000001', 'paywall_open'),
  ('00000000-0000-0000-0000-000000000002', 'purchase_success'),
  ('00000000-0000-0000-0000-000000000003', 'plan_select'),
  ('00000000-0000-0000-0000-000000000004', 'paywall_open');

insert into public.calonavi_plus_entitlements (user_id, product_id, expires_at, status) values
  ('00000000-0000-0000-0000-000000000001', 'calonavi_plus_monthly', timezone('utc', now()) + interval '30 days', 'active'),
  ('00000000-0000-0000-0000-000000000002', 'calonavi_plus_yearly', timezone('utc', now()) + interval '300 days', 'active');

insert into public.app_event_user_days (user_id, day, event_count, events) values
  ('00000000-0000-0000-0000-000000000001', '2026-10-10', 2, '{"paywall_open": 2}'::jsonb),
  ('00000000-0000-0000-0000-000000000003', '2026-10-10', 4, '{"plan_select": 4}'::jsonb),
  ('00000000-0000-0000-0000-000000000004', '2026-10-09', 1, '{"paywall_open": 1}'::jsonb);

insert into public.analytics_consents (
  consent_id, user_id, install_id, consented, policy_version, decided_at, surface
) values
  (
    '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000a1',
    true, '1', timezone('utc', now()), 'settings'
  ),
  (
    '00000000-0000-0000-0000-000000000012',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000a2',
    true, '1', timezone('utc', now()), 'settings'
  ),
  (
    '00000000-0000-0000-0000-000000000013',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-0000000000a2',
    true, '1', timezone('utc', now()), 'settings'
  );

do $$
declare
  users_before integer;
  funnel_before integer;
  ordinary_before integer;
begin
  select count(*) into users_before from kpi.users;
  select count(*) into funnel_before from kpi.plus_funnel_events;
  select count(*) into ordinary_before
  from kpi.users
  where id = '00000000-0000-0000-0000-000000000001';

  -- 退会済みは sub を入れる前から 0。メールを書き換えただけの行は残る。
  if users_before <> 4 then
    raise exception 'before exclusion rows, kpi.users = %, expected 4', users_before;
  end if;
  if ordinary_before <> 1 then
    raise exception 'ordinary user missing before exclusion rows';
  end if;
  if exists (
    select 1 from kpi.users
    where id in (
      '00000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000005'
    )
  ) then
    raise exception 'deleted_at users were counted before exclusion rows';
  end if;
  if not exists (
    select 1 from kpi.users
    where id = '00000000-0000-0000-0000-000000000006'
  ) then
    raise exception 'email rewrite alone was treated as deletion';
  end if;
  if funnel_before <> 3 then
    raise exception 'before exclusion rows, kpi.plus_funnel_events = %, expected 3', funnel_before;
  end if;
  raise notice 'before: kpi.users=% funnel=% ordinary=%', users_before, funnel_before, ordinary_before;
end
$$;

-- 作り直しても同じ sub。user_id は入れない。
insert into public.kpi_excluded_users (provider, provider_id, reason) values
  ('apple', 'ceo-apple-sub', 'fixture_apple'),
  ('google', 'ceo-google-sub', 'fixture_google');

-- ログイン前の端末だけ。アカウント除外とは別。
insert into public.kpi_excluded_users (install_id, reason) values
  ('00000000-0000-0000-0000-0000000000a1', 'fixture_install');

-- 退会関数は identities を消す前、deleted_at を立てる前に除外を写す。
-- 001 は一覧に無いので偽。002 は sub が一致するので真。
insert into public.anon_subjects (
  anon_subject_id, age_band, plan_type, kpi_excluded, deleted_at_hour
) values
  (
    '00000000-0000-0000-0000-000000000021',
    '30s',
    'none',
    exists (
      select 1 from kpi.excluded_user_ids x
      where x.user_id = '00000000-0000-0000-0000-000000000001'
    ),
    date_trunc('hour', timezone('utc', now()))
  ),
  (
    '00000000-0000-0000-0000-000000000022',
    '30s',
    'none',
    exists (
      select 1 from kpi.excluded_user_ids x
      where x.user_id = '00000000-0000-0000-0000-000000000002'
    ),
    date_trunc('hour', timezone('utc', now()))
  );

do $$
declare
  n integer;
  ordinary_users integer;
  ordinary_funnel integer;
  ordinary_entitlements integer;
  ordinary_days integer;
  ordinary_profiles integer;
begin
  select count(*) into n from public.users
  where id in (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000006'
  );
  if n <> 6 then
    raise exception 'public.users lost rows: %', n;
  end if;

  select count(*) into n from kpi.users
  where id in (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000005'
  );
  if n <> 0 then
    raise exception 'ceo or deleted users still in kpi.users: %', n;
  end if;

  select count(*) into ordinary_users from kpi.users
  where id = '00000000-0000-0000-0000-000000000001';
  if ordinary_users <> 1 then
    raise exception 'ordinary kpi.users = %, expected 1', ordinary_users;
  end if;

  select count(*) into n from kpi.users
  where id = '00000000-0000-0000-0000-000000000006';
  if n <> 1 then
    raise exception 'rewritten email without deleted_at was excluded';
  end if;

  select count(*) into ordinary_funnel from kpi.plus_funnel_events
  where user_id = '00000000-0000-0000-0000-000000000001';
  select count(*) into n from kpi.plus_funnel_events
  where user_id <> '00000000-0000-0000-0000-000000000001';
  if ordinary_funnel <> 1 or n <> 0 then
    raise exception 'funnel ordinary=% other=%', ordinary_funnel, n;
  end if;

  select count(*) into ordinary_entitlements from kpi.calonavi_plus_entitlements
  where user_id = '00000000-0000-0000-0000-000000000001';
  select count(*) into n from kpi.calonavi_plus_entitlements
  where user_id <> '00000000-0000-0000-0000-000000000001';
  if ordinary_entitlements <> 1 or n <> 0 then
    raise exception 'entitlements ordinary=% other=%', ordinary_entitlements, n;
  end if;

  select count(*) into ordinary_days from kpi.app_event_user_days
  where user_id = '00000000-0000-0000-0000-000000000001';
  select count(*) into n from kpi.app_event_user_days
  where user_id <> '00000000-0000-0000-0000-000000000001';
  if ordinary_days <> 1 or n <> 0 then
    raise exception 'retention days ordinary=% other=%', ordinary_days, n;
  end if;

  select count(*) into ordinary_profiles from kpi.profiles
  where user_id = '00000000-0000-0000-0000-000000000001';
  select count(*) into n from kpi.profiles;
  if ordinary_profiles <> 1 or n <> 1 then
    raise exception 'profiles ordinary=% kpi.profiles=%', ordinary_profiles, n;
  end if;

  select count(*) into n from public.profiles
  where user_id in (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003'
  );
  if n <> 3 then
    raise exception 'public.profiles was deleted: %', n;
  end if;

  -- 退会の匿名行。ふつうの退会は残る。ログイン除外は 0。
  select count(*) into n from kpi.anon_subjects
  where anon_subject_id = '00000000-0000-0000-0000-000000000021';
  if n <> 1 then
    raise exception 'ordinary anon subject was excluded';
  end if;
  select count(*) into n from kpi.anon_subjects
  where anon_subject_id = '00000000-0000-0000-0000-000000000022';
  if n <> 0 then
    raise exception 'ceo anon subject was counted';
  end if;

  -- install_id は端末だけ。ふつうの利用者の別端末は残る。
  select count(*) into n from kpi.analytics_consents
  where consent_id = '00000000-0000-0000-0000-000000000011';
  if n <> 0 then
    raise exception 'excluded install was counted';
  end if;
  select count(*) into n from kpi.analytics_consents
  where consent_id = '00000000-0000-0000-0000-000000000012';
  if n <> 1 then
    raise exception 'ordinary install was excluded';
  end if;
  select count(*) into n from kpi.analytics_consents
  where consent_id = '00000000-0000-0000-0000-000000000013';
  if n <> 0 then
    raise exception 'ceo consent was counted';
  end if;
  if exists (
    select 1 from kpi.excluded_install_ids
    where install_id = '00000000-0000-0000-0000-0000000000a2'
  ) then
    raise exception 'user exclusion spread to an install_id';
  end if;

  raise notice 'after: kpi.users ordinary=% funnel=% entitlements=% retention_days=% profiles=%',
    ordinary_users, ordinary_funnel, ordinary_entitlements, ordinary_days, ordinary_profiles;
end
$$;

-- 同じ sub で作り直す。古い identity は退会で消えている。
delete from auth.identities
where user_id = '00000000-0000-0000-0000-000000000003';

update public.users
set email = null,
    deleted_at = timezone('utc', now())
where id = '00000000-0000-0000-0000-000000000003';

insert into auth.users (id, email, created_at) values
  ('00000000-0000-0000-0000-000000000007', 'ceo-google-again@example.test', timezone('utc', now()));

insert into public.users (id, email) values
  ('00000000-0000-0000-0000-000000000007', 'ceo-google-again@example.test');

insert into auth.identities (user_id, provider, provider_id) values
  ('00000000-0000-0000-0000-000000000007', 'google', 'ceo-google-sub');

insert into public.plus_funnel_events (user_id, event) values
  ('00000000-0000-0000-0000-000000000007', 'purchase_tap');

do $$
declare
  n integer;
begin
  select count(*) into n from kpi.users
  where id = '00000000-0000-0000-0000-000000000007';
  if n <> 0 then
    raise exception 'recreated login was counted';
  end if;
  select count(*) into n from kpi.plus_funnel_events
  where user_id = '00000000-0000-0000-0000-000000000007';
  if n <> 0 then
    raise exception 'recreated funnel event was counted';
  end if;
  select count(*) into n from kpi.users
  where id = '00000000-0000-0000-0000-000000000001';
  if n <> 1 then
    raise exception 'ordinary user dropped after recreation';
  end if;
  select count(*) into n from public.users
  where id = '00000000-0000-0000-0000-000000000007';
  if n <> 1 then
    raise exception 'recreated public.users row is missing';
  end if;
  raise notice 'recreated login in kpi.users=0 ordinary=1';
end
$$;

do $$
begin
  if has_table_privilege('anon', 'public.kpi_excluded_users', 'select')
     or has_table_privilege('authenticated', 'public.kpi_excluded_users', 'select')
     or has_table_privilege('anon', 'kpi.users', 'select')
     or has_table_privilege('authenticated', 'kpi.users', 'select') then
    raise exception 'kpi exclusion is readable by anon or authenticated';
  end if;
  if not has_table_privilege('authenticated', 'public.users', 'select') then
    raise exception 'authenticated lost select on public.users';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'users_select_own'
  ) then
    raise exception 'users_select_own policy is missing';
  end if;
  if has_function_privilege('anon', 'kpi.collect_excluded_user_ids()', 'execute')
     or has_function_privilege(
       'authenticated', 'kpi.collect_excluded_user_ids()', 'execute'
     ) then
    raise exception 'exclusion function is executable by anon or authenticated';
  end if;
  if not has_function_privilege(
    'service_role', 'kpi.collect_excluded_user_ids()', 'execute'
  ) then
    raise exception 'service_role cannot execute the exclusion function';
  end if;
end
$$;
