-- entitlement_observed は端末の自己申告。ここで購入の持ち主を決めると、
-- Apple の署名が通る前に originalTransactionId が1アカウントへ固定される。
-- 持ち主は verify-store-transaction が署名を確かめたときだけ書く。
-- 加入の行が一度も無い対応は、その自己申告なので外す。検証済みの加入は残す。
-- 本番への適用は手動。2回実行しても失敗しない。

begin;

create or replace function public.app_events_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  return new;
end;
$function$;

comment on function public.app_events_before_insert() is
  'app_events の挿入前。購入の対応表は書かない。持ち主は verify-store-transaction だけが決める。';

delete from public.store_original_transactions t
where not exists (
  select 1
  from public.calonavi_plus_entitlements e
  where e.user_id = t.user_id
);

commit;
