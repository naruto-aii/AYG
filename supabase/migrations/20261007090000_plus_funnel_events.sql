-- カロナビ+の案内と購入の記録。売上の集計に使う。追加だけ。
-- レシート本文、検証データ、購入トークンは置かない。広告には使わない。
-- 本番には version 20261007090000 で適用済み。このエージェントからは適用しない。

begin;

create table if not exists public.plus_funnel_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.users (id) on delete cascade,
  event text not null
    check (event in (
      'paywall_open',
      'purchase_tap',
      'purchase_success',
      'purchase_cancel',
      'purchase_failed',
      'restore_tap',
      'gate_shown',
      'gate_tap'
    )),
  feature text
    check (feature is null or feature in (
      'meal_template_limit',
      'workout_template_limit',
      'recent_foods',
      'memo',
      'widget',
      'siri',
      'coach'
    )),
  product_id text,
  occurred_at timestamptz not null default timezone('utc', now()),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.plus_funnel_events is
  'カロナビ+の案内を開いた、押した、購入した、やめた、失敗した、復元した記録。広告には使わない。';

create index if not exists plus_funnel_events_user_occurred_idx
  on public.plus_funnel_events (user_id, occurred_at);

alter table public.plus_funnel_events enable row level security;

drop policy if exists plus_funnel_events_select_own
  on public.plus_funnel_events;
create policy plus_funnel_events_select_own
  on public.plus_funnel_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists plus_funnel_events_insert_own
  on public.plus_funnel_events;
create policy plus_funnel_events_insert_own
  on public.plus_funnel_events
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.plus_funnel_events from public, anon, authenticated;
grant select, insert on table public.plus_funnel_events to authenticated;

-- アカウント削除で、その本人の課金記録だけを消す。
create or replace function public.delete_own_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'not authenticated';
  end if;
  uid := p_user_id;

  delete from public.meal_template_items where user_id = uid;
  delete from public.meal_templates where user_id = uid;

  if to_regclass('public.workout_template_items') is not null then
    execute 'delete from public.workout_template_items where user_id = $1' using uid;
  end if;
  if to_regclass('public.workout_templates') is not null then
    execute 'delete from public.workout_templates where user_id = $1' using uid;
  end if;

  delete from public.food_ratings where rater_user_id = uid;
  delete from public.food_reports where reporter_user_id = uid;
  delete from public.blocked_food_creators
    where blocker_user_id = uid or blocked_user_id = uid;

  delete from public.saved_foods
    where user_id = uid
      and visibility is distinct from 'public';

  delete from public.food_entries where user_id = uid;
  delete from public.exercise_entries where user_id = uid;
  delete from public.weight_entries where user_id = uid;
  if to_regclass('public.alcohol_entries') is not null then
    execute 'delete from public.alcohol_entries where user_id = $1' using uid;
  end if;

  if to_regclass('public.health_workouts') is not null then
    execute 'delete from public.health_workouts where user_id = $1' using uid;
  end if;

  if to_regclass('public.calonavi_plus_entitlements') is not null then
    execute 'delete from public.calonavi_plus_entitlements where user_id = $1' using uid;
  end if;
  if to_regclass('public.food_search_queries') is not null then
    execute 'delete from public.food_search_queries where user_id = $1' using uid;
  end if;
  if to_regclass('public.exercise_search_queries') is not null then
    execute 'delete from public.exercise_search_queries where user_id = $1' using uid;
  end if;
  if to_regclass('public.app_screen_actions') is not null then
    execute 'delete from public.app_screen_actions where user_id = $1' using uid;
  end if;
  if to_regclass('public.coach_proposal_logs') is not null then
    execute 'delete from public.coach_proposal_logs where user_id = $1' using uid;
  end if;
  if to_regclass('public.plus_funnel_events') is not null then
    execute 'delete from public.plus_funnel_events where user_id = $1' using uid;
  end if;

  if to_regclass('internal.apple_refresh_tokens') is not null then
    delete from internal.apple_refresh_tokens where user_id = uid;
  end if;

  delete from public.health_snapshots where user_id = uid;
  delete from public.app_settings where user_id = uid;
  delete from public.nutrition_settings where user_id = uid;
  delete from public.goals where user_id = uid;
  delete from public.profiles where user_id = uid;
  delete from public.rate_limit_buckets where user_id = uid;

  update public.users
  set email = null,
      deleted_at = timezone('utc', now())
  where id = uid;

  begin
    delete from auth.identities where user_id = uid;
    update auth.users
    set email = 'deleted+' || uid::text || '@invalid.local',
        raw_user_meta_data = '{}'::jsonb
    where id = uid;
  exception
    when others then
      raise notice 'delete_own_account: skipped auth.users update: %', sqlerrm;
  end;
end;
$$;

revoke all on function public.delete_own_account(uuid) from public;
revoke all on function public.delete_own_account(uuid) from anon;
revoke all on function public.delete_own_account(uuid) from authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.delete_own_account(uuid) to service_role;
  end if;
end
$$;

commit;
