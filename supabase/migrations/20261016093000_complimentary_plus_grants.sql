-- 課金していないカロナビ+の付与。
-- 本物の加入（calonavi_plus_entitlements）には書かない。売上にも、有効なサブスクの数にも入れない。
-- 既存の表には列を足さない。App Store の通知、KPI、Slack の利用者ログは触らない。
-- このファイルは行を入れない。対象の入れ方は supabase/manual/complimentary_plus_president_grants.sql。
-- 本番への適用は手動。2回実行しても失敗しない。

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table if not exists public.calonavi_plus_complimentary_grants (
  provider text not null,
  provider_id text not null,
  created_at timestamptz not null default pg_catalog.timezone('utc', pg_catalog.now()),
  primary key (provider, provider_id),
  constraint calonavi_plus_complimentary_grants_provider_pair check (
    provider = lower(provider)
    and provider = btrim(provider)
    and char_length(provider) between 1 and 32
    and char_length(provider_id) between 1 and 255
  )
);

comment on table public.calonavi_plus_complimentary_grants is
  '課金ではないカロナビ+。ログインの provider と provider_id（auth.identities の sub）だけを持つ。購入・返金・解約の行とは混ぜない。アプリはこの表を直接読まない。';

alter table public.calonavi_plus_complimentary_grants enable row level security;

revoke all on table public.calonavi_plus_complimentary_grants from public, anon, authenticated;
grant select, insert, update, delete on table public.calonavi_plus_complimentary_grants to service_role;

create or replace function private.user_has_complimentary_plus(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.identities i
    join public.calonavi_plus_complimentary_grants g
      on g.provider = i.provider
     and g.provider_id = i.provider_id
    where p_user_id is not null
      and i.user_id = p_user_id
  );
$$;

comment on function private.user_has_complimentary_plus(uuid) is
  'その利用者のログイン識別子が付与表にあれば true。課金の行は読まない。API には出さない。';

revoke all on function private.user_has_complimentary_plus(uuid) from public, anon, authenticated;
grant execute on function private.user_has_complimentary_plus(uuid) to service_role;

-- PostgREST から service_role だけが呼ぶ。引数に利用者番号を取るので、ログイン利用者には渡さない。
create or replace function public.user_has_complimentary_plus(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.user_has_complimentary_plus(p_user_id);
$$;

comment on function public.user_has_complimentary_plus(uuid) is
  'service_role 向け。ビルド13の写真・料理・食品検索が有料かを見るときに、加入行と別に OR する。ログイン利用者は呼べない。';

revoke all on function public.user_has_complimentary_plus(uuid) from public, anon, authenticated;
grant execute on function public.user_has_complimentary_plus(uuid) to service_role;

-- ログイン中の本人だけ。引数は無く、返すのは真偽だけ。識別子は返さない。
create or replace function public.current_complimentary_plus()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.user_has_complimentary_plus(auth.uid());
$$;

comment on function public.current_complimentary_plus() is
  '今のログインが付与対象なら true。authenticated が呼べるのはこれだけ。他人の識別子は受け取れない。';

revoke all on function public.current_complimentary_plus() from public, anon;
grant execute on function public.current_complimentary_plus() to authenticated, service_role;
