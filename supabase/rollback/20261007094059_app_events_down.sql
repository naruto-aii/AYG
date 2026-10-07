-- 20261007094059 で足した行動の記録と App Store 取り込みの表を消す。
-- app_events の行は消える。先に 20261007094142_app_events_retention_down.sql を流す。
-- delete_own_account は、本番に当たっている 20261007090000 の定義に戻す。

begin;

do $guard$
begin
  if to_regclass('public.store_original_transactions') is not null
     or to_regprocedure('public.insert_app_events(jsonb)') is not null
     or to_regprocedure('public.maintain_app_events()') is not null then
    raise exception '20261007094142 を先に戻してください';
  end if;
end
$guard$;

drop view if exists public.store_import_health;
drop view if exists public.app_event_sequence_gaps;
drop view if exists public.app_events_including_legacy;

drop table if exists public.store_analytics_rows;
drop table if exists public.store_analytics_segments;
drop table if exists public.store_analytics_report_requests;
drop table if exists public.store_sales_rows;
drop table if exists public.store_sales_report_files;
drop table if exists public.store_server_notifications;
drop table if exists public.store_import_runs;
drop table if exists public.analytics_consents;
drop table if exists public.account_deletion_stats;
drop table if exists public.app_events cascade;

-- 本番の delete_own_account（20261007090000）。新しい表の削除は足さない。
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
