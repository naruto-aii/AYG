-- 20:00（日本時間）の通知。端末トークンと、送った日の記録だけを足す。
-- 食事・運動・目標の行は消さない。アカウント削除の関数は変えない。
-- 戻す手順: supabase/rollback/20261004120000_daily_calorie_reminder_down.sql

begin;

alter table public.health_snapshots
  add column if not exists activity_excess_kcal double precision,
  add column if not exists activity_excess_on date;

comment on column public.health_snapshots.activity_excess_kcal is
  'アプリがその日に計算した Health の上乗せ kcal。20:00 の通知は、この日付が日本の当日と一致するときだけ使う。';

comment on column public.health_snapshots.activity_excess_on is
  'activity_excess_kcal を計算した端末の暦日。日本の当日と一致するときだけ通知に使う。';

create table if not exists public.user_push_tokens (
  user_id uuid not null references public.users (id) on delete cascade,
  device_token text not null check (char_length(device_token) between 32 and 200),
  platform text not null check (platform = 'ios'),
  apns_environment text not null check (apns_environment in ('sandbox', 'production')),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, device_token)
);

comment on table public.user_push_tokens is
  'ログイン中の iOS へ 20:00 の通知を届ける APNs トークン。食事の中身は入れない。';

create index if not exists user_push_tokens_user_updated_idx
  on public.user_push_tokens (user_id, updated_at desc);

drop trigger if exists set_user_push_tokens_updated_at on public.user_push_tokens;
create trigger set_user_push_tokens_updated_at
  before update on public.user_push_tokens
  for each row execute function public.set_updated_at();

alter table public.user_push_tokens enable row level security;

drop policy if exists user_push_tokens_select_own on public.user_push_tokens;
create policy user_push_tokens_select_own
  on public.user_push_tokens for select
  using ((select auth.uid()) = user_id);

drop policy if exists user_push_tokens_insert_own on public.user_push_tokens;
create policy user_push_tokens_insert_own
  on public.user_push_tokens for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists user_push_tokens_update_own on public.user_push_tokens;
create policy user_push_tokens_update_own
  on public.user_push_tokens for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists user_push_tokens_delete_own on public.user_push_tokens;
create policy user_push_tokens_delete_own
  on public.user_push_tokens for delete
  using ((select auth.uid()) = user_id);

revoke all on table public.user_push_tokens from anon, authenticated;
grant select, insert, update, delete on table public.user_push_tokens to authenticated;

create table if not exists public.daily_reminder_deliveries (
  user_id uuid not null references public.users (id) on delete cascade,
  japan_date date not null,
  sent_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, japan_date)
);

comment on table public.daily_reminder_deliveries is
  '日本の暦日ごとに、20:00 の通知を1人1通だけにした記録。本文は保存しない。';

alter table public.daily_reminder_deliveries enable row level security;

revoke all on table public.daily_reminder_deliveries from anon, authenticated;

-- logged_at は端末の壁時計をオフセット無しで保存し、timestamptz はそれを UTC として持つ。
-- 日本の暦日との比較は、UTC の日付成分を使う。
create or replace function public.daily_calorie_reminder_page(
  p_japan_date date,
  p_limit integer,
  p_after_user_id uuid
)
returns table (
  user_id uuid,
  device_token text,
  apns_environment text,
  meal_count bigint,
  exercise_count bigint,
  food_kcal double precision,
  alcohol_kcal double precision,
  exercise_net_kcal double precision,
  goal_kcal double precision,
  weight_kg double precision,
  use_health_integration boolean,
  activity_level text,
  active_energy_burned_kcal double precision,
  activity_excess_kcal double precision,
  activity_excess_on date,
  birth_date timestamptz,
  gender text,
  height_cm double precision
)
language sql
stable
security definer
set search_path = public
as $$
  with tokens as (
    select distinct on (t.user_id)
      t.user_id,
      t.device_token,
      t.apns_environment
    from public.user_push_tokens t
    join public.users u on u.id = t.user_id
    where u.deleted_at is null
    order by t.user_id, t.updated_at desc, t.device_token
  ),
  page as (
    select *
    from tokens
    where p_after_user_id is null or tokens.user_id > p_after_user_id
    order by user_id
    limit least(greatest(coalesce(p_limit, 200), 1), 500)
  )
  select
    page.user_id,
    page.device_token,
    page.apns_environment,
    (
      select count(*)
      from public.food_entries f
      where f.user_id = page.user_id
        and (f.logged_at at time zone 'UTC')::date = p_japan_date
    ) as meal_count,
    (
      select count(*)
      from public.exercise_entries e
      where e.user_id = page.user_id
        and (e.logged_at at time zone 'UTC')::date = p_japan_date
    ) as exercise_count,
    (
      select coalesce(sum(
        coalesce(f.kcal_per_unit, 0) * (
          coalesce(f.consumed_amount, f.quantity, 1)
          / case
              when f.base_amount is null or f.base_amount = 0 then 1
              else f.base_amount
            end
        )
      ), 0)
      from public.food_entries f
      where f.user_id = page.user_id
        and (f.logged_at at time zone 'UTC')::date = p_japan_date
    ) as food_kcal,
    (
      select coalesce(sum(a.total_calories), 0)
      from public.alcohol_entries a
      where a.user_id = page.user_id
        and (a.consumed_at at time zone 'UTC')::date = p_japan_date
    ) as alcohol_kcal,
    (
      select coalesce(sum(
        case
          when e.net_kcal is not null and e.net_kcal = e.net_kcal and e.net_kcal >= 0
            then e.net_kcal
          when e.gross_kcal is not null
            and e.met_value is not null
            and e.gross_kcal = e.gross_kcal
            and e.met_value = e.met_value
            and e.met_value > 0
            then case
              when e.met_value - 1 <= 0 then 0
              else e.gross_kcal * (e.met_value - 1) / e.met_value
            end
          else e.burned_kcal
        end
      ), 0)
      from public.exercise_entries e
      where e.user_id = page.user_id
        and (e.logged_at at time zone 'UTC')::date = p_japan_date
    ) as exercise_net_kcal,
    case
      when s.calorie_target_mode = 'manual'
        and s.manual_target_kcal is not null
        and s.manual_target_kcal > 0
        and s.manual_protein_g is not null
        and s.manual_fat_g is not null
        and s.manual_carb_g is not null
        then s.manual_target_kcal
      else coalesce(s.auto_food_target_kcal, 0)
    end as goal_kcal,
    p.weight_kg,
    coalesce(s.use_health_integration, false) as use_health_integration,
    s.activity_level,
    h.active_energy_burned_kcal,
    h.activity_excess_kcal,
    h.activity_excess_on,
    p.birth_date,
    p.gender,
    p.height_cm
  from page
  left join public.profiles p on p.user_id = page.user_id
  left join public.nutrition_settings s on s.user_id = page.user_id
  left join public.health_snapshots h on h.user_id = page.user_id;
$$;

create or replace function public.claim_daily_calorie_reminder(
  p_user_id uuid,
  p_japan_date date
)
returns boolean
language sql
volatile
security definer
set search_path = public
as $$
  with inserted as (
    insert into public.daily_reminder_deliveries (user_id, japan_date)
    values (p_user_id, p_japan_date)
    on conflict do nothing
    returning 1
  )
  select exists (select 1 from inserted);
$$;

create or replace function public.release_daily_calorie_reminder(
  p_user_id uuid,
  p_japan_date date
)
returns void
language sql
volatile
security definer
set search_path = public
as $$
  delete from public.daily_reminder_deliveries
  where user_id = p_user_id
    and japan_date = p_japan_date;
$$;

revoke all on function public.daily_calorie_reminder_page(date, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.claim_daily_calorie_reminder(uuid, date)
  from public, anon, authenticated;
revoke all on function public.release_daily_calorie_reminder(uuid, date)
  from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select, insert, update, delete on table public.user_push_tokens to service_role;
    grant select, insert, update, delete on table public.daily_reminder_deliveries to service_role;
    grant execute on function public.daily_calorie_reminder_page(date, integer, uuid) to service_role;
    grant execute on function public.claim_daily_calorie_reminder(uuid, date) to service_role;
    grant execute on function public.release_daily_calorie_reminder(uuid, date) to service_role;
  end if;
end
$$;

commit;
