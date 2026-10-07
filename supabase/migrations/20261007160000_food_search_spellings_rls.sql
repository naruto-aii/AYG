-- food_search_spellings は SECURITY DEFINER の expand_public_food_voice だけが読む。
-- 本番へは適用済み。このファイルはリポジトリを本番に合わせる。
-- anon と authenticated の直接の権限は外す。authenticated には SELECT だけの方針を付ける。

begin;

alter table public.food_search_spellings enable row level security;

drop policy if exists food_search_spellings_select_authenticated
  on public.food_search_spellings;

create policy food_search_spellings_select_authenticated
  on public.food_search_spellings
  for select
  to authenticated
  using (true);

revoke all on table public.food_search_spellings from public;
revoke all on table public.food_search_spellings from anon;
revoke all on table public.food_search_spellings from authenticated;

commit;
