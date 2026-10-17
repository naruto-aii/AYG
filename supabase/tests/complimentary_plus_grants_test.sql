-- 本番には流さない。付与は社長役の3ログインだけ、それ以外の有料判定は変えない。

do $$
declare
  column_n integer;
begin
  select count(*) into column_n
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'kpi_excluded_users'
    and column_name in (
      'id', 'user_id', 'install_id', 'email', 'reason', 'added_at', 'provider', 'provider_id'
    );
  if column_n <> 8 then
    raise exception 'kpi_excluded_users does not match production columns: %', column_n;
  end if;
  begin
    insert into public.kpi_excluded_users (provider, reason)
    values ('apple', 'shape_check');
    raise exception 'provider without provider_id was accepted';
  exception
    when check_violation then
      null;
  end;
end
$$;

insert into public.users (id, email, deleted_at) values
  ('00000000-0000-4000-8000-000000000001', 'fixture-apple@example.test', null),
  ('00000000-0000-4000-8000-000000000002', 'fixture-google-one@example.test', null),
  ('00000000-0000-4000-8000-000000000003', 'fixture-google-two@example.test', null),
  ('00000000-0000-4000-8000-000000000004', 'fixture-ordinary@example.test', null),
  ('00000000-0000-4000-8000-000000000005', 'fixture-reviewer@example.test', null),
  ('00000000-0000-4000-8000-000000000006', 'fixture-deleted@example.test', timezone('utc', now())),
  ('00000000-0000-4000-8000-000000000007', 'fixture-subscriber@example.test', null);

insert into auth.identities (user_id, provider, provider_id) values
  ('00000000-0000-4000-8000-000000000001', 'apple', 'fixture-apple'),
  ('00000000-0000-4000-8000-000000000002', 'google', 'fixture-google-1'),
  ('00000000-0000-4000-8000-000000000003', 'google', 'fixture-google-2'),
  ('00000000-0000-4000-8000-000000000004', 'apple', 'fixture-ordinary'),
  ('00000000-0000-4000-8000-000000000005', 'apple', 'fixture-reviewer'),
  ('00000000-0000-4000-8000-000000000006', 'google', 'fixture-deleted'),
  ('00000000-0000-4000-8000-000000000007', 'apple', 'fixture-subscriber');

insert into public.kpi_excluded_users (provider, provider_id, reason) values
  ('apple', 'fixture-apple', 'president_apple'),
  ('google', 'fixture-google-1', 'president_google_one'),
  ('google', 'fixture-deleted', 'president_dead');
insert into public.kpi_excluded_users (email, reason) values
  ('fixture-google-two@example.test', 'president_email'),
  ('fixture-deleted@example.test', 'president_deleted_email');
insert into public.kpi_excluded_users (user_id, reason) values
  ('00000000-0000-4000-8000-000000000006', 'president_old');
insert into public.kpi_excluded_users (provider, provider_id, reason) values
  ('apple', 'fixture-reviewer', 'app_review_reviewer');

insert into public.calonavi_plus_entitlements (user_id, product_id, status, expires_at) values
  ('00000000-0000-4000-8000-000000000007', 'calonavi_plus_monthly', 'active', timezone('utc', now()) + interval '30 days');

insert into public.store_server_notifications (notification_uuid, notification_type) values
  ('00000000-0000-4000-8000-000000000099', 'SUBSCRIBED');

\ir ../manual/complimentary_plus_president_grants.sql

do $$
declare
  grants_n integer;
  kpi_n integer;
  entitlement_n integer;
  notice_n integer;
  answer boolean;
begin
  select count(*) into grants_n from public.calonavi_plus_complimentary_grants;
  if grants_n <> 3 then
    raise exception 'expected 3 grants, got %', grants_n;
  end if;
  if not exists (
    select 1 from public.calonavi_plus_complimentary_grants
    where provider = 'apple' and provider_id = 'fixture-apple'
  ) or not exists (
    select 1 from public.calonavi_plus_complimentary_grants
    where provider = 'google' and provider_id = 'fixture-google-1'
  ) or not exists (
    select 1 from public.calonavi_plus_complimentary_grants
    where provider = 'google' and provider_id = 'fixture-google-2'
  ) then
    raise exception 'the three president logins were not granted';
  end if;
  if exists (
    select 1 from public.calonavi_plus_complimentary_grants
    where provider_id in ('fixture-reviewer', 'fixture-deleted', 'fixture-ordinary', 'fixture-subscriber')
  ) then
    raise exception 'a non-president login was granted';
  end if;

  select count(*) into kpi_n from public.kpi_excluded_users;
  if kpi_n <> 7 then
    raise exception 'kpi exclusion rows changed: %', kpi_n;
  end if;

  if public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000001') is not true
    or public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000002') is not true
    or public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000003') is not true
  then
    raise exception 'a president login was not plus';
  end if;
  if public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000004')
    or public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000005')
    or public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000006')
    or public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000007')
    or public.user_has_complimentary_plus(null)
  then
    raise exception 'someone other than the three logins was plus';
  end if;

  select count(*) into entitlement_n from public.calonavi_plus_entitlements;
  select count(*) into notice_n from public.store_server_notifications;
  if entitlement_n <> 1 or notice_n <> 1 then
    raise exception 'billing rows changed: entitlements %, notices %', entitlement_n, notice_n;
  end if;
  if not exists (
    select 1 from public.calonavi_plus_entitlements
    where user_id = '00000000-0000-4000-8000-000000000007'
      and product_id = 'calonavi_plus_monthly'
      and status = 'active'
  ) then
    raise exception 'the real subscription row was rewritten';
  end if;
end
$$;

-- 同じ手順をもう一度流しても3行のまま。
\ir ../manual/complimentary_plus_president_grants.sql

do $$
declare
  grants_n integer;
begin
  select count(*) into grants_n from public.calonavi_plus_complimentary_grants;
  if grants_n <> 3 then
    raise exception 'second apply changed the grant count: %', grants_n;
  end if;
end
$$;

do $$
declare
  answer boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000003', true);
  execute 'set local role authenticated';
  select public.current_complimentary_plus() into answer;
  if answer is not true then
    raise exception 'the signed-in president was not plus';
  end if;
end
$$;

do $$
declare
  answer boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
  execute 'set local role authenticated';
  select public.current_complimentary_plus() into answer;
  if answer is not false then
    raise exception 'a paying account without a grant was complimentary';
  end if;
end
$$;

do $$
declare
  answer boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000004', true);
  execute 'set local role authenticated';
  select public.current_complimentary_plus() into answer;
  if answer is not false then
    raise exception 'an ordinary account was complimentary';
  end if;
end
$$;

do $$
begin
  begin
    execute 'set local role authenticated';
    execute 'select 1 from public.calonavi_plus_complimentary_grants';
    raise exception 'authenticated could read the grant table';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

do $$
begin
  begin
    execute 'set local role anon';
    perform public.current_complimentary_plus();
    raise exception 'anon could call current_complimentary_plus';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

do $$
begin
  begin
    execute 'set local role authenticated';
    perform public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000001');
    raise exception 'authenticated could call user_has_complimentary_plus';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

do $$
declare
  answer boolean;
begin
  execute 'set local role service_role';
  select public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000001') into answer;
  if answer is not true then
    raise exception 'service_role could not see a grant';
  end if;
  select public.user_has_complimentary_plus('00000000-0000-4000-8000-000000000004') into answer;
  if answer is not false then
    raise exception 'service_role marked an ordinary account plus';
  end if;
end
$$;
