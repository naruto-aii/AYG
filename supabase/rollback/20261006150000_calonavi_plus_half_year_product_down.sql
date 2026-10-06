-- 半年プランの商品IDだけを戻す。
-- 月額・年額・実機テストの加入行は残す。表も RLS も消さない。
-- 2回実行しても失敗しない。

begin;

delete from public.calonavi_plus_entitlements
where product_id = 'calonavi_plus_half_year';

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'calonavi_plus_entitlements'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%calonavi_plus_monthly%'
  loop
    execute format(
      'alter table public.calonavi_plus_entitlements drop constraint %I',
      constraint_name
    );
  end loop;
end $$;

alter table public.calonavi_plus_entitlements
  drop constraint if exists calonavi_plus_entitlements_product_id_check;

alter table public.calonavi_plus_entitlements
  add constraint calonavi_plus_entitlements_product_id_check
  check (
    product_id in (
      'calonavi_plus_monthly',
      'calonavi_plus_yearly',
      'calonavi_plus_test'
    )
  );

comment on column public.calonavi_plus_entitlements.product_id is
  'App Store の商品ID（calonavi_plus_monthly / calonavi_plus_yearly）か、実機テスト用の calonavi_plus_test。';

commit;
