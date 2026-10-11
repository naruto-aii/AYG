-- rollback for 20261011063750_kpi_exclusion_by_identity
-- 集計の除外を、user_id と email だけの定義へ戻す。
-- provider と provider_id だけで指定した行は消える。
-- user_id、install_id、email がある行は残る。
-- アプリの表、RLS、退会処理の本文は触らない。

begin;

create or replace view kpi.excluded_user_ids
with (security_invoker = true) as
select x.user_id
from public.kpi_excluded_users x
where x.user_id is not null
union
select u.id
from public.kpi_excluded_users x
join public.users u on lower(u.email) = lower(x.email)
where x.email is not null;

comment on view kpi.excluded_user_ids is null;
comment on view kpi.excluded_install_ids is null;

revoke all on table kpi.excluded_user_ids from public, anon, authenticated;
grant select on table kpi.excluded_user_ids to service_role;

drop function if exists kpi.collect_excluded_user_ids();

delete from public.kpi_excluded_users
where num_nonnulls(user_id, install_id, email) = 0;

drop index if exists public.kpi_excluded_users_provider_key;

alter table public.kpi_excluded_users
  drop constraint if exists kpi_excluded_users_provider_pair;

alter table public.kpi_excluded_users
  drop constraint if exists kpi_excluded_users_target;

alter table public.kpi_excluded_users
  add constraint kpi_excluded_users_target
  check (num_nonnulls(user_id, install_id, email) >= 1);

alter table public.kpi_excluded_users
  drop column if exists provider_id,
  drop column if exists provider;

comment on table public.kpi_excluded_users is
  'KPI に数えない開発者・テスト用のアカウント。user_id、install_id（端末）、email（同じ Apple ID で作り直したアカウントも外す）のどれかで指定する。データは消さず、kpi スキーマのビューと日次集計・退会集計で外す。サーバーだけが読む・書く。';

commit;
