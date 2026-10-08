-- 写真で登録の利用記録だけを戻す。食事の行は消さない。
-- 本番に適用していないときは、流さなくてよい。

begin;

alter table public.plus_funnel_events
  drop constraint if exists plus_funnel_events_feature_check;

delete from public.plus_funnel_events where feature = 'photo_meal';

alter table public.plus_funnel_events
  add constraint plus_funnel_events_feature_check
  check (feature is null or feature in (
    'meal_template_limit',
    'workout_template_limit',
    'recent_foods',
    'memo',
    'widget',
    'siri',
    'coach'
  ));

drop trigger if exists delete_meal_photo_analyses_on_account_close
  on public.users;
drop function if exists public.delete_meal_photo_analyses_on_account_close();

drop view if exists kpi.meal_photo_analyses;

drop trigger if exists meal_photo_analyses_guard_update
  on public.meal_photo_analyses;
drop function if exists public.meal_photo_analyses_guard_update();

drop table if exists public.meal_photo_analyses;

commit;
