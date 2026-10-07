-- plus_funnel_events にプラン選択を足す。列は増やさない。
-- 購入系の product_id は monthly / half-year / yearly。
-- このエージェントからは本番に適用しない。

begin;

do $$
declare
  cons name;
begin
  for cons in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'plus_funnel_events'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%event in%'
  loop
    execute format(
      'alter table public.plus_funnel_events drop constraint %I',
      cons
    );
  end loop;
end
$$;

alter table public.plus_funnel_events
  add constraint plus_funnel_events_event_check
  check (event in (
    'paywall_open',
    'plan_select',
    'purchase_tap',
    'purchase_success',
    'purchase_cancel',
    'purchase_failed',
    'restore_tap',
    'gate_shown',
    'gate_tap'
  ));

commit;
