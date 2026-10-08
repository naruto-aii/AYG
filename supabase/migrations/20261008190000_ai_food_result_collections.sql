-- AIが返した食品の収集。アプリの検索にも、他の利用者にも出さない。
-- 推定キャッシュは利用者ごとにする。共有していた行は消す。
-- 本番には適用しない。手順は supabase/functions/README.md。
-- 20261008160000 のあと。自炊コーチの 20261008180000 よりあとでも、その前でもよい。

begin;

create table if not exists public.ai_food_result_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  source_path text not null
    check (source_path in ('ai_search', 'photo')),
  normalized_name text not null
    check (char_length(normalized_name) between 1 and 80),
  chain_name text
    check (chain_name is null or char_length(chain_name) between 1 and 80),
  amount text not null
    check (char_length(amount) <= 40),
  kcal numeric not null
    check (kcal >= 0 and kcal <= 10000),
  protein_g numeric not null
    check (protein_g >= 0 and protein_g <= 1000),
  fat_g numeric not null
    check (fat_g >= 0 and fat_g <= 1000),
  carb_g numeric not null
    check (carb_g >= 0 and carb_g <= 1000),
  model text not null
    check (char_length(model) between 1 and 80),
  registered_as_is boolean,
  user_edited boolean,
  edited_name text
    check (edited_name is null or char_length(edited_name) between 1 and 80),
  edited_amount text
    check (edited_amount is null or char_length(edited_amount) <= 40),
  edited_kcal numeric
    check (edited_kcal is null or (edited_kcal >= 0 and edited_kcal <= 10000)),
  edited_protein_g numeric
    check (edited_protein_g is null or (edited_protein_g >= 0 and edited_protein_g <= 1000)),
  edited_fat_g numeric
    check (edited_fat_g is null or (edited_fat_g >= 0 and edited_fat_g <= 1000)),
  edited_carb_g numeric
    check (edited_carb_g is null or (edited_carb_g >= 0 and edited_carb_g <= 1000)),
  advertising_use boolean not null default false
    check (advertising_use = false),
  constraint ai_food_result_collections_outcome check (
    (
      registered_as_is is null
      and user_edited is null
      and edited_name is null
      and edited_amount is null
      and edited_kcal is null
      and edited_protein_g is null
      and edited_fat_g is null
      and edited_carb_g is null
    )
    or (
      registered_as_is = true
      and user_edited = false
      and edited_name is null
      and edited_amount is null
      and edited_kcal is null
      and edited_protein_g is null
      and edited_fat_g is null
      and edited_carb_g is null
    )
    or (
      registered_as_is = false
      and user_edited = true
      and edited_name is not null
      and edited_amount is not null
      and edited_kcal is not null
      and edited_protein_g is not null
      and edited_fat_g is not null
      and edited_carb_g is not null
    )
  )
);

comment on table public.ai_food_result_collections is
  'AIが返した食品の収集。検索結果にも、他の利用者にも出さない。食品データベースではない。広告には使わない。';
comment on column public.ai_food_result_collections.source_path is
  'ai_search は AIで探すと外食・コンビニ。photo は写真で登録。';
comment on column public.ai_food_result_collections.registered_as_is is
  '保存前に名前、量、カロリー、PFCを変えていないとき true。まだ保存していないときは null。';
comment on column public.ai_food_result_collections.user_edited is
  '保存前にどれかを変えたとき true。まだ保存していないときは null。';

create index if not exists ai_food_result_collections_user_created_idx
  on public.ai_food_result_collections (user_id, created_at desc);

alter table public.ai_food_result_collections enable row level security;

drop policy if exists ai_food_result_collections_insert_own
  on public.ai_food_result_collections;
create policy ai_food_result_collections_insert_own
  on public.ai_food_result_collections
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.ai_food_result_collections from public, anon, authenticated;
grant insert on table public.ai_food_result_collections to authenticated;

-- 退会は users 行を消さず deleted_at を入れる。カスケードでは消えない。
create or replace function public.delete_ai_food_results_on_account_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null
    and old.deleted_at is distinct from new.deleted_at
  then
    delete from public.ai_food_result_collections where user_id = new.id;
    delete from public.ai_food_estimate_cache where user_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.delete_ai_food_results_on_account_close()
  from public, anon, authenticated;

drop trigger if exists delete_ai_food_results_on_account_close
  on public.users;
create trigger delete_ai_food_results_on_account_close
  after update of deleted_at on public.users
  for each row
  execute function public.delete_ai_food_results_on_account_close();

-- 本人の保存結果だけを書く。行は返さない。読む方針は作らない。
create or replace function public.record_ai_food_result_outcome(
  p_id uuid,
  p_registered_as_is boolean,
  p_edited_name text,
  p_edited_amount text,
  p_edited_kcal numeric,
  p_edited_protein_g numeric,
  p_edited_fat_g numeric,
  p_edited_carb_g numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;
  if p_registered_as_is then
    update public.ai_food_result_collections
      set registered_as_is = true,
          user_edited = false,
          edited_name = null,
          edited_amount = null,
          edited_kcal = null,
          edited_protein_g = null,
          edited_fat_g = null,
          edited_carb_g = null
      where id = p_id
        and user_id = auth.uid();
    return;
  end if;
  if p_edited_name is null
    or char_length(btrim(p_edited_name)) < 1
    or char_length(btrim(p_edited_name)) > 80
    or p_edited_amount is null
    or char_length(p_edited_amount) > 40
    or p_edited_kcal is null
    or p_edited_kcal < 0
    or p_edited_kcal > 10000
    or p_edited_protein_g is null
    or p_edited_protein_g < 0
    or p_edited_protein_g > 1000
    or p_edited_fat_g is null
    or p_edited_fat_g < 0
    or p_edited_fat_g > 1000
    or p_edited_carb_g is null
    or p_edited_carb_g < 0
    or p_edited_carb_g > 1000
  then
    return;
  end if;
  update public.ai_food_result_collections
    set registered_as_is = false,
        user_edited = true,
        edited_name = btrim(p_edited_name),
        edited_amount = p_edited_amount,
        edited_kcal = p_edited_kcal,
        edited_protein_g = p_edited_protein_g,
        edited_fat_g = p_edited_fat_g,
        edited_carb_g = p_edited_carb_g
    where id = p_id
      and user_id = auth.uid();
end;
$$;

revoke all on function public.record_ai_food_result_outcome(
  uuid, boolean, text, text, numeric, numeric, numeric, numeric
) from public, anon;
grant execute on function public.record_ai_food_result_outcome(
  uuid, boolean, text, text, numeric, numeric, numeric, numeric
) to authenticated;

create or replace view kpi.ai_food_result_collections
  with (security_invoker = true) as
select t.*
from public.ai_food_result_collections t
where not exists (
  select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id
);

revoke all on table kpi.ai_food_result_collections from public, anon, authenticated;
grant select on table kpi.ai_food_result_collections to service_role;

-- 共有キャッシュは他の利用者へ推定を出してしまう。行を消して、本人だけにする。
delete from public.ai_food_estimate_cache;

alter table public.ai_food_estimate_cache
  add column user_id uuid not null references public.users (id);

alter table public.ai_food_estimate_cache
  drop constraint ai_food_estimate_cache_pkey;

alter table public.ai_food_estimate_cache
  add primary key (user_id, query_key);

comment on table public.ai_food_estimate_cache is
  'AIで探すの推定キャッシュ。本人の正規化した検索語だけ。食品データベースではなく、他の利用者には出さない。画面の食品一覧には出さない。';

commit;
