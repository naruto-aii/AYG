-- 今日のコーチが出した提案。
-- 経営判断スプレッドシート 148oUF5Coz17Bk7poFs0xQOdiO3Z_tkNB-PKN5w74H80 へ出す前提。
-- アプリが保存するのは提案内容、登録したか、日時だけ。シートへの書き込みはしない。
-- Good/Bad は置かない。既存の行は消さない。truncate しない。

begin;

create table if not exists public.coach_proposal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  proposal text not null
    check (char_length(btrim(proposal)) between 1 and 2000),
  registered boolean not null default false,
  recorded_at timestamptz not null
);

comment on table public.coach_proposal_logs is
  '今日のコーチの提案。経営判断スプレッドシート 148oUF5Coz17Bk7poFs0xQOdiO3Z_tkNB-PKN5w74H80 へ出す前提で、提案内容、登録したか、日時だけを残す。このマイグレーションはシートへ書き込まない。';
comment on column public.coach_proposal_logs.proposal is
  '出した提案の内容。';
comment on column public.coach_proposal_logs.registered is
  'その提案を食事へ登録したか。未登録は false。';
comment on column public.coach_proposal_logs.recorded_at is
  '提案を出した日時。';

create index if not exists coach_proposal_logs_user_recorded_idx
  on public.coach_proposal_logs (user_id, recorded_at desc);

alter table public.coach_proposal_logs enable row level security;

drop policy if exists coach_proposal_logs_select_own
  on public.coach_proposal_logs;
create policy coach_proposal_logs_select_own
  on public.coach_proposal_logs for select
  using ((select auth.uid()) = user_id);

drop policy if exists coach_proposal_logs_insert_own
  on public.coach_proposal_logs;
create policy coach_proposal_logs_insert_own
  on public.coach_proposal_logs for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists coach_proposal_logs_update_own
  on public.coach_proposal_logs;
create policy coach_proposal_logs_update_own
  on public.coach_proposal_logs for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.coach_proposal_logs from public, anon, authenticated;
grant select, insert, update on table public.coach_proposal_logs to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select, insert, update, delete on table public.coach_proposal_logs
      to service_role;
  end if;
end
$$;

-- アカウント削除で、その本人の提案記録だけを消す。
create or replace function public.delete_own_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
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
