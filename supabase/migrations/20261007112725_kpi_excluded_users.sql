-- =====================================================================
-- KPI から開発者アカウントを外す
-- 置き場所: supabase/migrations/<prod version>_kpi_excluded_users.sql
-- - public.kpi_excluded_users: 外すアカウント（user_id / install_id / email）の一覧。サーバーだけが読む・書く。
-- - kpi スキーマ: 一覧を除いた KPI 用ビュー。API には出さない（anon / authenticated は使えない）。
-- - maintain_app_events: 日次集計（app_event_daily_totals）に一覧の行を足さない。生データと利用者ごとの日の要約は今までどおり残す。
-- - delete_own_account: 一覧のアカウントの退会は account_deletion_stats に数えない。ほかの手順は同じ。
-- 既存の行は消さない・書き換えない。
-- 追加: insert into public.kpi_excluded_users (user_id, reason) values ('<uuid>', '<理由>');
-- =====================================================================

create table public.kpi_excluded_users (
  id bigint generated always as identity primary key,
  user_id uuid,
  install_id uuid,
  email text,
  reason text not null,
  added_at timestamptz not null default timezone('utc', now()),
  constraint kpi_excluded_users_target check (num_nonnulls(user_id, install_id, email) >= 1)
);
create unique index kpi_excluded_users_user_id_key on public.kpi_excluded_users (user_id) where user_id is not null;
create unique index kpi_excluded_users_install_id_key on public.kpi_excluded_users (install_id) where install_id is not null;
create unique index kpi_excluded_users_email_key on public.kpi_excluded_users (lower(email)) where email is not null;
comment on table public.kpi_excluded_users is 'KPI に数えない開発者・テスト用のアカウント。user_id、install_id（端末）、email（同じ Apple ID で作り直したアカウントも外す）のどれかで指定する。データは消さず、kpi スキーマのビューと日次集計・退会集計で外す。サーバーだけが読む・書く。';
alter table public.kpi_excluded_users enable row level security;
revoke all on table public.kpi_excluded_users from public, anon, authenticated;
grant select, insert, update, delete on table public.kpi_excluded_users to service_role;

create schema kpi;
comment on schema kpi is 'KPI 用のビュー。public.kpi_excluded_users のアカウントを除いて見せる。API には出さない。';
revoke all on schema kpi from public, anon, authenticated;
grant usage on schema kpi to service_role;

create view kpi.excluded_user_ids with (security_invoker = true) as
select x.user_id from public.kpi_excluded_users x where x.user_id is not null
union
select u.id from public.kpi_excluded_users x
join public.users u on lower(u.email) = lower(x.email)
where x.email is not null;

create view kpi.excluded_install_ids with (security_invoker = true) as
select x.install_id from public.kpi_excluded_users x where x.install_id is not null;

create view kpi.users with (security_invoker = true) as
select t.* from public.users t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.id);

create view kpi.food_ratings with (security_invoker = true) as
select t.* from public.food_ratings t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.rater_user_id);

create view kpi.food_reports with (security_invoker = true) as
select t.* from public.food_reports t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.reporter_user_id);

create view kpi.blocked_food_creators with (security_invoker = true) as
select t.* from public.blocked_food_creators t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.blocker_user_id);

create view kpi.profiles with (security_invoker = true) as
select t.* from public.profiles t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.goals with (security_invoker = true) as
select t.* from public.goals t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.nutrition_settings with (security_invoker = true) as
select t.* from public.nutrition_settings t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.app_settings with (security_invoker = true) as
select t.* from public.app_settings t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.health_snapshots with (security_invoker = true) as
select t.* from public.health_snapshots t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.account_display_names with (security_invoker = true) as
select t.* from public.account_display_names t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.food_entries with (security_invoker = true) as
select t.* from public.food_entries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.exercise_entries with (security_invoker = true) as
select t.* from public.exercise_entries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.weight_entries with (security_invoker = true) as
select t.* from public.weight_entries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.alcohol_entries with (security_invoker = true) as
select t.* from public.alcohol_entries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.saved_foods with (security_invoker = true) as
select t.* from public.saved_foods t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.meal_templates with (security_invoker = true) as
select t.* from public.meal_templates t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.meal_template_items with (security_invoker = true) as
select t.* from public.meal_template_items t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.workout_templates with (security_invoker = true) as
select t.* from public.workout_templates t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.workout_template_items with (security_invoker = true) as
select t.* from public.workout_template_items t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.calonavi_plus_entitlements with (security_invoker = true) as
select t.* from public.calonavi_plus_entitlements t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.plus_funnel_events with (security_invoker = true) as
select t.* from public.plus_funnel_events t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.coach_proposal_logs with (security_invoker = true) as
select t.* from public.coach_proposal_logs t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.food_search_queries with (security_invoker = true) as
select t.* from public.food_search_queries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.exercise_search_queries with (security_invoker = true) as
select t.* from public.exercise_search_queries t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.app_screen_actions with (security_invoker = true) as
select t.* from public.app_screen_actions t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.health_workouts with (security_invoker = true) as
select t.* from public.health_workouts t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.app_event_user_days with (security_invoker = true) as
select t.* from public.app_event_user_days t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.store_original_transactions with (security_invoker = true) as
select t.* from public.store_original_transactions t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id);

create view kpi.app_events with (security_invoker = true) as
select t.* from public.app_events t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id)
  and not exists (select 1 from kpi.excluded_install_ids y where y.install_id = t.install_id);

create view kpi.analytics_consents with (security_invoker = true) as
select t.* from public.analytics_consents t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id)
  and not exists (select 1 from kpi.excluded_install_ids y where y.install_id = t.install_id);

create view kpi.app_events_including_legacy with (security_invoker = true) as
select t.* from public.app_events_including_legacy t
where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id)
  and not (t.data_source = 'app_events' and exists (
    select 1 from public.app_events e
    join kpi.excluded_install_ids y on y.install_id = e.install_id
    where e.event_id = t.event_id));

-- 書くときに除外済み（maintain_app_events / delete_own_account）。KPI は kpi スキーマだけ見ればよいように置く。
create view kpi.app_event_daily_totals with (security_invoker = true) as
select t.* from public.app_event_daily_totals t;
create view kpi.account_deletion_stats with (security_invoker = true) as
select t.* from public.account_deletion_stats t;

revoke all on all tables in schema kpi from public, anon, authenticated;
grant select on all tables in schema kpi to service_role;

CREATE OR REPLACE FUNCTION public.maintain_app_events()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  i integer;
  month_start date := date_trunc('month', timezone('utc', now()))::date;
  stray_month date;
  stray_months date[];
  part_names text[];
  part_name text;
  part_range_start timestamptz;
  part_range_end timestamptz;
begin
  perform pg_catalog.pg_advisory_xact_lock(908030250);

  if to_regclass('public.app_events_default') is not null then
    select coalesce(array_agg(distinct date_trunc('month', occurred_at at time zone 'utc')::date), '{}'::date[])
    into stray_months
    from public.app_events_default;

    foreach stray_month in array stray_months loop
      truncate public.app_events_rehome;
      execute format(
        'insert into public.app_events_rehome select * from public.app_events_default where occurred_at >= %L and occurred_at < %L',
        (stray_month::timestamp at time zone 'utc'),
        ((stray_month + interval '1 month')::timestamp at time zone 'utc')
      );
      delete from public.app_events_default
      where occurred_at >= (stray_month::timestamp at time zone 'utc')
        and occurred_at < ((stray_month + interval '1 month')::timestamp at time zone 'utc');
      perform public.ensure_app_events_partition(stray_month);
      insert into public.app_events
      select * from public.app_events_rehome
      on conflict do nothing;
      truncate public.app_events_rehome;
    end loop;
  end if;

  for i in -1..3 loop
    perform public.ensure_app_events_partition(
      (month_start + make_interval(months => i))::date
    );
  end loop;

  select coalesce(array_agg(partition_name order by range_start), '{}'::text[])
  into part_names
  from public.app_event_partitions
  where public.app_event_month_is_aggregated(range_start);

  foreach part_name in array part_names loop
    select range_start, range_end
    into part_range_start, part_range_end
    from public.app_event_partitions
    where partition_name = part_name;
    if part_range_start is null or part_range_end is null then
      continue;
    end if;

    execute format(
      $rollup$
        insert into public.app_event_daily_totals (day, event_name, origin, event_count)
        select (p.occurred_at at time zone 'utc')::date, p.event_name, p.origin, count(*)
        from public.%I p
        where not exists (select 1 from kpi.excluded_user_ids x where x.user_id = p.user_id)
          and not exists (select 1 from kpi.excluded_install_ids y where y.install_id = p.install_id)
        group by 1, 2, 3
        on conflict (day, event_name, origin) do update
          set event_count = public.app_event_daily_totals.event_count + excluded.event_count
      $rollup$,
      part_name
    );

    execute format(
      $rollup$
        insert into public.app_event_user_days (user_id, day, event_count, events)
        select user_id, day, sum(cnt)::integer, jsonb_object_agg(event_name, cnt)
        from (
          select
            user_id,
            (occurred_at at time zone 'utc')::date as day,
            event_name,
            count(*) as cnt
          from public.%I
          group by 1, 2, 3
        ) grouped
        group by user_id, day
        on conflict (user_id, day) do update
          set event_count = public.app_event_user_days.event_count + excluded.event_count,
              events = coalesce((
                select jsonb_object_agg(merged.key, merged.total)
                from (
                  select e.key, sum((e.value #>> '{}')::bigint) as total
                  from (
                    select key, value
                    from jsonb_each(public.app_event_user_days.events)
                    union all
                    select key, value
                    from jsonb_each(excluded.events)
                  ) e
                  group by e.key
                ) merged
              ), '{}'::jsonb)
      $rollup$,
      part_name
    );

    execute format('drop table public.%I', part_name);
    delete from public.app_event_partitions
    where partition_name = part_name;
  end loop;

  delete from public.app_event_daily_totals
  where day < (timezone('utc', now()) - interval '2 years')::date;
  delete from public.app_event_user_days
  where day < (timezone('utc', now()) - interval '13 months')::date;
end;
$function$;
comment on function public.maintain_app_events() is 'app_event_month_is_aggregated が真の月を日次集計へ足してから表を消す。kpi_excluded_users の行は日次集計に足さない。';
revoke all on function public.maintain_app_events() from public, anon, authenticated;
grant execute on function public.maintain_app_events() to service_role;

CREATE OR REPLACE FUNCTION public.delete_own_account(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid;
  v_plus_status text := 'never';
  v_plan text := 'none';
  v_age_bucket text := 'unknown';
  v_created_at timestamptz;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'not authenticated';
  end if;
  uid := p_user_id;
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
      raise notice 'delete_own_account: skipped auth.users update: %', sqlerrm;
  end;
end;
$function$;
revoke all on function public.delete_own_account(uuid) from public, anon, authenticated;
grant execute on function public.delete_own_account(uuid) to service_role;
