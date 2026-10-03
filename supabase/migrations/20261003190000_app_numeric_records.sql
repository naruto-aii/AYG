-- アプリがすでに持っている数字だけを足す。
-- Health ワークアウトの開始、終了、消費カロリー。食事記録の保存食品バージョン。
-- 既存の行は削除しない。列の中身も書き換えない。truncate しない。
-- 歩数、レシート本文、購入トークンは列にしない。
-- ヘルスケアの数値は advertising_use = false 以外を拒否する。
-- このファイルをこのエージェントから本番へは適用しない。

begin;

alter table public.food_entries
  add column if not exists source_saved_food_version integer;

alter table public.food_entries
  drop constraint if exists food_entries_source_saved_food_version_check;

alter table public.food_entries
  add constraint food_entries_source_saved_food_version_check
  check (
    source_saved_food_version is null
    or source_saved_food_version >= 0
  );

comment on column public.food_entries.source_saved_food_version is
  '食事を記録したとき、アプリが保存食品から受け取った version。無いときは NULL。既存の食事行は消さない。';

create table if not exists public.health_workouts (
  user_id uuid not null references public.users (id) on delete cascade,
  workout_id text not null
    check (char_length(workout_id) between 1 and 128),
  activity_type text not null
    check (char_length(activity_type) between 1 and 128),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  calories_burned double precision,
  advertising_use boolean not null default false
    check (advertising_use = false),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, workout_id),
  constraint health_workouts_time_check check (ended_at >= started_at),
  constraint health_workouts_calories_check check (
    calories_burned is null or calories_burned >= 0
  )
);

comment on table public.health_workouts is
  'Health が返したワークアウト。種目、開始、終了、消費カロリーだけ。歩数と距離は入れない。使い道はアプリの機能と分析。広告には使わない。';
comment on column public.health_workouts.calories_burned is
  'Health が返した消費カロリー。返さないときは NULL。0 にはしない。';
comment on column public.health_workouts.advertising_use is
  '常に false。ヘルスケア由来の数値に広告利用の印は付けられない。';

create index if not exists health_workouts_user_started_idx
  on public.health_workouts (user_id, started_at desc);

drop trigger if exists set_health_workouts_updated_at
  on public.health_workouts;
create trigger set_health_workouts_updated_at
  before update on public.health_workouts
  for each row execute function public.set_updated_at();

alter table public.health_workouts enable row level security;

drop policy if exists health_workouts_select_own on public.health_workouts;
create policy health_workouts_select_own
  on public.health_workouts for select
  using ((select auth.uid()) = user_id);

drop policy if exists health_workouts_insert_own on public.health_workouts;
create policy health_workouts_insert_own
  on public.health_workouts for insert
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

drop policy if exists health_workouts_update_own on public.health_workouts;
create policy health_workouts_update_own
  on public.health_workouts for update
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.health_workouts from anon, authenticated;
grant select, insert, update on table public.health_workouts to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select on table public.health_workouts to service_role;
  end if;
end
$$;

-- アカウント削除のとき、本人のワークアウトも消す。
-- 食事、体重、プロフィールの行の消し方はこれまでの delete_own_account と同じ。
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

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

revoke all on function public.delete_own_account() from public;
revoke all on function public.delete_own_account() from anon;
revoke all on function public.delete_own_account() from authenticated;
grant execute on function public.delete_own_account() to authenticated;

commit;
