-- 写真で登録の利用記録。写真そのものは保存しない。
-- 本番には適用しない。手順は supabase/functions/README.md。
-- 既存の行は消さない。列も消さない。

begin;

create table if not exists public.meal_photo_analyses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  provider text not null
    check (char_length(provider) between 1 and 40),
  model text not null
    check (char_length(model) between 1 and 80),
  tier text not null
    check (tier in ('light', 'heavy')),
  input_tokens integer not null
    check (input_tokens >= 0),
  output_tokens integer not null
    check (output_tokens >= 0),
  estimated_cost_jpy numeric(14, 6) not null
    check (estimated_cost_jpy >= 0),
  latency_ms integer not null
    check (latency_ms >= 0),
  had_name boolean not null,
  had_amount boolean not null,
  success boolean not null,
  user_edited boolean,
  error_code text
    check (error_code is null or char_length(error_code) between 1 and 40),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.meal_photo_analyses is
  '写真で登録を1回呼んだ記録。利用者、モデル、トークン、推定費用、遅延、料理名と量の有無、成功、保存前に数値を直したか。写真と料理名と栄養の中身は入れない。広告には使わない。';
comment on column public.meal_photo_analyses.user_edited is
  '保存前に料理名、量、カロリー、PFCのどれかを変えたとき true。まだ保存していないときは null。';
comment on column public.meal_photo_analyses.estimated_cost_jpy is
  'APIが返したトークン数と、関数の環境変数の単価から出した円。実請求そのものではない。';

create index if not exists meal_photo_analyses_user_created_idx
  on public.meal_photo_analyses (user_id, created_at desc);

alter table public.meal_photo_analyses enable row level security;

drop policy if exists meal_photo_analyses_select_own
  on public.meal_photo_analyses;
create policy meal_photo_analyses_select_own
  on public.meal_photo_analyses for select
  using ((select auth.uid()) = user_id);

drop policy if exists meal_photo_analyses_update_own
  on public.meal_photo_analyses;
create policy meal_photo_analyses_update_own
  on public.meal_photo_analyses for update
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

-- 追加と削除は関数の service role だけ。本人は user_edited だけ変えられる。
revoke all on table public.meal_photo_analyses from anon, authenticated;
grant select, update on table public.meal_photo_analyses to authenticated;

create or replace function public.meal_photo_analyses_guard_update()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;
  if new.id is distinct from old.id
    or new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at
    or new.provider is distinct from old.provider
    or new.model is distinct from old.model
    or new.tier is distinct from old.tier
    or new.input_tokens is distinct from old.input_tokens
    or new.output_tokens is distinct from old.output_tokens
    or new.estimated_cost_jpy is distinct from old.estimated_cost_jpy
    or new.latency_ms is distinct from old.latency_ms
    or new.had_name is distinct from old.had_name
    or new.had_amount is distinct from old.had_amount
    or new.success is distinct from old.success
    or new.error_code is distinct from old.error_code
    or new.advertising_use is distinct from old.advertising_use
  then
    raise exception 'meal_photo_analyses: only user_edited can change';
  end if;
  return new;
end;
$$;

drop trigger if exists meal_photo_analyses_guard_update
  on public.meal_photo_analyses;
create trigger meal_photo_analyses_guard_update
  before update on public.meal_photo_analyses
  for each row
  execute function public.meal_photo_analyses_guard_update();

revoke all on function public.meal_photo_analyses_guard_update()
  from public, anon, authenticated;

-- 退会は users 行を消さず deleted_at を入れる。カスケードでは消えないので、ここで消す。
create or replace function public.delete_meal_photo_analyses_on_account_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null
    and old.deleted_at is distinct from new.deleted_at
  then
    delete from public.meal_photo_analyses where user_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.delete_meal_photo_analyses_on_account_close()
  from public, anon, authenticated;

drop trigger if exists delete_meal_photo_analyses_on_account_close
  on public.users;
create trigger delete_meal_photo_analyses_on_account_close
  after update of deleted_at on public.users
  for each row
  execute function public.delete_meal_photo_analyses_on_account_close();

-- KPI のビューだけ、開発者アカウントを外す。上限の集計は public の表を見る。
create or replace view kpi.meal_photo_analyses
  with (security_invoker = true) as
select t.*
from public.meal_photo_analyses t
where not exists (
  select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id
);

revoke all on table kpi.meal_photo_analyses from public, anon, authenticated;
grant select on table kpi.meal_photo_analyses to service_role;

-- 案内の記録に写真で登録を足す。本番の制約名が feature in でないこともある。
do $$
declare
  cons name;
begin
  select con.conname into cons
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'plus_funnel_events'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%feature%'
    and pg_get_constraintdef(con.oid) ilike '%coach%';
  if cons is not null then
    execute format(
      'alter table public.plus_funnel_events drop constraint %I',
      cons
    );
  end if;
end $$;

alter table public.plus_funnel_events
  drop constraint if exists plus_funnel_events_feature_check;

alter table public.plus_funnel_events
  add constraint plus_funnel_events_feature_check
  check (feature is null or feature in (
    'meal_template_limit',
    'workout_template_limit',
    'recent_foods',
    'memo',
    'widget',
    'siri',
    'coach',
    'photo_meal'
  ));

commit;
