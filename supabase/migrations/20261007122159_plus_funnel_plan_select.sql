-- plus_funnel_events にプラン選択を足す。列は増やさない。
-- 本番の制約定義は CHECK ((event = ANY (ARRAY[...]))) なので、
-- 定義文の `event in` では見つからない。名前で外す。
-- 購入系の product_id は monthly / half-year / yearly。
-- 本番には適用済み。このファイルは同じ手順の記録。

alter table public.plus_funnel_events drop constraint if exists plus_funnel_events_event_check;

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
