-- 自炊コーチと、AIで探すが共有する1日の回数。
-- 写真で登録は meal_photo_analyses を数える。ここには入れない。
-- 本番には適用しない。手順は supabase/functions/README.md。

begin;

create table if not exists public.ai_feature_uses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  feature text not null
    check (feature in ('cook_coach', 'ai_search')),
  provider text not null
    check (char_length(provider) between 1 and 40),
  model text not null
    check (char_length(model) between 1 and 80),
  input_tokens integer not null
    check (input_tokens >= 0),
  output_tokens integer not null
    check (output_tokens >= 0),
  cache_read_tokens integer not null default 0
    check (cache_read_tokens >= 0),
  cache_write_tokens integer not null default 0
    check (cache_write_tokens >= 0),
  estimated_cost_jpy numeric(14, 6) not null
    check (estimated_cost_jpy >= 0),
  latency_ms integer not null
    check (latency_ms >= 0),
  retried boolean not null default false,
  had_note boolean not null default false,
  meal_slot text
    check (meal_slot is null or meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  success boolean not null,
  error_code text
    check (error_code is null or char_length(error_code) between 1 and 40),
  advertising_use boolean not null default false
    check (advertising_use = false)
);

comment on table public.ai_feature_uses is
  '自炊コーチとAIで探すを1回数えた記録。食材、料理名、条件の文面、栄養の中身は入れない。写真で登録は meal_photo_analyses を見る。広告には使わない。';
comment on column public.ai_feature_uses.feature is
  'cook_coach は自炊コーチ。ai_search はAIで探す。写真で登録は入れない。';
comment on column public.ai_feature_uses.estimated_cost_jpy is
  'APIが返したトークン数と、関数の環境変数の単価から出した円。実請求そのものではない。';
comment on column public.ai_feature_uses.retried is
  '成分表で測ったあと、モデルをもう1回だけ呼んだとき true。';

create index if not exists ai_feature_uses_user_created_idx
  on public.ai_feature_uses (user_id, created_at desc);

alter table public.ai_feature_uses enable row level security;

drop policy if exists ai_feature_uses_select_own
  on public.ai_feature_uses;
create policy ai_feature_uses_select_own
  on public.ai_feature_uses for select
  using ((select auth.uid()) = user_id);

revoke all on table public.ai_feature_uses from anon, authenticated;
grant select on table public.ai_feature_uses to authenticated;

create or replace function public.delete_ai_feature_uses_on_account_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null
    and old.deleted_at is distinct from new.deleted_at
  then
    delete from public.ai_feature_uses where user_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.delete_ai_feature_uses_on_account_close()
  from public, anon, authenticated;

drop trigger if exists delete_ai_feature_uses_on_account_close
  on public.users;
create trigger delete_ai_feature_uses_on_account_close
  after update of deleted_at on public.users
  for each row
  execute function public.delete_ai_feature_uses_on_account_close();

create or replace view kpi.ai_feature_uses
  with (security_invoker = true) as
select t.*
from public.ai_feature_uses t
where not exists (
  select 1 from kpi.excluded_user_ids x where x.user_id = t.user_id
);

revoke all on table kpi.ai_feature_uses from public, anon, authenticated;
grant select on table kpi.ai_feature_uses to service_role;

-- 同じ食材と丸めた目標の献立。利用者の識別子は入れない。
create table if not exists public.cook_coach_cache (
  cache_key text primary key
    check (char_length(cache_key) = 64),
  response jsonb not null,
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null
);

comment on table public.cook_coach_cache is
  '同じ食材と丸めた目標kcal・PFCの献立。利用者の識別子、メモの生文以外の個人情報は入れない。';

create index if not exists cook_coach_cache_expires_idx
  on public.cook_coach_cache (expires_at);

alter table public.cook_coach_cache enable row level security;

revoke all on table public.cook_coach_cache from anon, authenticated;

commit;
