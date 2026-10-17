-- このファイルは本番に流さない。userlog のマイグレーションを単体で試すための最小の表。
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

create table if not exists public.users (
  id uuid primary key,
  email text,
  deleted_at timestamptz
);

create table if not exists public.profiles (
  user_id uuid primary key,
  display_name text
);

create table if not exists public.app_events (
  event_id uuid primary key,
  user_id uuid,
  event_name text not null,
  occurred_at timestamptz not null,
  install_id uuid
);

create table if not exists public.account_deletion_stats (
  deleted_on date not null,
  plus_status text not null,
  plan text not null,
  account_age_bucket text not null,
  deletions integer not null default 0,
  primary key (deleted_on, plus_status, plan, account_age_bucket)
);

create table if not exists public.store_server_notifications (
  notification_uuid uuid primary key,
  notification_type text not null,
  subtype text,
  verification_status text not null,
  user_id uuid,
  original_transaction_id text,
  signed_date timestamptz,
  received_at timestamptz not null default timezone('utc', now()),
  signed_payload text,
  decoded_payload jsonb
);

create table if not exists auth.sessions (
  id uuid primary key,
  user_id uuid,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.kpi_excluded_users (
  id bigint generated always as identity primary key,
  user_id uuid,
  install_id uuid,
  email text,
  reason text not null
);

create schema if not exists kpi;
create or replace view kpi.excluded_user_ids as
  select user_id from public.kpi_excluded_users where user_id is not null;
create or replace view kpi.excluded_install_ids as
  select install_id from public.kpi_excluded_users where install_id is not null;

grant select on public.users, public.profiles, public.kpi_excluded_users to service_role;
grant select on kpi.excluded_user_ids, kpi.excluded_install_ids to service_role;
grant usage on schema kpi to service_role;
