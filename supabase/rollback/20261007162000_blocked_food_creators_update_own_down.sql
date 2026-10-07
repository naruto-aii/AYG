-- ブロックの更新方針だけを外す。行は残す。

begin;

drop policy if exists blocked_food_creators_update_own
  on public.blocked_food_creators;

commit;
