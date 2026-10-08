-- カロナビ+の加入は、検証済みの StoreKit 取引からサーバだけが書く。
-- アプリの authenticated は自分の行を読むだけ。INSERT / UPDATE / DELETE は渡さない。
-- 本番には適用しない。手順は supabase/functions/README.md。

begin;

drop policy if exists calonavi_plus_entitlements_insert_own
  on public.calonavi_plus_entitlements;

drop policy if exists calonavi_plus_entitlements_update_own
  on public.calonavi_plus_entitlements;

revoke all on table public.calonavi_plus_entitlements from anon, authenticated;
grant select on table public.calonavi_plus_entitlements to authenticated;

comment on table public.calonavi_plus_entitlements is
  'カロナビ+の購入状態。商品ID、期限、状態だけを残す。アプリは書かない。verify-store-transaction と App Store のサーバ通知が、検証済みの取引から service_role で書く。レシート本文は置かない。広告には使わない。';

commit;
