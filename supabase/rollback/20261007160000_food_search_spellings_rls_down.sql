-- food_search_spellings の RLS と SELECT 方針だけを外す。行は残す。

begin;

drop policy if exists food_search_spellings_select_authenticated
  on public.food_search_spellings;

alter table public.food_search_spellings disable row level security;

commit;
