-- pgTAP: 初回設定より前の同意。
-- ローカルの Postgres だけ。本番には繋がない。
-- 先にマイグレーションを流し、その前に ai_data_consent_before_profile_seed.sql を流す。

begin;

create extension if not exists pgtap;

select plan(17);

select ok(
  exists (
    select 1
    from public.ai_data_consents
    where user_id = '11111111-1111-4111-8111-111111111111'
      and policy_version = '2026-10-08'
  ),
  '既存の同意行は参照先を変えたあとも残る'
);

select is(
  (
    select email
    from public.users
    where id = '11111111-1111-4111-8111-111111111111'
  ),
  'legacy@example.test',
  '既存の public.users.email は変わらない'
);

select ok(
  (
    select deleted_at is null
    from public.users
    where id = '11111111-1111-4111-8111-111111111111'
  ),
  '既存の public.users は退会扱いにならない'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class rel on rel.oid = c.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    join pg_class ref on ref.oid = c.confrelid
    join pg_namespace refn on refn.oid = ref.relnamespace
    where c.conname = 'ai_data_consents_user_id_fkey'
      and nsp.nspname = 'public'
      and rel.relname = 'ai_data_consents'
      and refn.nspname = 'auth'
      and ref.relname = 'users'
      and c.confdeltype = 'c'
  ),
  'user_id は auth.users を on delete cascade で参照する'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgname = 'delete_ai_data_consent_on_account_close'
      and not tgisinternal
  ),
  '退会時に同意を消すトリガーは残す'
);

insert into auth.users (id, email)
values ('22222222-2222-4222-8222-222222222222', 'fresh@example.test');

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

insert into public.ai_data_consents (user_id, policy_version)
values ('22222222-2222-4222-8222-222222222222', '2026-10-10')
on conflict (user_id) do update
set policy_version = excluded.policy_version;

reset role;

select ok(
  exists (
    select 1
    from public.ai_data_consents
    where user_id = '22222222-2222-4222-8222-222222222222'
      and policy_version = '2026-10-10'
  ),
  'public.users が無い新規アカウントでも同意を保存できる'
);

select is(
  (
    select count(*)
    from public.users
    where id = '22222222-2222-4222-8222-222222222222'
  ),
  0::bigint,
  '同意では public.users を作らない'
);

select is(
  (
    select count(*)
    from public.app_settings
    where user_id = '22222222-2222-4222-8222-222222222222'
  ),
  0::bigint,
  '同意では app_settings を作らず、初回設定は未完了のまま'
);

insert into auth.users (id, email)
values ('44444444-4444-4444-8444-444444444444', 'kept@example.test');

insert into public.users (id, email)
values ('44444444-4444-4444-8444-444444444444', 'kept@example.test');

insert into public.app_settings (user_id, onboarding_complete)
values ('44444444-4444-4444-8444-444444444444', true);

select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
set local role authenticated;

insert into public.ai_data_consents (user_id, policy_version)
values ('44444444-4444-4444-8444-444444444444', '2026-10-08')
on conflict (user_id) do update
set policy_version = excluded.policy_version;

insert into public.ai_data_consents (user_id, policy_version)
values ('44444444-4444-4444-8444-444444444444', '2026-10-10')
on conflict (user_id) do update
set policy_version = excluded.policy_version;

reset role;

select is(
  (
    select count(*)
    from public.ai_data_consents
    where user_id = '44444444-4444-4444-8444-444444444444'
  ),
  1::bigint,
  '既存アカウントの同意は1行のまま上書きできる'
);

select is(
  (
    select policy_version
    from public.ai_data_consents
    where user_id = '44444444-4444-4444-8444-444444444444'
  ),
  '2026-10-10',
  '既存アカウントは今の版へ更新できる'
);

select is(
  (
    select email
    from public.users
    where id = '44444444-4444-4444-8444-444444444444'
  ),
  'kept@example.test',
  '同意の上書きは既存の email を変えない'
);

select ok(
  (
    select onboarding_complete
    from public.app_settings
    where user_id = '44444444-4444-4444-8444-444444444444'
  ),
  '同意の上書きは初回設定の完了を戻さない'
);

insert into auth.users (id, email)
values ('55555555-5555-4555-8555-555555555555', 'closing@example.test');

insert into public.users (id, email)
values ('55555555-5555-4555-8555-555555555555', 'closing@example.test');

insert into public.ai_data_consents (user_id, policy_version)
values ('55555555-5555-4555-8555-555555555555', '2026-10-10');

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '', true);

select lives_ok(
  $$select public.delete_own_account('55555555-5555-4555-8555-555555555555')$$,
  'delete_own_account は同意済みのアカウントを退会できる'
);

select ok(
  not exists (
    select 1
    from public.ai_data_consents
    where user_id = '55555555-5555-4555-8555-555555555555'
  ),
  '退会すると同意の行が消える'
);

select ok(
  (
    select deleted_at is not null
    from public.users
    where id = '55555555-5555-4555-8555-555555555555'
  ),
  '退会は public.users を消さず deleted_at を入れる'
);

select ok(
  exists (
    select 1
    from auth.users
    where id = '55555555-5555-4555-8555-555555555555'
  ),
  '退会は auth.users を消さない'
);

delete from auth.users
where id = '22222222-2222-4222-8222-222222222222';

select ok(
  not exists (
    select 1
    from public.ai_data_consents
    where user_id = '22222222-2222-4222-8222-222222222222'
  ),
  'auth.users を消すと、public.users が無くても同意の行が消える'
);

select * from finish();

rollback;
