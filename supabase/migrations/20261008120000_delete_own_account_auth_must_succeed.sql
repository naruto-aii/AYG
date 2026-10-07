-- 退会時に記録を匿名化して残す。user_id との対応表は作らない。
-- auth.identities / auth.users の削除に失敗したら例外にし、成功扱いにしない。
-- kpi.excluded_user_ids の退会集計の除外は 20261007112725 と同じ。
-- 開発者は anon_subjects.kpi_excluded を真にして、kpi.anon_* から外す。
-- 本番へは適用しない。提出者が確認してから流す。

begin;

create table public.anon_subjects (
  anon_subject_id uuid primary key,
  age_band text not null,
  gender text,
  goal_type text,
  height_cm double precision,
  weight_kg double precision,
  account_created_month date,
  plan_type text not null,
  kpi_excluded boolean not null,
  deleted_at_hour timestamptz not null
);
comment on table public.anon_subjects is
  '退会のたびに一度だけ作る匿名の主体。gen_random_uuid() で作り、user_id や email からは導出しない。対応表は残さない。';

create table public.anon_food_entries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  food_name text not null,
  kcal_per_unit double precision,
  protein_per_unit double precision,
  fat_per_unit double precision,
  carb_per_unit double precision,
  quantity double precision not null,
  logged_at_hour timestamptz not null,
  source_saved_food_version integer
);
create index anon_food_entries_subject_idx
  on public.anon_food_entries (anon_subject_id);

create table public.anon_exercise_entries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  activity_name text not null,
  duration_min integer not null,
  burned_kcal double precision not null,
  logged_at_hour timestamptz not null
);
create index anon_exercise_entries_subject_idx
  on public.anon_exercise_entries (anon_subject_id);

create table public.anon_weight_entries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  weight_kg double precision not null,
  source text not null,
  recorded_at_hour timestamptz not null
);
create index anon_weight_entries_subject_idx
  on public.anon_weight_entries (anon_subject_id);

create table public.anon_alcohol_entries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  beverage_name text not null,
  amount double precision not null,
  unit text not null,
  alcohol_percentage double precision not null,
  total_calories double precision not null,
  pure_alcohol_grams double precision not null,
  alcohol_calories double precision not null,
  consumed_at_hour timestamptz not null
);
create index anon_alcohol_entries_subject_idx
  on public.anon_alcohol_entries (anon_subject_id);

create table public.anon_health_workouts (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  activity_type text not null,
  started_at_hour timestamptz not null,
  ended_at_hour timestamptz not null,
  calories_burned double precision
);
create index anon_health_workouts_subject_idx
  on public.anon_health_workouts (anon_subject_id);

create table public.anon_meal_template_usage (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  use_count integer not null,
  last_used_at_hour timestamptz
);
create index anon_meal_template_usage_subject_idx
  on public.anon_meal_template_usage (anon_subject_id);

create table public.anon_workout_template_usage (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  use_count integer not null,
  last_used_at_hour timestamptz
);
create index anon_workout_template_usage_subject_idx
  on public.anon_workout_template_usage (anon_subject_id);

create table public.anon_food_search_queries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  source text not null,
  query_text text not null,
  searched_at_hour timestamptz not null
);
create index anon_food_search_queries_subject_idx
  on public.anon_food_search_queries (anon_subject_id);

create table public.anon_exercise_search_queries (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  source text not null,
  searched_at_hour timestamptz not null
);
create index anon_exercise_search_queries_subject_idx
  on public.anon_exercise_search_queries (anon_subject_id);

create table public.anon_screen_actions (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  screen text not null,
  action text not null,
  acted_at_hour timestamptz not null
);
create index anon_screen_actions_subject_idx
  on public.anon_screen_actions (anon_subject_id);

create table public.anon_app_events (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  event_name text not null,
  occurred_at_hour timestamptz not null,
  origin text not null,
  stream text not null,
  app_version text not null
);
create index anon_app_events_subject_idx
  on public.anon_app_events (anon_subject_id);

create table public.anon_coach_proposal_logs (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  registered boolean not null,
  recorded_at_hour timestamptz not null
);
create index anon_coach_proposal_logs_subject_idx
  on public.anon_coach_proposal_logs (anon_subject_id);

create table public.anon_plus_funnel_events (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  anon_subject_id uuid not null references public.anon_subjects (anon_subject_id) on delete cascade,
  event text not null,
  feature text,
  product_id text,
  occurred_at_hour timestamptz not null
);
create index anon_plus_funnel_events_subject_idx
  on public.anon_plus_funnel_events (anon_subject_id);

do $$
declare
  t text;
begin
  foreach t in array array[
    'anon_subjects',
    'anon_food_entries',
    'anon_exercise_entries',
    'anon_weight_entries',
    'anon_alcohol_entries',
    'anon_health_workouts',
    'anon_meal_template_usage',
    'anon_workout_template_usage',
    'anon_food_search_queries',
    'anon_exercise_search_queries',
    'anon_screen_actions',
    'anon_app_events',
    'anon_coach_proposal_logs',
    'anon_plus_funnel_events'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'revoke all on table public.%I from public, anon, authenticated',
      t
    );
    execute format('grant select on table public.%I to service_role', t);
  end loop;
end
$$;

create view kpi.anon_subjects with (security_invoker = true) as
select s.*
from public.anon_subjects s
where s.kpi_excluded = false;

create view kpi.anon_food_entries with (security_invoker = true) as
select e.*
from public.anon_food_entries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_exercise_entries with (security_invoker = true) as
select e.*
from public.anon_exercise_entries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_weight_entries with (security_invoker = true) as
select e.*
from public.anon_weight_entries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_alcohol_entries with (security_invoker = true) as
select e.*
from public.anon_alcohol_entries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_health_workouts with (security_invoker = true) as
select e.*
from public.anon_health_workouts e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_meal_template_usage with (security_invoker = true) as
select e.*
from public.anon_meal_template_usage e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_workout_template_usage with (security_invoker = true) as
select e.*
from public.anon_workout_template_usage e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_food_search_queries with (security_invoker = true) as
select e.*
from public.anon_food_search_queries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_exercise_search_queries with (security_invoker = true) as
select e.*
from public.anon_exercise_search_queries e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_screen_actions with (security_invoker = true) as
select e.*
from public.anon_screen_actions e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_app_events with (security_invoker = true) as
select e.*
from public.anon_app_events e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_coach_proposal_logs with (security_invoker = true) as
select e.*
from public.anon_coach_proposal_logs e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

create view kpi.anon_plus_funnel_events with (security_invoker = true) as
select e.*
from public.anon_plus_funnel_events e
join public.anon_subjects s on s.anon_subject_id = e.anon_subject_id
where s.kpi_excluded = false;

grant select on kpi.anon_subjects to service_role;
grant select on kpi.anon_food_entries to service_role;
grant select on kpi.anon_exercise_entries to service_role;
grant select on kpi.anon_weight_entries to service_role;
grant select on kpi.anon_alcohol_entries to service_role;
grant select on kpi.anon_health_workouts to service_role;
grant select on kpi.anon_meal_template_usage to service_role;
grant select on kpi.anon_workout_template_usage to service_role;
grant select on kpi.anon_food_search_queries to service_role;
grant select on kpi.anon_exercise_search_queries to service_role;
grant select on kpi.anon_screen_actions to service_role;
grant select on kpi.anon_app_events to service_role;
grant select on kpi.anon_coach_proposal_logs to service_role;
grant select on kpi.anon_plus_funnel_events to service_role;

create or replace function public.delete_own_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  uid uuid;
  v_plus_status text := 'never';
  v_plan text := 'none';
  v_age_bucket text := 'unknown';
  v_created_at timestamptz;
  v_anon uuid;
  v_birth timestamptz;
  v_years integer;
  v_age_band text := 'unknown';
  v_gender text;
  v_goal text;
  v_height double precision;
  v_weight double precision;
  v_kpi_excluded boolean := false;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'not authenticated';
  end if;
  uid := p_user_id;
  -- 退会ごとに新しい uuid。user_id や email からは作らない。対応は保存しない。
  v_anon := pg_catalog.gen_random_uuid();
  select u.created_at into v_created_at from public.users u where u.id = uid;
  if to_regclass('public.calonavi_plus_entitlements') is not null then
    execute $q$
      select
        case
          when e.status = 'active' and e.expires_at > timezone('utc', now()) then 'active'
          when e.status = 'inactive' then 'never'
          else 'expired'
        end,
        case when e.status = 'inactive' then 'none' else e.product_id end
      from public.calonavi_plus_entitlements e
      where e.user_id = $1
      order by
        (e.status = 'active' and e.expires_at > timezone('utc', now())) desc,
        e.expires_at desc nulls last,
        e.updated_at desc nulls last
      limit 1
    $q$ into v_plus_status, v_plan using uid;
    v_plus_status := coalesce(v_plus_status, 'never');
    v_plan := coalesce(v_plan, 'none');
  end if;
  v_age_bucket := case
    when v_created_at is null then 'unknown'
    when timezone('utc', now()) - v_created_at <= interval '1 day' then '0-1d'
    when timezone('utc', now()) - v_created_at <= interval '7 days' then '2-7d'
    when timezone('utc', now()) - v_created_at <= interval '30 days' then '8-30d'
    when timezone('utc', now()) - v_created_at <= interval '90 days' then '31-90d'
    else '91d+'
  end;
  select p.birth_date, p.gender, p.height_cm, p.weight_kg
    into v_birth, v_gender, v_height, v_weight
  from public.profiles p
  where p.user_id = uid;
  select g.goal_type into v_goal from public.goals g where g.user_id = uid;
  if v_birth is not null then
    v_years := extract(year from age(timezone('utc', now()), v_birth))::integer;
    if v_years is null or v_years < 0 then
      v_age_band := 'unknown';
    elsif v_years >= 90 then
      v_age_band := '90s';
    else
      v_age_band := ((v_years / 10) * 10)::text || 's';
    end if;
  end if;
  v_kpi_excluded := exists (
    select 1 from kpi.excluded_user_ids x where x.user_id = uid
  );
  insert into public.anon_subjects (
    anon_subject_id,
    age_band,
    gender,
    goal_type,
    height_cm,
    weight_kg,
    account_created_month,
    plan_type,
    kpi_excluded,
    deleted_at_hour
  ) values (
    v_anon,
    v_age_band,
    v_gender,
    v_goal,
    v_height,
    v_weight,
    date_trunc('month', v_created_at)::date,
    v_plan,
    v_kpi_excluded,
    date_trunc('hour', timezone('utc', now()))
  );
  insert into public.anon_food_entries (
    anon_subject_id, food_name, kcal_per_unit, protein_per_unit, fat_per_unit,
    carb_per_unit, quantity, logged_at_hour, source_saved_food_version
  )
  select
    v_anon, f.name, f.kcal_per_unit, f.protein_per_unit, f.fat_per_unit,
    f.carb_per_unit, f.quantity, date_trunc('hour', f.logged_at),
    f.source_saved_food_version
  from public.food_entries f
  where f.user_id = uid;
  insert into public.anon_exercise_entries (
    anon_subject_id, activity_name, duration_min, burned_kcal, logged_at_hour
  )
  select
    v_anon, e.name, e.duration_min, e.burned_kcal, date_trunc('hour', e.logged_at)
  from public.exercise_entries e
  where e.user_id = uid;
  insert into public.anon_weight_entries (
    anon_subject_id, weight_kg, source, recorded_at_hour
  )
  select
    v_anon, w.weight_kg, w.source, date_trunc('hour', w.recorded_at)
  from public.weight_entries w
  where w.user_id = uid;
  insert into public.anon_alcohol_entries (
    anon_subject_id, beverage_name, amount, unit, alcohol_percentage,
    total_calories, pure_alcohol_grams, alcohol_calories, consumed_at_hour
  )
  select
    v_anon, a.beverage_name, a.amount, a.unit, a.alcohol_percentage,
    a.total_calories, a.pure_alcohol_grams, a.alcohol_calories,
    date_trunc('hour', a.consumed_at)
  from public.alcohol_entries a
  where a.user_id = uid;
  insert into public.anon_health_workouts (
    anon_subject_id, activity_type, started_at_hour, ended_at_hour, calories_burned
  )
  select
    v_anon, h.activity_type, date_trunc('hour', h.started_at),
    date_trunc('hour', h.ended_at), h.calories_burned
  from public.health_workouts h
  where h.user_id = uid;
  insert into public.anon_meal_template_usage (
    anon_subject_id, use_count, last_used_at_hour
  )
  select
    v_anon, m.use_count, date_trunc('hour', m.last_used_at)
  from public.meal_templates m
  where m.user_id = uid;
  insert into public.anon_workout_template_usage (
    anon_subject_id, use_count, last_used_at_hour
  )
  select
    v_anon, m.use_count, date_trunc('hour', m.last_used_at)
  from public.workout_templates m
  where m.user_id = uid;
  insert into public.anon_food_search_queries (
    anon_subject_id, source, query_text, searched_at_hour
  )
  select
    v_anon, q.source, q.query_text, date_trunc('hour', q.searched_at)
  from public.food_search_queries q
  where q.user_id = uid;
  insert into public.anon_exercise_search_queries (
    anon_subject_id, source, searched_at_hour
  )
  select
    v_anon, q.source, date_trunc('hour', q.searched_at)
  from public.exercise_search_queries q
  where q.user_id = uid;
  insert into public.anon_screen_actions (
    anon_subject_id, screen, action, acted_at_hour
  )
  select
    v_anon, s.screen, s.action, date_trunc('hour', s.acted_at)
  from public.app_screen_actions s
  where s.user_id = uid;
  insert into public.anon_app_events (
    anon_subject_id, event_name, occurred_at_hour, origin, stream, app_version
  )
  select
    v_anon, ev.event_name, date_trunc('hour', ev.occurred_at),
    ev.origin, ev.stream, ev.app_version
  from public.app_events ev
  where ev.user_id = uid;
  insert into public.anon_coach_proposal_logs (
    anon_subject_id, registered, recorded_at_hour
  )
  select
    v_anon, c.registered, date_trunc('hour', c.recorded_at)
  from public.coach_proposal_logs c
  where c.user_id = uid;
  insert into public.anon_plus_funnel_events (
    anon_subject_id, event, feature, product_id, occurred_at_hour
  )
  select
    v_anon, p.event, p.feature, p.product_id, date_trunc('hour', p.occurred_at)
  from public.plus_funnel_events p
  where p.user_id = uid;
  if not exists (select 1 from kpi.excluded_user_ids x where x.user_id = uid) then
    insert into public.account_deletion_stats (deleted_on, plus_status, plan, account_age_bucket, deletions)
    values ((timezone('Asia/Tokyo', now()))::date, v_plus_status, v_plan, v_age_bucket, 1)
    on conflict (deleted_on, plus_status, plan, account_age_bucket)
    do update set deletions = public.account_deletion_stats.deletions + 1;
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
  if to_regclass('public.coach_proposal_logs') is not null then
    execute 'delete from public.coach_proposal_logs where user_id = $1' using uid;
  end if;
  if to_regclass('public.app_events') is not null then
    execute 'delete from public.app_events where user_id = $1' using uid;
  end if;
  if to_regclass('public.store_original_transactions') is not null then
    execute 'delete from public.store_original_transactions where user_id = $1' using uid;
  end if;
  if to_regclass('public.app_event_user_days') is not null then
    execute 'delete from public.app_event_user_days where user_id = $1' using uid;
  end if;
  if to_regclass('public.analytics_consents') is not null then
    execute 'delete from public.analytics_consents where user_id = $1' using uid;
  end if;
  if to_regclass('public.plus_funnel_events') is not null then
    execute 'delete from public.plus_funnel_events where user_id = $1' using uid;
  end if;
  if to_regclass('public.store_server_notifications') is not null then
    execute $q$
      update public.store_server_notifications
      set user_id = null,
          app_account_token = null,
          signed_payload = null,
          decoded_payload = null
      where user_id = $1 or app_account_token = $1
    $q$ using uid;
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
      raise exception 'delete_own_account: auth deletion failed: %', sqlerrm;
  end;
end;
$function$;
revoke all on function public.delete_own_account(uuid) from public, anon, authenticated;
grant execute on function public.delete_own_account(uuid) to service_role;

commit;
