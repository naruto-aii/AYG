-- pgTAP: カロナビ+は、読み取った行と一致するときだけ更新する。
-- ローカルの Postgres だけ。本番には繋がない。
-- 先にマイグレーションを流す。

begin;

create extension if not exists pgtap;

select plan(14);

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

-- 列を足す前の行。取引IDは埋め戻さない。期待するIDが null のときだけ更新する。
insert into public.calonavi_plus_entitlements (
  user_id,
  product_id,
  expires_at,
  status,
  advertising_use
)
values (
  '11111111-1111-4111-8111-111111111111',
  'calonavi_plus_yearly',
  '2027-10-08T00:00:00Z',
  'active',
  false
);

select ok(
  (
    select source_transaction_id is null
    from public.calonavi_plus_entitlements
    where user_id = '11111111-1111-4111-8111-111111111111'
      and product_id = 'calonavi_plus_yearly'
  ),
  'a legacy row keeps a null transaction id'
);

select ok(
  not public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_yearly',
    '2026-10-08T00:00:00Z',
    'inactive',
    'tx-guess',
    true,
    '2027-10-08T00:00:00Z',
    'active',
    'tx-guess'
  ),
  'a guessed transaction id does not update a legacy row'
);

select ok(
  public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_yearly',
    '2027-10-08T00:00:00Z',
    'active',
    'tx-year',
    true,
    '2027-10-08T00:00:00+00',
    'active',
    null
  ),
  'a legacy row updates when the snapshot matches across timestamp spellings'
);

select ok(
  (
    select column_default is null
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'calonavi_plus_entitlements'
      and column_name = 'source_transaction_id'
  ),
  'the transaction id column has no default and does not backfill'
);

select ok(
  not public.save_plus_entitlement(
    '11111111-1111-4111-8111-111111111111',
    'calonavi_plus_monthly',
    '2026-12-01T00:00:00Z',
    'inactive',
    '',
    true,
    '2026-12-01T00:00:00Z',
    'inactive',
    'tx-renewal'
  ),
  'an empty transaction id is rejected'
);

select * from finish();
rollback;
