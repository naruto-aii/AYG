-- AIの収集表と、利用者ごとの推定キャッシュを戻す。食事の行は消さない。
-- 20261008160000 のロールバックより先に流す。本番に適用していないときは、流さなくてよい。

begin;

drop trigger if exists delete_ai_food_results_on_account_close
  on public.users;
drop function if exists public.delete_ai_food_results_on_account_close();

drop function if exists public.record_ai_food_result_outcome(
  uuid, boolean, text, text, numeric, numeric, numeric, numeric
);

drop view if exists kpi.ai_food_result_collections;
drop table if exists public.ai_food_result_collections;

delete from public.ai_food_estimate_cache;

alter table public.ai_food_estimate_cache
  drop constraint if exists ai_food_estimate_cache_pkey;

alter table public.ai_food_estimate_cache
  drop column if exists user_id;

alter table public.ai_food_estimate_cache
  add primary key (query_key);

comment on table public.ai_food_estimate_cache is
  'AIで探すの推定キャッシュ。正規化した検索語、モデル、期限、推定。食品データベースではなく、チェーンの栄養成分の一括取り込みでもない。画面の食品一覧には出さない。';

commit;
