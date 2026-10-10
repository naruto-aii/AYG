-- 返金・取り消しされた transactionId を残す。
-- 行の持ち主が違っても記録し、そのIDは二度と有料にしない。
-- 外すのは REFUND_REVERSED だけ。利用者からは見えない。
-- レシート本文は置かない。本番への適用は手動。2回実行しても失敗しない。

begin;

create table if not exists public.calonavi_plus_revoked_transactions (
  user_id uuid not null references public.users (id) on delete cascade,
  product_id text not null
    check (product_id in (
      'calonavi_plus_monthly',
      'calonavi_plus_half_year',
      'calonavi_plus_yearly'
    )),
  transaction_id text not null
    check (
      char_length(transaction_id) > 0
      and char_length(transaction_id) <= 128
    ),
  revoked_at timestamptz not null,
  reason text not null
    check (reason in ('refund', 'revoke')),
  primary key (user_id, product_id, transaction_id)
);

comment on table public.calonavi_plus_revoked_transactions is
  '返金・取り消しされた StoreKit の transactionId。このIDは有料に戻さない。外すのは REFUND_REVERSED だけ。アプリは読まない。広告には使わない。';
comment on column public.calonavi_plus_revoked_transactions.transaction_id is
  '返金または取り消しされた transactionId。originalTransactionId ではない。';
comment on column public.calonavi_plus_revoked_transactions.reason is
  'refund は返金、revoke は取り消し。';

alter table public.calonavi_plus_revoked_transactions enable row level security;

revoke all on table public.calonavi_plus_revoked_transactions from public, anon, authenticated;
grant select, insert, update, delete on table public.calonavi_plus_revoked_transactions to service_role;

create or replace function public.remember_revoked_store_transaction(
  p_user_id uuid,
  p_product_id text,
  p_transaction_id text,
  p_reason text,
  p_revoked_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_transaction_id text := btrim(p_transaction_id);
begin
  if p_user_id is null or p_product_id is null or p_reason is null or p_revoked_at is null then
    return false;
  end if;
  if p_product_id not in (
    'calonavi_plus_monthly',
    'calonavi_plus_half_year',
    'calonavi_plus_yearly'
  ) then
    return false;
  end if;
  if p_reason not in ('refund', 'revoke') then
    return false;
  end if;
  if v_transaction_id is null
    or char_length(v_transaction_id) = 0
    or char_length(v_transaction_id) > 128
  then
    return false;
  end if;
  insert into public.calonavi_plus_revoked_transactions (
    user_id,
    product_id,
    transaction_id,
    revoked_at,
    reason
  )
  values (
    p_user_id,
    p_product_id,
    v_transaction_id,
    p_revoked_at,
    p_reason
  )
  on conflict (user_id, product_id, transaction_id) do update
  set revoked_at = excluded.revoked_at,
      reason = excluded.reason;
  return true;
end;
$function$;

comment on function public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz) is
  '返金・取り消しされた transactionId を記録する。加入の行と一致しなくても記録する。同じIDをもう一度記録しても失敗しない。';

create or replace function public.forget_revoked_store_transaction(
  p_user_id uuid,
  p_product_id text,
  p_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_transaction_id text := btrim(p_transaction_id);
begin
  if p_user_id is null or p_product_id is null then
    return false;
  end if;
  if v_transaction_id is null
    or char_length(v_transaction_id) = 0
    or char_length(v_transaction_id) > 128
  then
    return false;
  end if;
  delete from public.calonavi_plus_revoked_transactions
  where user_id = p_user_id
    and product_id = p_product_id
    and transaction_id = v_transaction_id;
  return true;
end;
$function$;

comment on function public.forget_revoked_store_transaction(uuid, text, text) is
  'REFUND_REVERSED のときだけ、返金済み transactionId の記録を外す。';

create or replace function public.store_transaction_revoked(
  p_user_id uuid,
  p_product_id text,
  p_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_transaction_id text := btrim(p_transaction_id);
begin
  if p_user_id is null or p_product_id is null then
    return false;
  end if;
  if v_transaction_id is null
    or char_length(v_transaction_id) = 0
    or char_length(v_transaction_id) > 128
  then
    return false;
  end if;
  return exists (
    select 1
    from public.calonavi_plus_revoked_transactions
    where user_id = p_user_id
      and product_id = p_product_id
      and transaction_id = v_transaction_id
  );
end;
$function$;

comment on function public.store_transaction_revoked(uuid, text, text) is
  'その transactionId が返金・取り消し済みなら true。有料には戻さない。';

revoke all on function public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.forget_revoked_store_transaction(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.store_transaction_revoked(uuid, text, text)
  from public, anon, authenticated;

grant execute on function public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)
  to service_role;
grant execute on function public.forget_revoked_store_transaction(uuid, text, text)
  to service_role;
grant execute on function public.store_transaction_revoked(uuid, text, text)
  to service_role;

commit;
