-- 登録済みのユーザー名だけを、後から人数を集計できる表へ写す。
-- アプリが読む保存先は profiles.display_name のまま。この表は写しです。
-- 既存の行は削除しない。列も消さない。truncate しない。
-- 性別、生年月日、身長、体重、消費カロリー、レシート本文、購入トークンは列にしない。
-- このファイルをこのエージェントから本番へは適用しない。

begin;

comment on column public.profiles.display_name is
  '利用者が登録したユーザー名。未入力は NULL。1〜40文字のときだけ account_display_names へ同じ文字列を写す。ヘルスケアの数値は写さない。この列の既存の値は消さない。';

comment on column public.profiles.gender is
  '健康情報であり、機微な情報でもある。消費カロリーの計算に使う。広告には使わない。account_display_names には入れない。';

comment on column public.profiles.birth_date is
  'ヘルスケア由来の生年月日。広告には使わない。';

comment on column public.profiles.height_cm is
  'ヘルスケア由来の身長。広告には使わない。';

comment on column public.profiles.weight_kg is
  'ヘルスケア由来の体重。広告には使わない。';

comment on table public.health_snapshots is
  'アクティブエネルギーと体重のスナップショット。ヘルスケア由来。使い道はアプリの機能と分析。広告には使わない。';

comment on table public.calonavi_plus_entitlements is
  'カロナビ+の購入状態。商品ID、期限、状態だけを残し、後から有効人数を集計する。レシート本文とトークンは置かない。使い道はアプリの機能と分析。広告には使わない。';

comment on table public.food_search_queries is
  '食品を探すために、今の検索が受け取った語。公式食品、公開食品、マイ食品、食事テンプレート。ヘルスケアの測定値は入れない。使い道はアプリの機能と分析。広告には使わない。';

comment on table public.exercise_search_queries is
  '運動種目を探すために、今の検索が受け取った語。種目カタログと運動テンプレート。HealthKit の測定値や消費カロリーは入れない。使い道はアプリの機能と分析。広告には使わない。';

comment on table public.app_screen_actions is
  '今の画面操作。タブの表示と選択、初回の食事案内、ホームウィジェットとロック画面のボタン。画面名と操作だけ。体重、消費カロリー、ヘルスケアの数値は入れない。使い道はアプリの機能と分析。広告には使わない。';

create schema if not exists internal;

revoke all on schema internal from public;
revoke all on schema internal from anon;
revoke all on schema internal from authenticated;

create table if not exists public.account_display_names (
  user_id uuid primary key
    references public.profiles (user_id) on delete cascade,
  display_name text not null
    check (char_length(display_name) between 1 and 40),
  advertising_use boolean not null default false
    check (advertising_use = false),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.account_display_names is
  '登録済みユーザー名の写し。後から名前のある人数を集計する。性別、生年月日、身長、体重、レシート、トークンは置かない。使い道はアプリの機能と分析。広告には使わない。';

comment on column public.account_display_names.display_name is
  'profiles.display_name と同じ文字列。1〜40文字。';

comment on column public.account_display_names.advertising_use is
  '常に false。広告利用の印は付けられない。';

create index if not exists account_display_names_updated_at_idx
  on public.account_display_names (updated_at desc);

drop trigger if exists set_account_display_names_updated_at
  on public.account_display_names;
create trigger set_account_display_names_updated_at
  before update on public.account_display_names
  for each row execute function public.set_updated_at();

alter table public.account_display_names enable row level security;

drop policy if exists account_display_names_select_own
  on public.account_display_names;
create policy account_display_names_select_own
  on public.account_display_names for select
  using ((select auth.uid()) = user_id);

revoke all on table public.account_display_names from anon, authenticated;
grant select on table public.account_display_names to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select on table public.account_display_names to service_role;
  end if;
end
$$;

-- プロフィール保存のたびに名前だけを写す。クライアントはこの表へ直接書けない。
create or replace function internal.sync_account_display_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.display_name is null then
    delete from public.account_display_names where user_id = new.user_id;
    return new;
  end if;

  -- アプリが受け付けない長さは写さない。プロフィールの保存自体は止めない。
  if char_length(new.display_name) not between 1 and 40 then
    return new;
  end if;

  insert into public.account_display_names (
    user_id,
    display_name,
    advertising_use
  )
  values (new.user_id, new.display_name, false)
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        advertising_use = false;

  return new;
end;
$$;

revoke all on function internal.sync_account_display_name() from public;
revoke all on function internal.sync_account_display_name() from anon;
revoke all on function internal.sync_account_display_name() from authenticated;
grant execute on function internal.sync_account_display_name() to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function internal.sync_account_display_name() to service_role;
  end if;
end
$$;

drop trigger if exists sync_account_display_name on public.profiles;
create trigger sync_account_display_name
  after insert or update of display_name on public.profiles
  for each row execute function internal.sync_account_display_name();

-- すでに profiles にある名前だけを写す。プロフィールの行は消さない。
insert into public.account_display_names (user_id, display_name)
select user_id, display_name
from public.profiles
where display_name is not null
  and char_length(display_name) between 1 and 40
on conflict (user_id) do update
  set display_name = excluded.display_name,
      advertising_use = false;

commit;
