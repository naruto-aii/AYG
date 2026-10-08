-- 20261008200000 を戻す。アプリが自分の加入行を再び書けるようにする。
-- 本番の適用前なら、このファイルは流さない。

begin;

drop policy if exists calonavi_plus_entitlements_insert_own
  on public.calonavi_plus_entitlements;
create policy calonavi_plus_entitlements_insert_own
  on public.calonavi_plus_entitlements for insert
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

drop policy if exists calonavi_plus_entitlements_update_own
  on public.calonavi_plus_entitlements;
create policy calonavi_plus_entitlements_update_own
  on public.calonavi_plus_entitlements for update
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.calonavi_plus_entitlements from anon, authenticated;
grant select, insert, update on table public.calonavi_plus_entitlements
  to authenticated;

comment on table public.calonavi_plus_entitlements is
  'カロナビ+の購入状態。商品ID、期限、状態だけを残し、後から有効人数を集計する。レシート本文とトークンは置かない。広告には使わない。';

commit;
