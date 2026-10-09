-- AI機能で個人の入力を外部へ送る前の同意。時刻はサーバが付ける。
-- 本番には適用しない。手順は supabase/functions/README.md。
-- 20261008200000 のあと。関数より先。

begin;

create table if not exists public.ai_data_consents (
  user_id uuid primary key references public.users (id) on delete cascade,
  policy_version text not null,
  consented_at timestamptz not null default timezone('utc', now()),
  constraint ai_data_consents_policy_version_length
    check (char_length(policy_version) between 1 and 32)
);

comment on table public.ai_data_consents is
  'AI機能の同意。利用者ID、版、同意した時刻だけ。写真や検索語は入れない。アカウント削除で消す。';

create or replace function public.ai_data_consents_stamp()
returns trigger
language plpgsql
as $$
begin
  new.consented_at = timezone('utc', now());
  return new;
end;
$$;

revoke all on function public.ai_data_consents_stamp()
  from public, anon, authenticated;

drop trigger if exists ai_data_consents_stamp on public.ai_data_consents;
create trigger ai_data_consents_stamp
  before insert or update on public.ai_data_consents
  for each row
  execute function public.ai_data_consents_stamp();

alter table public.ai_data_consents enable row level security;

revoke all on table public.ai_data_consents from anon, authenticated;
grant select, insert, update on table public.ai_data_consents to authenticated;

drop policy if exists ai_data_consents_select_own on public.ai_data_consents;
create policy ai_data_consents_select_own
  on public.ai_data_consents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists ai_data_consents_insert_own on public.ai_data_consents;
create policy ai_data_consents_insert_own
  on public.ai_data_consents
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists ai_data_consents_update_own on public.ai_data_consents;
create policy ai_data_consents_update_own
  on public.ai_data_consents
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 退会は users 行を消さず deleted_at を入れる。カスケードでは消えない。
create or replace function public.delete_ai_data_consent_on_account_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null
    and old.deleted_at is distinct from new.deleted_at
  then
    delete from public.ai_data_consents where user_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.delete_ai_data_consent_on_account_close()
  from public, anon, authenticated;

drop trigger if exists delete_ai_data_consent_on_account_close
  on public.users;
create trigger delete_ai_data_consent_on_account_close
  after update of deleted_at on public.users
  for each row
  execute function public.delete_ai_data_consent_on_account_close();

commit;
