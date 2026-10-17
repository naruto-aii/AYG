-- アプリの更新案内。1行だけ。
-- minimum_version 未満は続けられない。recommended_version 未満は閉じられる。
-- 読み取りは anon と authenticated。書き込みは service role だけ。

begin;

create table if not exists public.app_version_policy (
  id int primary key default 1 check (id = 1),
  minimum_version text not null,
  recommended_version text not null,
  ios_store_url text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.app_version_policy is
  'アプリの最低版と推奨版。id は 1 の1行だけ。';

alter table public.app_version_policy enable row level security;

drop policy if exists app_version_policy_select on public.app_version_policy;
create policy app_version_policy_select
  on public.app_version_policy
  for select
  to anon, authenticated
  using (true);

revoke all on table public.app_version_policy from public;
revoke all on table public.app_version_policy from anon, authenticated;
grant select on table public.app_version_policy to anon;
grant select on table public.app_version_policy to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select, insert, update, delete on table public.app_version_policy
      to service_role;
  end if;
end
$$;

insert into public.app_version_policy (
  id,
  minimum_version,
  recommended_version,
  ios_store_url
) values (
  1,
  '0.0.0',
  '0.0.0',
  'https://apps.apple.com/jp/app/id6814054275'
);

commit;
