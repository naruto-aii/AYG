-- =====================================================================
-- カロナビ 行動の数値化（追加だけのマイグレーション）
-- 置き場所: supabase/migrations/20261008090000_app_events.sql
--
-- 方針
--   * 既存の表・列・データは一切消さない、変えない（追加だけ）。
--     例外は delete_own_account(uuid) の中身の差し替えのみ。既存の削除処理は
--     一字一句そのまま残し、新しい表の削除を足している。
--   * アプリ利用者に、app_events への直接の insert は渡さない。
--     重複を無視する追加は、090200 の public.insert_app_events だけが行う。
--     直接の upsert は conflict 列の SELECT が要り、本人の行を読めてしまう。
--   * イベント名の一覧はアプリ側（lib/services/analytics/event_names.dart）で持つ。
--     データベース側はイベント名の「形式」と「大きさ」しか検査しないので、
--     新しいイベントを足してもこのファイルの変更は不要。
--   * App Store から取り込む表（store_*）はサーバー（service_role）専用。
--   * 本番には pg_cron / pg_net が入っていないため、定期実行は別ファイル
--     20261008090100_store_import_schedule.sql に分けた（社長の承認後に適用）。
--   * 20261008090200_app_events_retention.sql と必ず同じ作業で適用する。
--     追加関数は、月ごとの主キー (event_id, occurred_at) ができてから作る。
--     このファイルだけの主キーは event_id なので、関数を先に使うと失敗する。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. アプリ内の行動（汎用イベント）
-- ---------------------------------------------------------------------
create table if not exists public.app_events (
  -- 端末で作る UUID。再送しても二重に入らないよう主キーにする。
  event_id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  event_name text not null,
  -- 実際に操作した時刻（ウィジェットを押した時刻など）。端末の時計。
  occurred_at timestamptz not null,
  -- 端末が送信した時刻。端末の時計のずれの推定に使う。
  client_sent_at timestamptz,
  -- サーバーが受け取った時刻。
  received_at timestamptz not null default timezone('utc', now()),
  -- app / home_widget / lock_widget / siri / system など（一覧はアプリ側で管理）
  origin text not null,
  -- アプリを入れるたびに作り直すランダムな UUID（端末の識別子ではない）
  install_id uuid not null,
  session_id uuid,
  -- 連番の系統（app / widget / siri）。系統ごとに 1 から欠けずに増える。
  stream text not null,
  sequence_number bigint not null,
  app_version text not null,
  app_build text not null,
  os_version text,
  device_model text,
  locale text,
  time_zone text,
  schema_version smallint not null default 1,
  -- イベントごとの属性。健康の数値は入れず、記録表の ID で参照する。
  props jsonb not null default '{}'::jsonb,
  advertising_use boolean not null default false,
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
);

comment on table public.app_events is
  'アプリ・ウィジェット・Siri の行動。event_id は端末生成で重複排除。イベント名の一覧はアプリ側 event_names.dart。広告には使わない。';

create index if not exists app_events_user_occurred_idx
  on public.app_events (user_id, occurred_at desc);
create index if not exists app_events_name_occurred_idx
  on public.app_events (event_name, occurred_at desc);
create index if not exists app_events_install_stream_seq_idx
  on public.app_events (install_id, stream, sequence_number);
create index if not exists app_events_received_idx
  on public.app_events (received_at);

alter table public.app_events enable row level security;
revoke all on table public.app_events from public, anon, authenticated;
-- 直接の INSERT は渡さない。ON CONFLICT には SELECT が要り、本人の行が読めてしまう。
-- 追加は 20261008090200 の public.insert_app_events だけ。

-- ---------------------------------------------------------------------
-- 2. 利用状況の記録への同意（審査ガイドライン 5.1.1(ii) 対応）
-- ---------------------------------------------------------------------
create table if not exists public.analytics_consents (
  consent_id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  install_id uuid not null,
  consented boolean not null,
  policy_version text not null,
  decided_at timestamptz not null,
  received_at timestamptz not null default timezone('utc', now()),
  surface text not null,
  constraint analytics_consents_policy_version_length check (char_length(policy_version) between 1 and 32),
  constraint analytics_consents_surface_format check (surface ~ '^[a-z][a-z0-9_]{1,30}$')
);

create index if not exists analytics_consents_user_decided_idx
  on public.analytics_consents (user_id, decided_at desc);

alter table public.analytics_consents enable row level security;
revoke all on table public.analytics_consents from anon, authenticated;
grant insert on table public.analytics_consents to authenticated;

drop policy if exists analytics_consents_insert_own on public.analytics_consents;
create policy analytics_consents_insert_own
  on public.analytics_consents
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 3. アカウント削除の集計（個人と結び付かない件数だけ。重要指標 67・68）
-- ---------------------------------------------------------------------
create table if not exists public.account_deletion_stats (
  deleted_on date not null,
  plus_status text not null,          -- active（削除時に有効） / expired（過去に有料） / never（有料歴なし）
  plan text not null,                 -- 商品 ID か none
  account_age_bucket text not null,   -- 0-1d / 2-7d / 8-30d / 31-90d / 91d+
  deletions integer not null default 0,
  primary key (deleted_on, plus_status, plan, account_age_bucket)
);

alter table public.account_deletion_stats enable row level security;
revoke all on table public.account_deletion_stats from anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. App Store から取り込むデータ（サーバー専用。アプリからは読めない・書けない）
-- ---------------------------------------------------------------------

-- 4-1. 取り込み処理の実行記録（取りこぼし検知用）
create table if not exists public.store_import_runs (
  run_id uuid primary key default gen_random_uuid(),
  job text not null,                  -- analytics / sales / notifications_check
  started_at timestamptz not null default timezone('utc', now()),
  finished_at timestamptz,
  status text not null default 'running', -- running / succeeded / failed / partial
  files_imported integer not null default 0,
  rows_imported integer not null default 0,
  detail jsonb not null default '{}'::jsonb
);
create index if not exists store_import_runs_job_started_idx
  on public.store_import_runs (job, started_at desc);

-- 4-2. 分析レポートの依頼（Analytics Reports の reportRequest）
create table if not exists public.store_analytics_report_requests (
  request_id text primary key,
  app_apple_id text not null,
  access_type text not null,          -- ONGOING / ONE_TIME_SNAPSHOT
  stopped_due_to_inactivity boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  last_checked_at timestamptz
);

-- 4-3. 取り込んだファイル（segment）単位の台帳。1 つでも未取り込みがあれば分かる。
create table if not exists public.store_analytics_segments (
  segment_id text primary key,
  instance_id text not null,
  report_id text not null,
  report_name text not null,
  report_category text not null,
  granularity text not null,          -- DAILY / WEEKLY / MONTHLY
  processing_date date not null,
  checksum text,
  size_bytes bigint,
  row_count integer,
  status text not null default 'pending', -- pending / imported / failed
  attempts integer not null default 0,
  last_error text,
  first_seen_at timestamptz not null default timezone('utc', now()),
  imported_at timestamptz
);
create index if not exists store_analytics_segments_status_idx
  on public.store_analytics_segments (status, processing_date);

-- 4-4. 分析レポートの中身。列はレポートごとに違うので、全列を jsonb にそのまま入れる。
create table if not exists public.store_analytics_rows (
  segment_id text not null references public.store_analytics_segments(segment_id),
  row_number integer not null,
  report_name text not null,
  granularity text not null,
  row_date date,
  data jsonb not null,
  primary key (segment_id, row_number)
);
create index if not exists store_analytics_rows_report_date_idx
  on public.store_analytics_rows (report_name, granularity, row_date);

-- 4-5. 売上とトレンドのレポート（salesReports）
create table if not exists public.store_sales_report_files (
  report_type text not null,          -- SALES / SUBSCRIPTION / SUBSCRIPTION_EVENT / SUBSCRIBER
  report_sub_type text not null,      -- SUMMARY / DETAILED
  frequency text not null,            -- DAILY / WEEKLY / MONTHLY / YEARLY
  report_date date not null,
  version text not null,
  status text not null default 'pending', -- pending / imported / not_available / failed
  attempts integer not null default 0,
  row_count integer,
  last_error text,
  imported_at timestamptz,
  primary key (report_type, report_sub_type, frequency, report_date, version)
);

create table if not exists public.store_sales_rows (
  report_type text not null,
  report_sub_type text not null,
  frequency text not null,
  report_date date not null,
  version text not null,
  row_number integer not null,
  data jsonb not null,
  primary key (report_type, report_sub_type, frequency, report_date, version, row_number),
  foreign key (report_type, report_sub_type, frequency, report_date, version)
    references public.store_sales_report_files (report_type, report_sub_type, frequency, report_date, version)
);

-- 4-6. App Store サーバー通知 第 2 版（購入・更新・解約・返金など）
create table if not exists public.store_server_notifications (
  notification_uuid uuid primary key,
  notification_type text not null,
  subtype text,
  environment text,                   -- Production / Sandbox
  signed_date timestamptz,
  received_at timestamptz not null default timezone('utc', now()),
  bundle_id text,
  app_apple_id text,
  product_id text,
  original_transaction_id text,
  transaction_id text,
  app_account_token uuid,             -- = 購入時の Supabase の user_id
  user_id uuid,                       -- app_account_token か original_transaction_id から照合
  purchase_date timestamptz,
  expires_date timestamptz,
  price_milliunits bigint,
  currency text,
  offer_type integer,
  offer_discount_type text,
  revocation_reason integer,
  auto_renew_status integer,
  verification_status text not null,  -- verified / failed
  -- 退会者は signed_payload と decoded_payload を消し、識別子を null にする
  signed_payload text,
  decoded_payload jsonb
);
create index if not exists store_server_notifications_user_idx
  on public.store_server_notifications (user_id, signed_date desc);
create index if not exists store_server_notifications_original_tx_idx
  on public.store_server_notifications (original_transaction_id, signed_date desc);
create index if not exists store_server_notifications_type_idx
  on public.store_server_notifications (notification_type, signed_date desc);

alter table public.store_import_runs enable row level security;
alter table public.store_analytics_report_requests enable row level security;
alter table public.store_analytics_segments enable row level security;
alter table public.store_analytics_rows enable row level security;
alter table public.store_sales_report_files enable row level security;
alter table public.store_sales_rows enable row level security;
alter table public.store_server_notifications enable row level security;

revoke all on table public.store_import_runs from anon, authenticated;
revoke all on table public.store_analytics_report_requests from anon, authenticated;
revoke all on table public.store_analytics_segments from anon, authenticated;
revoke all on table public.store_analytics_rows from anon, authenticated;
revoke all on table public.store_sales_report_files from anon, authenticated;
revoke all on table public.store_sales_rows from anon, authenticated;
revoke all on table public.store_server_notifications from anon, authenticated;
-- 方針どおり、これらの表にはアプリ利用者向けの policy を作らない（service_role だけが使う）。

-- ---------------------------------------------------------------------
-- 5. 既存の app_screen_actions / 検索の表との互換（データは消さない）
--    旧データも新しいイベントと同じ形で読めるビュー。二重書き込み中は
--    同じ UUID を両方に入れるので、ここで重複を除く。
-- ---------------------------------------------------------------------
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
    -- 旧方式ではウィジェットの時刻は「押した時刻」ではなく「アプリが取り込んだ時刻」
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

-- ---------------------------------------------------------------------
-- 6. 「届いていない数値」を見つけるためのビュー（連番の欠け）
-- ---------------------------------------------------------------------
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

create or replace view public.store_import_health
with (security_invoker = true) as
select
  job,
  max(finished_at) filter (where status = 'succeeded') as last_succeeded_at,
  max(started_at) as last_started_at,
  count(*) filter (where status = 'failed' and started_at > timezone('utc', now()) - interval '7 days') as failed_runs_last_7_days
from public.store_import_runs
group by job;

revoke all on table public.store_import_health from anon, authenticated;

-- ---------------------------------------------------------------------
-- 7. アカウント削除関数の差し替え
--    本番の delete_own_account(p_user_id uuid) の本体（2026-10-07 時点で
--    読み取り確認）をそのまま残し、新しい表の削除と集計を足した。
--    service_role 以外は実行できない検査も、実行権限もそのまま。
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

-- 実行権限は本番と同じ（postgres と service_role だけ）
revoke all on function public.delete_own_account(uuid) from public, anon, authenticated;
grant execute on function public.delete_own_account(uuid) to service_role;
