-- このファイルは本番に流さない。付与の関数を単体で試すための最小の表。
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

create table if not exists public.kpi_excluded_users (
  id bigint generated always as identity primary key,
  user_id uuid,
  install_id uuid,
  email text,
  provider text,
  provider_id text,
  reason text not null
);

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
