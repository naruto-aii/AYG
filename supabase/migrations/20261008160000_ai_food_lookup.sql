-- AIで探すの利用記録と、推定の期限つきキャッシュ。
-- 食品データベースへチェーンの数値を一括では入れない。
-- キャッシュは食品の一覧としては出さない。
-- 本番には適用しない。手順は supabase/functions/README.md。

begin;

create table if not exists public.meal_text_lookups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  provider text not null
    check (char_length(provider) between 1 and 40),
  model text not null
    check (char_length(model) between 1 and 80),
  input_tokens integer not null
    check (input_tokens >= 0),
  output_tokens integer not null
    check (output_tokens >= 0),
  estimated_cost_jpy numeric(14, 6) not null
    check (estimated_cost_jpy >= 0),
  latency_ms integer not null
    check (latency_ms >= 0),
  cache_hit boolean not null,
  success boolean not null,
  saved boolean,
  user_edited boolean,
  error_code text
    check (error_code is null or char_length(error_code) between 1 and 40),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.meal_text_lookups is
  'AIで探すを1回呼んだ記録。利用者、モデル、トークン、推定費用、遅延、キャッシュに当たったか、成功、保存したか、保存前に数値を直したか。検索語と栄養の中身は入れない。広告には使わない。';
comment on column public.meal_text_lookups.saved is
  'この推定から食事を1件保存したとき true。まだ保存していないときは null。';
comment on column public.meal_text_lookups.user_edited is
  '保存前に名前、量、カロリー、PFCのどれかを変えたとき true。まだ保存していないときは null。';
comment on column public.meal_text_lookups.estimated_cost_jpy is
  'APIが返したトークン数と、関数の環境変数の単価から出した円。キャッシュのときは 0。実請求そのものではない。';

create index if not exists meal_text_lookups_user_created_idx
  on public.meal_text_lookups (user_id, created_at desc);

alter table public.meal_text_lookups enable row level security;

drop policy if exists meal_text_lookups_select_own
  on public.meal_text_lookups;
create policy meal_text_lookups_select_own
  on public.meal_text_lookups for select
  using ((select auth.uid()) = user_id);

drop policy if exists meal_text_lookups_update_own
  on public.meal_text_lookups;
create policy meal_text_lookups_update_own
  on public.meal_text_lookups for update
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and advertising_use = false
  );

revoke all on table public.meal_text_lookups from anon, authenticated;
grant select, update on table public.meal_text_lookups to authenticated;

create or replace function public.meal_text_lookups_guard_update()
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
    or new.input_tokens is distinct from old.input_tokens
    or new.output_tokens is distinct from old.output_tokens
    or new.estimated_cost_jpy is distinct from old.estimated_cost_jpy
    or new.latency_ms is distinct from old.latency_ms
    or new.cache_hit is distinct from old.cache_hit
    or new.success is distinct from old.success
    or new.error_code is distinct from old.error_code
    or new.advertising_use is distinct from old.advertising_use
  then
    raise exception 'meal_text_lookups: only saved and user_edited can change';
  end if;
  return new;
end;
$$;

drop trigger if exists meal_text_lookups_guard_update
  on public.meal_text_lookups;
create trigger meal_text_lookups_guard_update
  before update on public.meal_text_lookups
  for each row
  execute function public.meal_text_lookups_guard_update();

revoke all on function public.meal_text_lookups_guard_update()
  from public, anon, authenticated;

create or replace function public.delete_meal_text_lookups_on_account_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null
    and old.deleted_at is distinct from new.deleted_at
  then
    delete from public.meal_text_lookups where user_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.delete_meal_text_lookups_on_account_close()
  from public, anon, authenticated;

drop trigger if exists delete_meal_text_lookups_on_account_close
  on public.users;
create trigger delete_meal_text_lookups_on_account_close
  after update of deleted_at on public.users
  for each row
  execute function public.delete_meal_text_lookups_on_account_close();

create or replace view kpi.meal_text_lookups
  with (security_invoker = true) as
select t.*
from public.meal_text_lookups t
where not exists (
  select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id
);

revoke all on table kpi.meal_text_lookups from public, anon, authenticated;
grant select on table kpi.meal_text_lookups to service_role;

-- 推定のキャッシュ。利用者 ID は持たない。食品マスタではない。
create table if not exists public.ai_food_estimate_cache (
  query_key text primary key
    check (char_length(query_key) between 1 and 80),
  model text not null
    check (char_length(model) between 1 and 80),
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null,
  candidates jsonb not null
);

comment on table public.ai_food_estimate_cache is
  'AIで探すの推定キャッシュ。正規化した検索語、モデル、期限、推定。食品データベースではなく、チェーンの栄養成分の一括取り込みでもない。画面の食品一覧には出さない。';

alter table public.ai_food_estimate_cache enable row level security;

revoke all on table public.ai_food_estimate_cache from anon, authenticated;

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
    'photo_meal',
    'ai_food_lookup'
  ));

commit;
