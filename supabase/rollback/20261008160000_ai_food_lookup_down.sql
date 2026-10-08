-- AIで探すの利用記録と推定キャッシュだけを戻す。食事の行は消さない。
-- 写真で登録より先に戻す。本番に適用していないときは、流さなくてよい。

begin;

alter table public.plus_funnel_events
  drop constraint if exists plus_funnel_events_feature_check;

delete from public.plus_funnel_events where feature = 'ai_food_lookup';

alter table public.plus_funnel_events
  add constraint plus_funnel_events_feature_check
  check (feature is null or feature in (
    'meal_template_limit',
    'workout_template_limit',
    'recent_foods',
    'memo',
    'widget',
    'siri',
    'coach',
    'photo_meal'
  ));

drop trigger if exists delete_meal_text_lookups_on_account_close
  on public.users;
drop function if exists public.delete_meal_text_lookups_on_account_close();

drop view if exists kpi.meal_text_lookups;

drop trigger if exists meal_text_lookups_guard_update
  on public.meal_text_lookups;
drop function if exists public.meal_text_lookups_guard_update();

drop table if exists public.meal_text_lookups;
drop table if exists public.ai_food_estimate_cache;

commit;
