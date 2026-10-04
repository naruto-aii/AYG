-- お知らせ表だけを戻す。食事、運動、公式食品は消さない。
-- 2回実行しても失敗しない。

begin;

drop policy if exists announcements_select_published on public.announcements;

drop table if exists public.announcements;

commit;
