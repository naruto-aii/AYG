-- 20261003160000 で足した4表だけを消す。食事、体重、運動、目標、ヘルスケアの行は消さない。
-- 先にアプリを、この表へ書かない版へ戻してから流す。
-- 2回実行しても失敗しない。表が既に無いときは drop は何もしない。
-- このダウンで消えるのは、適用後にたまった購入状態、検索語、画面操作だけ。

begin;

drop table if exists public.app_screen_actions;
drop table if exists public.exercise_search_queries;
drop table if exists public.food_search_queries;
drop table if exists public.calonavi_plus_entitlements;

-- delete_own_account を、この表を消す前の本体へ戻す。
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
