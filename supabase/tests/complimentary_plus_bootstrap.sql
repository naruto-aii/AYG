-- このファイルは本番に流さない。付与の関数を単体で試すための最小の表。
-- kpi_excluded_users は、リポジトリの 20261007112725 で作ってから、
-- 本番の 20261011070423 が足した provider / provider_id だけを足す。
-- 最初から列を足した別の表にはしない。KPI の関数とビューはここでは作らない。
create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;

alter role service_role bypassrls;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table if not exists auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  provider text not null,
  provider_id text not null
);

create table if not exists public.users (
  id uuid primary key,
  email text,
  deleted_at timestamptz
);

-- 20261007112725 の表。この時点では provider 列は無い。
create table public.kpi_excluded_users (
  id bigint generated always as identity primary key,
  user_id uuid,
  install_id uuid,
  email text,
  reason text not null,
  added_at timestamptz not null default timezone('utc', now()),
  constraint kpi_excluded_users_target check (num_nonnulls(user_id, install_id, email) >= 1)
);
create unique index kpi_excluded_users_user_id_key on public.kpi_excluded_users (user_id) where user_id is not null;
create unique index kpi_excluded_users_install_id_key on public.kpi_excluded_users (install_id) where install_id is not null;
create unique index kpi_excluded_users_email_key on public.kpi_excluded_users (lower(email)) where email is not null;
comment on table public.kpi_excluded_users is 'KPI に数えない開発者・テスト用のアカウント。user_id、install_id（端末）、email（同じ Apple ID で作り直したアカウントも外す）のどれかで指定する。データは消さず、kpi スキーマのビューと日次集計・退会集計で外す。サーバーだけが読む・書く。';
alter table public.kpi_excluded_users enable row level security;
revoke all on table public.kpi_excluded_users from public, anon, authenticated;
grant select, insert, update, delete on table public.kpi_excluded_users to service_role;

-- 本番の 20261011070423 のうち、表の定義だけ。集計関数は写さない。
alter table public.kpi_excluded_users
  add column if not exists provider text,
  add column if not exists provider_id text;

alter table public.kpi_excluded_users
  drop constraint if exists kpi_excluded_users_target;

alter table public.kpi_excluded_users
  drop constraint if exists kpi_excluded_users_provider_pair;

alter table public.kpi_excluded_users
  add constraint kpi_excluded_users_provider_pair check (
    (provider is null and provider_id is null)
    or (
      provider is not null
      and provider_id is not null
      and provider = lower(provider)
      and provider = btrim(provider)
      and char_length(provider) between 1 and 32
      and char_length(provider_id) between 1 and 255
    )
  );

alter table public.kpi_excluded_users
  add constraint kpi_excluded_users_target check (
    num_nonnulls(user_id, install_id, email) >= 1
    or (provider is not null and provider_id is not null)
  );

create unique index if not exists kpi_excluded_users_provider_key
  on public.kpi_excluded_users (provider, provider_id)
  where provider is not null;

comment on table public.kpi_excluded_users is
  'KPI に数えないアカウント。user_id、install_id、email、または provider と provider_id（auth.identities の sub）で指定する。データは消さず、集計だけから外す。サーバーだけが読む・書く。';

create table if not exists public.calonavi_plus_entitlements (
  user_id uuid not null,
  product_id text not null,
  status text not null,
  expires_at timestamptz
);

create table if not exists public.store_server_notifications (
  notification_uuid uuid primary key,
  notification_type text not null
);
