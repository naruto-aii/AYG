-- 端末にだけ残っている利用記録を、用途別の表へ足す。
-- 既存の行は削除しない。列も消さない。truncate しない。
-- 新しい表は、本人がアカウントを消したときにだけ、その本人の行を消す。
-- ヘルスケアの測定値は入れない。advertising_use は false 以外を拒否する。
-- レシート本文、検証データ、購入トークンは列にしない。

begin;

create table if not exists public.calonavi_plus_entitlements (
  user_id uuid not null references public.users (id) on delete cascade,
  product_id text not null
    check (product_id in ('calonavi_plus_monthly', 'calonavi_plus_yearly')),
  expires_at timestamptz,
  status text not null
    check (status in ('active', 'expired', 'inactive')),
  advertising_use boolean not null default false
    check (advertising_use = false),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, product_id),
  constraint calonavi_plus_entitlements_expiry_check check (
    status = 'inactive' or expires_at is not null
  )
);

comment on table public.calonavi_plus_entitlements is
  'カロナビ+の購入状態。商品ID、期限、状態だけを残し、後から有効人数を集計する。レシート本文とトークンは置かない。広告には使わない。';
comment on column public.calonavi_plus_entitlements.product_id is
  'App Store の商品ID。calonavi_plus_monthly または calonavi_plus_yearly。';
comment on column public.calonavi_plus_entitlements.expires_at is
  'その商品の期限。ストアが期限を返したときだけ入る。';
comment on column public.calonavi_plus_entitlements.status is
  'active は期限内、expired は期限切れ、inactive は取り消しまたはストアから消えた状態。';
comment on column public.calonavi_plus_entitlements.advertising_use is
  '常に false。広告利用の印は付けられない。';

create index if not exists calonavi_plus_entitlements_status_expires_idx
  on public.calonavi_plus_entitlements (status, expires_at);

drop trigger if exists set_calonavi_plus_entitlements_updated_at
  on public.calonavi_plus_entitlements;
create trigger set_calonavi_plus_entitlements_updated_at
  before update on public.calonavi_plus_entitlements
  for each row execute function public.set_updated_at();

alter table public.calonavi_plus_entitlements enable row level security;

drop policy if exists calonavi_plus_entitlements_select_own
  on public.calonavi_plus_entitlements;
create policy calonavi_plus_entitlements_select_own
  on public.calonavi_plus_entitlements for select
  using ((select auth.uid()) = user_id);

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

create table if not exists public.food_search_queries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  source text not null
    check (source in (
      'official_food',
      'public_food',
      'saved_food',
      'meal_template'
    )),
  query_text text not null
    check (char_length(query_text) between 1 and 256),
  searched_at timestamptz not null default timezone('utc', now()),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.food_search_queries is
  '食品を探すために、今の検索が受け取った語。公式食品、公開食品、マイ食品、食事テンプレート。ヘルスケアの測定値は入れない。広告には使わない。';
comment on column public.food_search_queries.source is
  'official_food / public_food / saved_food / meal_template のどれか。';
comment on column public.food_search_queries.query_text is
  '検索に渡した語。結果の栄養値は入れない。';

create index if not exists food_search_queries_user_searched_idx
  on public.food_search_queries (user_id, searched_at desc);
create index if not exists food_search_queries_source_searched_idx
  on public.food_search_queries (source, searched_at desc);

alter table public.food_search_queries enable row level security;

drop policy if exists food_search_queries_select_own
  on public.food_search_queries;
create policy food_search_queries_select_own
  on public.food_search_queries for select
  using ((select auth.uid()) = user_id);

drop policy if exists food_search_queries_insert_own
  on public.food_search_queries;
create policy food_search_queries_insert_own
  on public.food_search_queries for insert
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.food_search_queries from anon, authenticated;
grant select, insert on table public.food_search_queries to authenticated;

create table if not exists public.exercise_search_queries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  source text not null
    check (source in ('exercise_catalog', 'workout_template')),
  query_text text not null
    check (char_length(query_text) between 1 and 256),
  searched_at timestamptz not null default timezone('utc', now()),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.exercise_search_queries is
  '運動種目を探すために、今の検索が受け取った語。種目カタログと運動テンプレート。HealthKit の測定値や消費カロリーは入れない。広告には使わない。';
comment on column public.exercise_search_queries.source is
  'exercise_catalog または workout_template。';
comment on column public.exercise_search_queries.query_text is
  '検索欄に入った種目名。体重やカロリーは入れない。';

create index if not exists exercise_search_queries_user_searched_idx
  on public.exercise_search_queries (user_id, searched_at desc);
create index if not exists exercise_search_queries_source_searched_idx
  on public.exercise_search_queries (source, searched_at desc);

alter table public.exercise_search_queries enable row level security;

drop policy if exists exercise_search_queries_select_own
  on public.exercise_search_queries;
create policy exercise_search_queries_select_own
  on public.exercise_search_queries for select
  using ((select auth.uid()) = user_id);

drop policy if exists exercise_search_queries_insert_own
  on public.exercise_search_queries;
create policy exercise_search_queries_insert_own
  on public.exercise_search_queries for insert
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.exercise_search_queries from anon, authenticated;
grant select, insert on table public.exercise_search_queries to authenticated;

create table if not exists public.app_screen_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  screen text not null
    check (screen in (
      'home',
      'food',
      'workout',
      'weight',
      'settings',
      'first_meal_guide',
      'home_widget',
      'lock_screen'
    )),
  action text not null
    check (action in ('open', 'select', 'meal_button')),
  acted_at timestamptz not null default timezone('utc', now()),
  advertising_use boolean not null default false
    check (advertising_use = false),
  constraint app_screen_actions_pair_check check (
    (
      screen in ('home_widget', 'lock_screen')
      and action = 'meal_button'
    )
    or (
      screen in ('home', 'food', 'workout', 'weight', 'settings')
      and action in ('open', 'select')
    )
    or (screen = 'first_meal_guide' and action = 'open')
  )
);

comment on table public.app_screen_actions is
  '今の画面操作。タブの表示と選択、初回の食事案内、ホームウィジェットとロック画面のボタン。画面名と操作だけ。体重、消費カロリー、ヘルスケアの数値は入れない。広告には使わない。';
comment on column public.app_screen_actions.screen is
  'home / food / workout / weight / settings / first_meal_guide / home_widget / lock_screen。';
comment on column public.app_screen_actions.action is
  'open は表示、select はタブ選択、meal_button はウィジェットのボタン。';

create index if not exists app_screen_actions_user_acted_idx
  on public.app_screen_actions (user_id, acted_at desc);
create index if not exists app_screen_actions_screen_acted_idx
  on public.app_screen_actions (screen, acted_at desc);

alter table public.app_screen_actions enable row level security;

drop policy if exists app_screen_actions_select_own
  on public.app_screen_actions;
create policy app_screen_actions_select_own
  on public.app_screen_actions for select
  using ((select auth.uid()) = user_id);

drop policy if exists app_screen_actions_insert_own
  on public.app_screen_actions;
create policy app_screen_actions_insert_own
  on public.app_screen_actions for insert
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.app_screen_actions from anon, authenticated;
grant select, insert on table public.app_screen_actions to authenticated;

-- アカウント削除のとき、上の4表にある本人の行も消す。
-- それ以外の削除は、これまでの delete_own_account と同じ。
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

  -- Prevent the same Google/Apple identity from signing back into this row.
  -- Public foods stay attached to this anonymized user id.
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
