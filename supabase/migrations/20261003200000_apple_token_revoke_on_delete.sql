-- Sign in with Apple のリフレッシュトークンを、失効のためだけに保存する。
-- 本番には適用しない。既存の食事・プロフィール・公開食品は消さない。
--
-- トークンは internal.apple_refresh_tokens に置く。このスキーマは Data API に出ない。
-- 読み書きは service_role だけが呼べる関数経由。アプリには返さない。
-- 購入のレシート本文や購入トークンは、ここにも他の表にも入れない。
--
-- 引数なしの delete_own_account() は、トークン失効を飛ばせるので落とす。
-- 代わりに service_role だけが呼べる delete_own_account(uuid) を置く。
-- 消す行は、これまでの本人の記録と同じ。公開食品の行は消さない。

begin;

create schema if not exists internal;

revoke all on schema internal from public;
revoke all on schema internal from anon;
revoke all on schema internal from authenticated;

create table if not exists internal.apple_refresh_tokens (
  user_id uuid primary key,
  refresh_token text not null,
  constraint apple_refresh_tokens_length check (
    char_length(refresh_token) between 1 and 4096
  )
);

revoke all on table internal.apple_refresh_tokens from public;
revoke all on table internal.apple_refresh_tokens from anon;
revoke all on table internal.apple_refresh_tokens from authenticated;

create or replace function public.store_apple_refresh_token(
  p_user_id uuid,
  p_refresh_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null
    or p_refresh_token is null
    or pg_catalog.char_length(pg_catalog.btrim(p_refresh_token)) = 0
    or pg_catalog.char_length(p_refresh_token) > 4096
  then
    raise exception 'apple refresh token payload is empty';
  end if;

  insert into internal.apple_refresh_tokens as stored (user_id, refresh_token)
  values (p_user_id, p_refresh_token)
  on conflict (user_id) do update
    set refresh_token = excluded.refresh_token;
end;
$$;

create or replace function public.read_apple_refresh_token(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  if p_user_id is null then
    return null;
  end if;

  select stored.refresh_token
    into token
  from internal.apple_refresh_tokens as stored
  where stored.user_id = p_user_id;

  return token;
end;
$$;

create or replace function public.delete_apple_refresh_token(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    return;
  end if;

  delete from internal.apple_refresh_tokens as stored
  where stored.user_id = p_user_id;
end;
$$;

revoke all on function public.store_apple_refresh_token(uuid, text) from public;
revoke all on function public.store_apple_refresh_token(uuid, text) from anon;
revoke all on function public.store_apple_refresh_token(uuid, text) from authenticated;

revoke all on function public.read_apple_refresh_token(uuid) from public;
revoke all on function public.read_apple_refresh_token(uuid) from anon;
revoke all on function public.read_apple_refresh_token(uuid) from authenticated;

revoke all on function public.delete_apple_refresh_token(uuid) from public;
revoke all on function public.delete_apple_refresh_token(uuid) from anon;
revoke all on function public.delete_apple_refresh_token(uuid) from authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.store_apple_refresh_token(uuid, text) to service_role;
    grant execute on function public.read_apple_refresh_token(uuid) to service_role;
    grant execute on function public.delete_apple_refresh_token(uuid) to service_role;
  end if;
end
$$;

drop function if exists public.delete_own_account();

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
