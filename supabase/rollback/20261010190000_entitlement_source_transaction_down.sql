-- 取引IDと、一致したときだけ書く関数を外す。加入の行自体は残す。
-- 2回実行しても失敗しない。

begin;

revoke all on function public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text)
  from public, anon, authenticated, service_role;
drop function if exists public.save_plus_entitlement(uuid, text, timestamptz, text, text, boolean, timestamptz, text, text);

alter table public.calonavi_plus_entitlements
  drop constraint if exists calonavi_plus_entitlements_source_transaction_id_check;

alter table public.calonavi_plus_entitlements
  drop column if exists source_transaction_id;

commit;
