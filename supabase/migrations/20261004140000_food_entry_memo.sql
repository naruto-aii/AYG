-- その日の食品へのメモ。カロナビ+の機能。
-- 空は入れない。食事の行そのものは消さない。

begin;

alter table public.food_entries
  add column if not exists memo text;

alter table public.food_entries
  drop constraint if exists food_entries_memo_length;

alter table public.food_entries
  add constraint food_entries_memo_length
  check (memo is null or char_length(btrim(memo)) between 1 and 200);

comment on column public.food_entries.memo is
  'その食事へのメモ。空は保存しない。カロナビ+が無い利用者はアプリから書かない。';

commit;
