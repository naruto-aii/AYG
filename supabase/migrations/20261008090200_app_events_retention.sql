-- =====================================================================
-- 操作の記録の保存期間と、購入と利用者の対応表（追加だけ）
-- 置き場所: supabase/migrations/20261008090200_app_events_retention.sql
--
-- 本番には適用しない。社長の承認後に、20261008090000 と必ず同じ作業で適用する。
-- アプリは onConflict 'event_id,occurred_at' で upsert する。90000 だけだと主キーは
-- event_id だけで、このファイルが (event_id, occurred_at) に変えるまで送信は失敗する。
-- このファイルは削除を始めない。定期実行は 20261008090300 に分けた。
-- このファイルは pg_cron を有効にしない。
--
-- 方針
--   * 既存の表・列・データは消さない。app_events は、同じ行を月ごとの表へ移す。
--   * 生の記録は 90 日分だけ残す。90 日より古い月は、集計したあと表ごと消す。
--   * 利用者を含まない日次の集計は 2 年残す。
--   * 利用者ごとの日の要約は 13 か月残し、退会時に消す。
--   * 購入の取引番号と利用者の対応は、生の記録とは別の表に残す。
--     サーバーだけが書き、利用者は自分の行だけ読める。退会時に消す。
--   * delete_own_account は、これまでの処理を残したまま、新しい表の削除を足す。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 購入の取引番号と利用者の対応
-- ---------------------------------------------------------------------
create table if not exists public.store_original_transactions (
  original_transaction_id text primary key,
  user_id uuid not null references public.users(id),
  product_id text,
  first_seen_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  constraint store_original_transactions_id_length check (
    char_length(original_transaction_id) between 1 and 128
  ),
  constraint store_original_transactions_product_length check (
    product_id is null or char_length(product_id) <= 128
  )
);

comment on table public.store_original_transactions is
  'App Store の originalTransactionId と利用者の対応。サーバーだけが書く。生の app_events が消えても通知の照合に使う。退会すると消す。広告には使わない。';

create index if not exists store_original_transactions_user_idx
  on public.store_original_transactions (user_id);

alter table public.store_original_transactions enable row level security;
revoke all on table public.store_original_transactions from anon, authenticated;
grant select on table public.store_original_transactions to authenticated;

drop policy if exists store_original_transactions_select_own
  on public.store_original_transactions;
create policy store_original_transactions_select_own
  on public.store_original_transactions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.remember_store_original_transaction(
  p_original_transaction_id text,
  p_user_id uuid,
  p_product_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  tx text := nullif(btrim(p_original_transaction_id), '');
  product text := nullif(btrim(p_product_id), '');
begin
  if tx is null or p_user_id is null or char_length(tx) > 128 then
    return;
  end if;
  if product is not null and char_length(product) > 128 then
    product := null;
  end if;
  -- 退会済みの利用者へは、対応を作り直さない。
  if exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and u.deleted_at is not null
  ) then
    return;
  end if;
  insert into public.store_original_transactions (
    original_transaction_id,
    user_id,
    product_id
  )
  values (tx, p_user_id, product)
  on conflict (original_transaction_id) do update
    set last_seen_at = timezone('utc', now()),
        product_id = coalesce(
          excluded.product_id,
          public.store_original_transactions.product_id
        )
    where public.store_original_transactions.user_id = excluded.user_id;
end;
$function$;

revoke all on function public.remember_store_original_transaction(text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.remember_store_original_transaction(text, uuid, text)
  to service_role;

-- ---------------------------------------------------------------------
-- 2. 消す前の集計
-- ---------------------------------------------------------------------
create table if not exists public.app_event_daily_totals (
  day date not null,
  event_name text not null,
  origin text not null,
  event_count bigint not null,
  primary key (day, event_name, origin),
  constraint app_event_daily_totals_count_positive check (event_count >= 0)
);

comment on table public.app_event_daily_totals is
  '利用者を含まない日次の集計。日付は UTC。2 年残し、それより古い行は消す。個人の識別子は置かない。';

create table if not exists public.app_event_user_days (
  user_id uuid not null,
  day date not null,
  event_count integer not null,
  events jsonb not null,
  primary key (user_id, day),
  constraint app_event_user_days_count_positive check (event_count >= 0),
  constraint app_event_user_days_events_object check (jsonb_typeof(events) = 'object')
);

comment on table public.app_event_user_days is
  '利用者ごとの日の要約。イベント名と件数だけ。13 か月残し、退会すると消す。日付は UTC。';

alter table public.app_event_daily_totals enable row level security;
alter table public.app_event_user_days enable row level security;
revoke all on table public.app_event_daily_totals from anon, authenticated;
revoke all on table public.app_event_user_days from anon, authenticated;
grant select on table public.app_event_user_days to authenticated;

drop policy if exists app_event_user_days_select_own on public.app_event_user_days;
create policy app_event_user_days_select_own
  on public.app_event_user_days
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create table if not exists public.app_event_partitions (
  partition_name text primary key,
  range_start timestamptz not null,
  range_end timestamptz not null
);

alter table public.app_event_partitions enable row level security;
revoke all on table public.app_event_partitions from anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. 月の表を作る
--    新しい表は、作った瞬間に authenticated へ select/insert/update/delete が
--    付く（既定の権限）。親の RLS は子の表を直接開いたときには効かないので、
--    子の表でも RLS を有効にし、挿入以外の権限を外す。
-- ---------------------------------------------------------------------
create or replace function public.lock_app_events_partition(p_partition_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_partition_name is null or p_partition_name !~ '^app_events(_default|_y[0-9]{4}m[0-9]{2})$' then
    raise exception 'unexpected app_events partition name';
  end if;
  execute format('alter table public.%I enable row level security', p_partition_name);
  execute format(
    'revoke all on table public.%I from public, anon, authenticated',
    p_partition_name
  );
  execute format('grant insert on table public.%I to authenticated', p_partition_name);
  execute format('drop policy if exists app_events_insert_own on public.%I', p_partition_name);
  execute format(
    'create policy app_events_insert_own on public.%I for insert to authenticated with check (user_id = (select auth.uid()) and advertising_use = false)',
    p_partition_name
  );
end;
$function$;

revoke all on function public.lock_app_events_partition(text)
  from public, anon, authenticated;
grant execute on function public.lock_app_events_partition(text) to service_role;

create or replace function public.ensure_app_events_partition(p_month date)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  child_name text;
  child_start timestamptz;
  child_end timestamptz;
begin
  if p_month is null then
    return;
  end if;
  child_start := (date_trunc('month', p_month::timestamp) at time zone 'utc');
  child_end := child_start + interval '1 month';
  child_name := format(
    'app_events_y%sm%s',
    to_char(child_start at time zone 'utc', 'YYYY'),
    to_char(child_start at time zone 'utc', 'MM')
  );
  if to_regclass('public.' || child_name) is null then
    execute format(
      'create table public.%I partition of public.app_events for values from (%L) to (%L)',
      child_name,
      child_start,
      child_end
    );
    perform public.lock_app_events_partition(child_name);
  end if;
  insert into public.app_event_partitions (partition_name, range_start, range_end)
  values (child_name, child_start, child_end)
  on conflict (partition_name) do nothing;
end;
$function$;

revoke all on function public.ensure_app_events_partition(date)
  from public, anon, authenticated;
grant execute on function public.ensure_app_events_partition(date) to service_role;

create or replace function public.app_events_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  tx text;
begin
  -- 行の振り分けは、このトリガーが動くより前に終わっている。
  -- ここで月の表を作ると、受け皿への挿入が失敗する。
  -- 月の表は変換時と maintain_app_events が先に作る。
  if new.event_name = 'entitlement_observed' and new.user_id is not null then
    tx := nullif(btrim(new.props->>'original_transaction_id'), '');
    if tx is not null then
      begin
        perform public.remember_store_original_transaction(
          tx,
          new.user_id,
          nullif(btrim(new.props->>'product_id'), '')
        );
      exception
        when others then
          raise notice 'store original transaction capture skipped: %', sqlerrm;
      end;
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function public.app_events_before_insert()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. 既存の app_events を月ごとの表へ移す。行は残す。
-- ---------------------------------------------------------------------
create or replace function public.convert_app_events_to_monthly()
returns void
language plpgsql
security definer
set search_path = ''
as $convert$
declare
  month_start date;
  constraint_name text;
  constraint_names text[];
begin
  if exists (
    select 1
    from pg_partitioned_table
    where partrelid = 'public.app_events'::regclass
  ) then
    return;
  end if;

  alter table public.app_events rename to app_events_plain;

  select coalesce(array_agg(
    con.conname
    order by case con.contype
      when 'f' then 0
      when 'p' then 1
      when 'u' then 2
      else 3
    end
  ), '{}'::text[])
  into constraint_names
  from pg_constraint con
  where con.conrelid = 'public.app_events_plain'::regclass
    and con.contype in ('p', 'u', 'f', 'c');

  foreach constraint_name in array constraint_names loop
    execute format(
      'alter table public.app_events_plain drop constraint %I',
      constraint_name
    );
  end loop;

  drop index if exists public.app_events_user_occurred_idx;
  drop index if exists public.app_events_name_occurred_idx;
  drop index if exists public.app_events_install_stream_seq_idx;
  drop index if exists public.app_events_received_idx;

  create table public.app_events (
    event_id uuid not null,
    user_id uuid not null references public.users(id) on delete cascade,
    event_name text not null,
    occurred_at timestamptz not null,
    client_sent_at timestamptz,
    received_at timestamptz not null default timezone('utc', now()),
    origin text not null,
    install_id uuid not null,
    session_id uuid,
    stream text not null,
    sequence_number bigint not null,
    app_version text not null,
    app_build text not null,
    os_version text,
    device_model text,
    locale text,
    time_zone text,
    schema_version smallint not null default 1,
    props jsonb not null default '{}'::jsonb,
    advertising_use boolean not null default false,
    primary key (event_id, occurred_at),
    constraint app_events_event_name_format check (event_name ~ '^[a-z][a-z0-9_]{1,62}$'),
    constraint app_events_origin_format check (origin ~ '^[a-z][a-z0-9_]{1,30}$'),
    constraint app_events_stream_format check (stream ~ '^[a-z][a-z0-9_]{1,30}$'),
    constraint app_events_sequence_positive check (sequence_number > 0),
    constraint app_events_props_object check (jsonb_typeof(props) = 'object'),
    constraint app_events_props_size check (octet_length(props::text) <= 8192),
    constraint app_events_text_lengths check (
      char_length(app_version) <= 32
      and char_length(app_build) <= 32
      and char_length(coalesce(os_version, '')) <= 32
      and char_length(coalesce(device_model, '')) <= 64
      and char_length(coalesce(locale, '')) <= 35
      and char_length(coalesce(time_zone, '')) <= 64
    ),
    constraint app_events_advertising_use_check check (advertising_use = false)
  ) partition by range (occurred_at);

  comment on table public.app_events is
    'アプリ・ウィジェット・Siri の行動。月ごとに表を分ける。生データは 90 日より古い月を表ごと消す。event_id と occurred_at で重複を除く。広告には使わない。';

  create table public.app_events_default partition of public.app_events default;
  perform public.lock_app_events_partition('app_events_default');

  alter table public.app_events enable row level security;
  revoke all on table public.app_events from anon, authenticated;
  grant insert on table public.app_events to authenticated;

  drop policy if exists app_events_insert_own on public.app_events;
  create policy app_events_insert_own
    on public.app_events
    for insert
    to authenticated
    with check (user_id = (select auth.uid()) and advertising_use = false);

  create index app_events_user_occurred_idx
    on public.app_events (user_id, occurred_at desc);
  create index app_events_name_occurred_idx
    on public.app_events (event_name, occurred_at desc);
  create index app_events_install_stream_seq_idx
    on public.app_events (install_id, stream, sequence_number);
  create index app_events_received_idx
    on public.app_events (received_at);

  drop trigger if exists app_events_before_insert on public.app_events;
  create trigger app_events_before_insert
    before insert on public.app_events
    for each row
    execute function public.app_events_before_insert();

  for month_start in
    select distinct date_trunc('month', occurred_at at time zone 'utc')::date
    from public.app_events_plain
  loop
    perform public.ensure_app_events_partition(month_start);
  end loop;

  insert into public.app_events
  select * from public.app_events_plain;

  -- ビューは改名前の表を指したままなので、消す前に新しい表へ付け替える。
  -- 完全な定義はこの関数のあとで付け直す。
  execute $view$
    create or replace view public.app_events_including_legacy
    with (security_invoker = true) as
    select
      e.event_id, e.user_id, e.event_name, e.occurred_at, e.received_at,
      e.origin, e.props, 'app_events'::text as data_source
    from public.app_events e
  $view$;
  execute $view$
    create or replace view public.app_event_sequence_gaps
    with (security_invoker = true) as
    select
      e.install_id,
      e.user_id,
      e.stream,
      e.sequence_number as previous_sequence_number,
      e.sequence_number,
      0::bigint as missing_count,
      e.occurred_at
    from public.app_events e
    where false
  $view$;

  drop table public.app_events_plain;
end;
$convert$;

select public.convert_app_events_to_monthly();
drop function public.convert_app_events_to_monthly();

do $months$
declare
  i integer;
  month_start date := date_trunc('month', timezone('utc', now()))::date;
begin
  for i in -1..3 loop
    perform public.ensure_app_events_partition(
      (month_start + make_interval(months => i))::date
    );
  end loop;
end;
$months$;

drop trigger if exists app_events_before_insert on public.app_events;
create trigger app_events_before_insert
  before insert on public.app_events
  for each row
  execute function public.app_events_before_insert();

-- ビューは移したあとの app_events を見る。中身は 20261008090000 と同じ。
create or replace view public.app_events_including_legacy
with (security_invoker = true) as
select
  e.event_id,
  e.user_id,
  e.event_name,
  e.occurred_at,
  e.received_at,
  e.origin,
  e.props,
  'app_events'::text as data_source
from public.app_events e
union all
select
  a.id,
  a.user_id,
  case
    when a.action = 'open' then 'screen_view'
    when a.action = 'select' then 'tab_select'
    when a.action = 'meal_button' then 'widget_tap'
    else 'share_tap'
  end,
  a.acted_at,
  a.acted_at,
  case a.screen
    when 'home_widget' then 'home_widget'
    when 'lock_screen' then 'lock_widget'
    else 'app'
  end,
  jsonb_build_object(
    'screen', a.screen,
    'action', a.action,
    'legacy', true,
    'time_is_import_time', a.action = 'meal_button'
  ),
  'app_screen_actions'::text
from public.app_screen_actions a
where not exists (select 1 from public.app_events e2 where e2.event_id = a.id)
union all
select
  q.id,
  q.user_id,
  'food_search',
  q.searched_at,
  q.searched_at,
  'app',
  jsonb_build_object('source', q.source, 'query', q.query_text, 'legacy', true),
  'food_search_queries'::text
from public.food_search_queries q
where not exists (select 1 from public.app_events e3 where e3.event_id = q.id)
union all
select
  x.id,
  x.user_id,
  'exercise_search',
  x.searched_at,
  x.searched_at,
  'app',
  jsonb_build_object('source', x.source, 'query', x.query_text, 'legacy', true),
  'exercise_search_queries'::text
from public.exercise_search_queries x
where not exists (select 1 from public.app_events e4 where e4.event_id = x.id);

revoke all on table public.app_events_including_legacy from anon, authenticated;

create or replace view public.app_event_sequence_gaps
with (security_invoker = true) as
select
  s.install_id,
  s.user_id,
  s.stream,
  s.previous_sequence_number,
  s.sequence_number,
  s.sequence_number - s.previous_sequence_number - 1 as missing_count,
  s.occurred_at
from (
  select
    install_id,
    user_id,
    stream,
    sequence_number,
    occurred_at,
    lag(sequence_number) over (
      partition by install_id, stream order by sequence_number
    ) as previous_sequence_number
  from public.app_events
) s
where s.previous_sequence_number is not null
  and s.sequence_number - s.previous_sequence_number > 1;

revoke all on table public.app_event_sequence_gaps from anon, authenticated;

-- 受け皿から月の表へ移すときの作業用。トランザクションの途中だけ行が入る。
create table if not exists public.app_events_rehome (
  like public.app_events including defaults
);
comment on table public.app_events_rehome is
  '月の表へ移す途中の作業用。空で運用する。利用者は読めない。';
alter table public.app_events_rehome enable row level security;
revoke all on table public.app_events_rehome from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. 集計してから、古い月の表を消す
-- ---------------------------------------------------------------------
create or replace function public.maintain_app_events()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  i integer;
  month_start date := date_trunc('month', timezone('utc', now()))::date;
  stray_month date;
  stray_months date[];
  part_names text[];
  part_name text;
  part_range_start timestamptz;
  part_range_end timestamptz;
  range_start_day date;
  range_end_day date;
begin
  -- 受け皿に残った行は、その月の表を作る前にどける。
  -- 受け皿に重なる行があると、月の表は作れない。
  if to_regclass('public.app_events_default') is not null then
    select coalesce(array_agg(distinct date_trunc('month', occurred_at at time zone 'utc')::date), '{}'::date[])
    into stray_months
    from public.app_events_default;

    foreach stray_month in array stray_months loop
      truncate public.app_events_rehome;
      execute format(
        'insert into public.app_events_rehome select * from public.app_events_default where occurred_at >= %L and occurred_at < %L',
        (stray_month::timestamp at time zone 'utc'),
        ((stray_month + interval '1 month')::timestamp at time zone 'utc')
      );
      delete from public.app_events_default
      where occurred_at >= (stray_month::timestamp at time zone 'utc')
        and occurred_at < ((stray_month + interval '1 month')::timestamp at time zone 'utc');
      perform public.ensure_app_events_partition(stray_month);
      insert into public.app_events
      select * from public.app_events_rehome
      on conflict do nothing;
      truncate public.app_events_rehome;
    end loop;
  end if;

  for i in -1..3 loop
    perform public.ensure_app_events_partition(
      (month_start + make_interval(months => i))::date
    );
  end loop;

  select coalesce(array_agg(partition_name order by range_start), '{}'::text[])
  into part_names
  from public.app_event_partitions
  where range_end <= now() - interval '90 days';

  foreach part_name in array part_names loop
    select range_start, range_end
    into part_range_start, part_range_end
    from public.app_event_partitions
    where partition_name = part_name;
    if part_range_start is null or part_range_end is null then
      continue;
    end if;

    range_start_day := (part_range_start at time zone 'utc')::date;
    range_end_day := (part_range_end at time zone 'utc')::date;

    delete from public.app_event_daily_totals
    where day >= range_start_day and day < range_end_day;
    execute format(
      $rollup$
        insert into public.app_event_daily_totals (day, event_name, origin, event_count)
        select (occurred_at at time zone 'utc')::date, event_name, origin, count(*)
        from public.%I
        group by 1, 2, 3
      $rollup$,
      part_name
    );

    delete from public.app_event_user_days
    where day >= range_start_day and day < range_end_day;
    execute format(
      $rollup$
        insert into public.app_event_user_days (user_id, day, event_count, events)
        select user_id, day, sum(cnt)::integer, jsonb_object_agg(event_name, cnt)
        from (
          select
            user_id,
            (occurred_at at time zone 'utc')::date as day,
            event_name,
            count(*) as cnt
          from public.%I
          group by 1, 2, 3
        ) grouped
        group by user_id, day
      $rollup$,
      part_name
    );

    execute format('drop table public.%I', part_name);
    delete from public.app_event_partitions
    where partition_name = part_name;
  end loop;

  delete from public.app_event_daily_totals
  where day < (timezone('utc', now()) - interval '2 years')::date;
  delete from public.app_event_user_days
  where day < (timezone('utc', now()) - interval '13 months')::date;
end;
$function$;

revoke all on function public.maintain_app_events()
  from public, anon, authenticated;
grant execute on function public.maintain_app_events() to service_role;

-- ---------------------------------------------------------------------
-- 6. アカウント削除。これまでの処理はそのまま、新しい表の削除だけ足す。
-- ---------------------------------------------------------------------
create or replace function public.delete_own_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  uid uuid;
  v_plus_status text := 'never';
  v_plan text := 'none';
  v_age_bucket text := 'unknown';
  v_created_at timestamptz;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'not authenticated';
  end if;
  uid := p_user_id;

  -- (追加) 個人と結び付かない削除件数の集計。消す前に有料状態を見る。
  select u.created_at into v_created_at from public.users u where u.id = uid;
  if to_regclass('public.calonavi_plus_entitlements') is not null then
    execute $q$
      select
        case
          when e.status = 'active' and e.expires_at > timezone('utc', now()) then 'active'
          when e.status = 'inactive' then 'never'
          else 'expired'
        end,
        case when e.status = 'inactive' then 'none' else e.product_id end
      from public.calonavi_plus_entitlements e
      where e.user_id = $1
      order by
        (e.status = 'active' and e.expires_at > timezone('utc', now())) desc,
        e.expires_at desc nulls last,
        e.updated_at desc nulls last
      limit 1
    $q$ into v_plus_status, v_plan using uid;
    v_plus_status := coalesce(v_plus_status, 'never');
    v_plan := coalesce(v_plan, 'none');
  end if;
  v_age_bucket := case
    when v_created_at is null then 'unknown'
    when timezone('utc', now()) - v_created_at <= interval '1 day' then '0-1d'
    when timezone('utc', now()) - v_created_at <= interval '7 days' then '2-7d'
    when timezone('utc', now()) - v_created_at <= interval '30 days' then '8-30d'
    when timezone('utc', now()) - v_created_at <= interval '90 days' then '31-90d'
    else '91d+'
  end;
  insert into public.account_deletion_stats (deleted_on, plus_status, plan, account_age_bucket, deletions)
  values ((timezone('Asia/Tokyo', now()))::date, v_plus_status, v_plan, v_age_bucket, 1)
  on conflict (deleted_on, plus_status, plan, account_age_bucket)
  do update set deletions = public.account_deletion_stats.deletions + 1;

  delete from public.meal_template_items where user_id = uid;
  delete from public.meal_templates where user_id = uid;

  if to_regclass('public.workout_template_items') is not null then
    execute 'delete from public.workout_template_items where user_id = $1' using uid;
  end if;
  if to_regclass('public.workout_templates') is not null then
    execute 'delete from public.workout_templates where user_id = $1' using uid;
  end if;

  delete from public.food_ratings where rater_user_id = uid;
  delete from public.food_reports where reporter_user_id = uid;
  delete from public.blocked_food_creators
    where blocker_user_id = uid or blocked_user_id = uid;

  delete from public.saved_foods
    where user_id = uid
      and visibility is distinct from 'public';

  delete from public.food_entries where user_id = uid;
  delete from public.exercise_entries where user_id = uid;
  delete from public.weight_entries where user_id = uid;
  if to_regclass('public.alcohol_entries') is not null then
    execute 'delete from public.alcohol_entries where user_id = $1' using uid;
  end if;

  if to_regclass('public.health_workouts') is not null then
    execute 'delete from public.health_workouts where user_id = $1' using uid;
  end if;

  if to_regclass('public.calonavi_plus_entitlements') is not null then
    execute 'delete from public.calonavi_plus_entitlements where user_id = $1' using uid;
  end if;
  if to_regclass('public.food_search_queries') is not null then
    execute 'delete from public.food_search_queries where user_id = $1' using uid;
  end if;
  if to_regclass('public.exercise_search_queries') is not null then
    execute 'delete from public.exercise_search_queries where user_id = $1' using uid;
  end if;
  if to_regclass('public.app_screen_actions') is not null then
    execute 'delete from public.app_screen_actions where user_id = $1' using uid;
  end if;
  if to_regclass('public.coach_proposal_logs') is not null then
    execute 'delete from public.coach_proposal_logs where user_id = $1' using uid;
  end if;

  -- (追加) 行動の数値化で増えた表
  if to_regclass('public.app_events') is not null then
    execute 'delete from public.app_events where user_id = $1' using uid;
  end if;
  if to_regclass('public.store_original_transactions') is not null then
    execute 'delete from public.store_original_transactions where user_id = $1' using uid;
  end if;
  if to_regclass('public.app_event_user_days') is not null then
    execute 'delete from public.app_event_user_days where user_id = $1' using uid;
  end if;
  if to_regclass('public.analytics_consents') is not null then
    execute 'delete from public.analytics_consents where user_id = $1' using uid;
  end if;
  -- 依頼済みの plus_funnel_events が先に作られていた場合も消す（無ければ何もしない）
  if to_regclass('public.plus_funnel_events') is not null then
    execute 'delete from public.plus_funnel_events where user_id = $1' using uid;
  end if;
  -- 購入の通知は売上の集計に要るので行は残し、本人と結び付く情報だけ消す
  if to_regclass('public.store_server_notifications') is not null then
    execute $q$
      update public.store_server_notifications
      set user_id = null,
          app_account_token = null,
          signed_payload = null,
          decoded_payload = null
      where user_id = $1 or app_account_token = $1
    $q$ using uid;
  end if;

  if to_regclass('internal.apple_refresh_tokens') is not null then
    delete from internal.apple_refresh_tokens where user_id = uid;
  end if;

  delete from public.health_snapshots where user_id = uid;
  delete from public.app_settings where user_id = uid;
  delete from public.nutrition_settings where user_id = uid;
  delete from public.goals where user_id = uid;
  delete from public.profiles where user_id = uid;
  delete from public.rate_limit_buckets where user_id = uid;

  update public.users
  set email = null,
      deleted_at = timezone('utc', now())
  where id = uid;

  begin
    delete from auth.identities where user_id = uid;
    update auth.users
    set email = 'deleted+' || uid::text || '@invalid.local',
        raw_user_meta_data = '{}'::jsonb
    where id = uid;
  exception
    when others then
      raise notice 'delete_own_account: skipped auth.users update: %', sqlerrm;
  end;
end;
$function$;

revoke all on function public.delete_own_account(uuid) from public, anon, authenticated;
grant execute on function public.delete_own_account(uuid) to service_role;
