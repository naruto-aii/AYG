-- カロナビ+の行に、その期限を書いた取引IDを残す。
-- 同じ transactionId の返金・失効・アップグレードだけが、猶予で延ばした期限を上書きする。
-- 別の取引の古い期限では消さない。レシート本文は置かない。
-- 書くときは save_plus_entitlement が、読み取った行と一致するときだけ更新する。
-- 本番への適用は手動。2回実行しても失敗しない。

begin;

alter table public.calonavi_plus_entitlements
  add column if not exists source_transaction_id text;

alter table public.calonavi_plus_entitlements
  drop constraint if exists calonavi_plus_entitlements_source_transaction_id_check;

alter table public.calonavi_plus_entitlements
  add constraint calonavi_plus_entitlements_source_transaction_id_check
  check (
    source_transaction_id is null
    or (
      char_length(source_transaction_id) > 0
      and char_length(source_transaction_id) <= 128
    )
  );

comment on column public.calonavi_plus_entitlements.source_transaction_id is
  'この期限を書いた StoreKit の transactionId。originalTransactionId ではない。同じ取引の返金・失効・アップグレードは上書きし、別の取引の古い期限では消さない。レシート本文は置かない。';

create or replace function public.save_plus_entitlement(
  p_user_id uuid,
  p_product_id text,
  p_expires_at timestamptz,
  p_status text,
  p_source_transaction_id text,
  p_expect_row boolean,
  p_expected_expires_at timestamptz,
  p_expected_status text,
  p_expected_source_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  updated_rows integer;
begin
  if p_user_id is null or p_product_id is null or p_status is null then
    return false;
  end if;
  if char_length(p_product_id) > 128 then
    return false;
  end if;
  if p_source_transaction_id is not null and (
    char_length(btrim(p_source_transaction_id)) = 0
    or char_length(p_source_transaction_id) > 128
  ) then
    return false;
  end if;
  if p_expect_row then
    update public.calonavi_plus_entitlements
    set expires_at = p_expires_at,
        status = p_status,
        advertising_use = false,
        source_transaction_id = p_source_transaction_id
    where user_id = p_user_id
      and product_id = p_product_id
      and expires_at is not distinct from p_expected_expires_at
      and status = p_expected_status
      and source_transaction_id is not distinct from p_expected_source_transaction_id;
    get diagnostics updated_rows = row_count;
    return updated_rows > 0;
  end if;
  insert into public.calonavi_plus_entitlements (
    user_id,
    product_id,
    expires_at,
    status,
    advertising_use,
    source_transaction_id
  )
  values (
    p_user_id,
    p_product_id,
    p_expires_at,
    p_status,
    false,
    p_source_transaction_id
  );
  return true;
exception
  when unique_violation then
    return false;
end;
$function$;

comment on function public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text) is
  'カロナビ+を1行書く。行が無いときは挿入し、あるときは読み取った期限・状態・取引IDと一致するときだけ更新する。判定は Edge Function の skipsOlderEntitlement が行う。';

revoke all on function public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)
  from public, anon, authenticated;
grant execute on function public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)
  to service_role;

commit;
