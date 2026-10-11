-- KPI の除外を一か所にまとめる。
-- アプリの表は消さない。RLS、同期、課金のポリシーは変えない。
-- 除外の対象（ログインの識別子）はこのファイルに書かない。表へ入れるのは適用後の別作業。
--
-- 判定は kpi.collect_excluded_user_ids だけ。
--   * 表の user_id
--   * 表の email（public.users.email と一致）
--   * 表の provider + provider_id（auth.identities。Google / Apple の sub）
--   * public.users.deleted_at が入っている退会済み
--     （delete_own_account が auth のメールを書き換える前に立てる印。
--      メールの deleted+...@invalid.local では判定しない）
-- kpi.* の各ビューは、今までどおり kpi.excluded_user_ids を見る。条件は足さない。
-- 退会で残る anon_* は user_id を持たない。delete_own_account が identities を消す前に
-- この関数の結果を anon_subjects.kpi_excluded へ写す。ビューはそちらの真偽を見る。
--
-- install_id は別物。kpi.excluded_install_ids は表の install_id だけ。
-- ログインの除外からは広がらない。user_id と install_id の両方がある表だけ、両方を見る。

begin;

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

create or replace function kpi.collect_excluded_user_ids()
returns table (user_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select x.user_id
  from public.kpi_excluded_users x
  where x.user_id is not null
  union
  select u.id
  from public.kpi_excluded_users x
  join public.users u on lower(u.email) = lower(x.email)
  where x.email is not null
  union
  select i.user_id
  from public.kpi_excluded_users x
  join auth.identities i
    on i.provider = x.provider
   and i.provider_id = x.provider_id
  where x.provider is not null
    and x.provider_id is not null
  union
  select u.id
  from public.users u
  where u.deleted_at is not null
$$;

comment on function kpi.collect_excluded_user_ids() is
  'KPI から外す user_id。一覧、ログインの sub、退会の deleted_at をここだけで決める。アプリの認可には使わない。';

revoke all on function kpi.collect_excluded_user_ids() from public;
revoke all on function kpi.collect_excluded_user_ids() from anon, authenticated;
grant execute on function kpi.collect_excluded_user_ids() to service_role;

create or replace view kpi.excluded_user_ids
with (security_invoker = true) as
select ids.user_id
from kpi.collect_excluded_user_ids() ids;

comment on view kpi.excluded_user_ids is
  'kpi.collect_excluded_user_ids の結果。各 kpi ビューはこれを見る。';

comment on view kpi.excluded_install_ids is
  '表に書いた install_id だけ。ログインの除外とは独立で、自動では増えない。user_id と install_id の両方を持つ表だけ、両方を見る。';

revoke all on table kpi.excluded_user_ids from public, anon, authenticated;
grant select on table kpi.excluded_user_ids to service_role;

commit;
