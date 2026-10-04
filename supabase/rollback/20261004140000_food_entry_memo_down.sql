-- 食事メモの列だけを戻す。食事の行は消さない。
-- 2回実行しても失敗しない。

begin;

alter table public.food_entries
  drop constraint if exists food_entries_memo_length;

alter table public.food_entries
  drop column if exists memo;

commit;
