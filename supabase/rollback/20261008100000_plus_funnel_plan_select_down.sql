-- plan_select を plus_funnel_events の event から外す。
-- すでに plan_select の行があると、元の制約は付け直せない。

begin;

alter table public.plus_funnel_events
  drop constraint if exists plus_funnel_events_event_check;

alter table public.plus_funnel_events
  add constraint plus_funnel_events_event_check
  check (event in (
    'paywall_open',
    'purchase_tap',
    'purchase_success',
    'purchase_cancel',
    'purchase_failed',
    'restore_tap',
    'gate_shown',
    'gate_tap'
  ));

commit;
