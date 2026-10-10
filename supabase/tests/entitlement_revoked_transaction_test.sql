-- pgTAP: 返金・取り消しされた transactionId は利用者から見えない。
-- ローカルの Postgres だけ。本番には繋がない。
-- 先に 20261010092056_revoked_store_transactions.sql を流す。

begin;

create extension if not exists pgtap;

select plan(22);

insert into auth.users (id, email)
values ('33333333-3333-4333-8333-333333333333', 'plus-revoked@example.test')
on conflict (id) do nothing;

insert into public.users (id, email)
values ('33333333-3333-4333-8333-333333333333', 'plus-revoked@example.test')
on conflict (id) do nothing;

select ok(
  public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal',
    'refund',
    '2026-10-09T00:00:00Z'
  ),
  'a refunded transaction id is recorded without an entitlement row'
);

select ok(
  not exists (
    select 1
    from public.calonavi_plus_entitlements
    where user_id = '33333333-3333-4333-8333-333333333333'
  ),
  'recording a refund does not create an entitlement row'
);

select ok(
  public.store_transaction_revoked(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal'
  ),
  'the recorded transaction id is revoked'
);

select ok(
  public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    '  tx-renewal  ',
    'revoke',
    '2026-10-10T00:00:00Z'
  ),
  'remembering the same id again updates the row'
);

select ok(
  (
    select count(*) = 1
      and reason = 'revoke'
      and revoked_at = '2026-10-10T00:00:00Z'::timestamptz
    from public.calonavi_plus_revoked_transactions
    where user_id = '33333333-3333-4333-8333-333333333333'
      and product_id = 'calonavi_plus_monthly'
      and transaction_id = 'tx-renewal'
  ),
  'the same transaction id stays one row'
);

select ok(
  not public.store_transaction_revoked(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-next'
  ),
  'a different transaction id is not revoked'
);

select ok(
  not public.store_transaction_revoked(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_yearly',
    'tx-renewal'
  ),
  'the same id on another product is not revoked'
);

select ok(
  public.forget_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal'
  ),
  'a refund reversal removes the record'
);

select ok(
  not public.store_transaction_revoked(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal'
  ),
  'the forgotten transaction id can be granted again'
);

select ok(
  public.forget_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal'
  ),
  'forgetting an absent id still succeeds'
);

select ok(
  not public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    '   ',
    'refund',
    '2026-10-09T00:00:00Z'
  ),
  'an empty transaction id is rejected'
);

select ok(
  not public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    'tx-renewal',
    'other',
    '2026-10-09T00:00:00Z'
  ),
  'an unknown reason is rejected'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.forget_revoked_store_transaction(uuid, text, text)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.store_transaction_revoked(uuid, text, text)',
    'execute'
  ),
  'service_role can record and read revoked transaction ids'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.forget_revoked_store_transaction(uuid, text, text)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.forget_revoked_store_transaction(uuid, text, text)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.store_transaction_revoked(uuid, text, text)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.store_transaction_revoked(uuid, text, text)',
    'execute'
  ),
  'anon and authenticated cannot call the revoked-transaction functions'
);

select ok(
  not has_table_privilege('anon', 'public.calonavi_plus_revoked_transactions', 'select')
  and not has_table_privilege('authenticated', 'public.calonavi_plus_revoked_transactions', 'select')
  and not has_table_privilege('anon', 'public.calonavi_plus_revoked_transactions', 'insert')
  and not has_table_privilege('authenticated', 'public.calonavi_plus_revoked_transactions', 'insert'),
  'anon and authenticated cannot read or write the table'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.calonavi_plus_revoked_transactions'::regclass
  ),
  'row level security is enabled'
);

select ok(
  (
    select count(*) = 0
    from pg_policies
    where schemaname = 'public'
      and tablename = 'calonavi_plus_revoked_transactions'
  ),
  'users have no policies on revoked transactions'
);

select ok(
  not public.forget_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_monthly',
    ''
  ),
  'forgetting an empty transaction id is rejected'
);

select ok(
  (
    select count(*) = 4
    from pg_constraint
    where conrelid = 'public.calonavi_plus_revoked_transactions'::regclass
      and contype in ('c', 'p')
  ),
  'the table checks product, transaction id, reason, and the primary key'
);

select ok(
  public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_half_year',
    'tx-half',
    'refund',
    '2026-10-09T00:00:00Z'
  ),
  'a half-year refund is recorded'
);

select ok(
  public.store_transaction_revoked(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_half_year',
    'tx-half'
  ),
  'the half-year transaction id is revoked'
);

select ok(
  not public.remember_revoked_store_transaction(
    '33333333-3333-4333-8333-333333333333',
    'calonavi_plus_test',
    'tx-test',
    'refund',
    '2026-10-09T00:00:00Z'
  ),
  'a product outside Plus is rejected'
);

select * from finish();
rollback;
