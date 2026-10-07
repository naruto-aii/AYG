-- 同じ相手をもう一度ブロックすると失敗していた。本人の行を更新できるようにする。
-- 本番へは適用済み。このファイルはリポジトリを本番に合わせる。

begin;

drop policy if exists blocked_food_creators_update_own
  on public.blocked_food_creators;

create policy blocked_food_creators_update_own on public.blocked_food_creators for update to authenticated using ((select auth.uid()) = blocker_user_id) with check ((select auth.uid()) = blocker_user_id);

commit;
