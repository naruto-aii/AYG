-- pgTAP: カロナビ+は、読み取った行と一致するときだけ更新する。
-- ローカルの Postgres だけ。本番には繋がない。
-- 先にマイグレーションを流す。

begin;

create extension if not exists pgtap;

select plan(9);

insert into auth.users (id, email)
values ('11111111-1111-4111-8111-111111111111', 'plus-source@example.test')
on conflict (id) do nothing;

insert into public.users (id, email)
values ('11111111-1111-4111-8111-111111111111', 'plus-source@example.test')
on conflict (id) do nothing;

delete from public.calonavi_plus_entitlements
where user_id = '11111111-1111-4111-8111-111111111111'
  and product_id = 'calonavi_plus_monthly';

select ok(
  public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-11-08T00:00:00Z',
    'active',
    'tx-current',
    false,
    null,
    null,
    null
  ),
  'the first insert writes the paid period'
);

select ok(
  not public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-12-01T00:00:00Z',
    'active',
    'tx-renewal',
    false,
    null,
    null,
    null
  ),
  'a second insert loses the race and does not overwrite'
);

select ok(
  public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-12-01T00:00:00Z',
    'active',
    'tx-renewal',
    true,
    '2026-11-08T00:00:00Z',
    'active',
    'tx-current'
  ),
  'a renewal replaces the row when the snapshot still matches'
);

select ok(
  not public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-11-08T00:00:00Z',
    'expired',
    'tx-current',
    true,
    '2026-11-08T00:00:00Z',
    'active',
    'tx-current'
  ),
  'a stale expiry notice does not wipe the renewal'
);

select ok(
  exists (
    select 1
    from public.calonavi_plus_entitlements
    where user_id = '11111111-1111-4111-8111-111111111111'
      and product_id = 'calonavi_plus_monthly'
      and status = 'active'
      and source_transaction_id = 'tx-renewal'
      and expires_at = '2026-12-01T00:00:00Z'::timestamptz
  ),
  'the renewal remains after the stale write'
);

select ok(
  public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-12-01T00:00:00Z',
    'inactive',
    'tx-renewal',
    true,
    '2026-12-01T00:00:00Z',
    'active',
    'tx-renewal'
  ),
  'the same transaction can still be refunded'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)',
    'execute'
  ),
  'service_role can write entitlements'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)',
    'execute'
  ),
  'anon cannot write entitlements'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)',
    'execute'
  ),
  'authenticated cannot write entitlements'
);

select * from finish();
rollback;
