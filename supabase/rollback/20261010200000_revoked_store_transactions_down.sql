-- 返金済み取引の記録を外す。加入の行自体は残す。
-- 先に verify-store-transaction と app-store-notifications を、この関数を呼ばない版へ戻す。
-- 2回実行しても失敗しない。

begin;

revoke all on function public.store_transaction_revoked(uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.forget_revoked_store_transaction(uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz)
  from public, anon, authenticated, service_role;

drop function if exists public.store_transaction_revoked(uuid, text, text);
drop function if exists public.forget_revoked_store_transaction(uuid, text, text);
drop function if exists public.remember_revoked_store_transaction(uuid, text, text, text, timestamptz);

drop table if exists public.calonavi_plus_revoked_transactions;

commit;
