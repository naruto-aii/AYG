-- 日次レポートを1本にまとめるための追加。
-- 既存の表・列・関数は変えない。集計値だけを新しい表に入れる。
-- 個人を特定する列は作らない。

create table kpi.asc_usage_daily (
  data_date date primary key,
  installs integer,
  uninstalls integer,
  installs_state text not null,
  sessions integer,
  session_duration_seconds bigint,
  unique_devices integer,
  sessions_state text not null,
  crash_count integer,
  crashes_by_version jsonb,
  crashes_by_device jsonb,
  crashes_state text not null,
  fetched_at timestamptz not null default pg_catalog.now(),
  constraint asc_usage_daily_installs_state check (installs_state in ('present', 'absent', 'pending')),
  constraint asc_usage_daily_sessions_state check (sessions_state in ('present', 'absent', 'pending')),
  constraint asc_usage_daily_crashes_state check (crashes_state in ('present', 'absent', 'pending')),
  constraint asc_usage_daily_installs_null check (
    (installs_state = 'present' and installs is not null and uninstalls is not null)
    or (installs_state <> 'present' and installs is null and uninstalls is null)
  ),
  constraint asc_usage_daily_sessions_null check (
    (sessions_state = 'present' and sessions is not null and session_duration_seconds is not null and unique_devices is not null)
    or (sessions_state <> 'present' and sessions is null and session_duration_seconds is null and unique_devices is null)
  ),
  constraint asc_usage_daily_crashes_null check (
    (crashes_state = 'present' and crash_count is not null)
    or (crashes_state <> 'present' and crash_count is null and crashes_by_version is null and crashes_by_device is null)
  )
);

create table kpi.app_activity_daily (
  data_date date primary key,
  window_start timestamptz not null,
  window_end timestamptz not null,
  first_opens integer not null,
  first_opens_asa integer not null,
  first_opens_other integer not null,
  first_opens_unknown integer not null,
  registrations integer not null,
  onboarding_completes integer not null,
  first_meals integer not null,
  paywall_openers integer not null,
  trial_starts integer not null,
  sessions integer not null,
  session_duration_seconds bigint not null,
  searches integer not null,
  siri_uses integer not null,
  widget_uses integer not null,
  fetched_at timestamptz not null default pg_catalog.now()
);

create table kpi.daily_report_snapshot (
  data_date date primary key,
  heading text not null,
  slack_text text not null,
  payload jsonb not null,
  content_hash text not null,
  publishable boolean not null,
  updated_at timestamptz not null default pg_catalog.now()
);

create table kpi.daily_report_delivery (
  data_date date primary key,
  status text not null,
  attempt integer not null,
  content_hash text,
  reserved_at timestamptz,
  posted_at timestamptz,
  updated_at timestamptz not null default pg_catalog.now(),
  constraint daily_report_delivery_status check (status in ('reserved', 'posted', 'failed'))
);

alter table kpi.asc_usage_daily enable row level security;
alter table kpi.app_activity_daily enable row level security;
alter table kpi.daily_report_snapshot enable row level security;
alter table kpi.daily_report_delivery enable row level security;

revoke all on table kpi.asc_usage_daily, kpi.app_activity_daily, kpi.daily_report_snapshot, kpi.daily_report_delivery
  from public, anon, authenticated;
grant select, insert, update, delete on table kpi.asc_usage_daily, kpi.app_activity_daily, kpi.daily_report_snapshot, kpi.daily_report_delivery
  to service_role;

-- countAppActivity（supabase/functions/asc-daily-report/metrics.ts）と同じ規則。
-- ASA は attribution が真で、キャンペーンが社長の指定と一致するもの。
create function kpi.collect_app_activity(p_start timestamptz, p_end timestamptz)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with events as (
    select event_name, occurred_at, user_id, install_id, props
    from kpi.app_events
    where occurred_at < p_end
  ),
  opens as (
    select install_id, user_id
    from events
    where event_name = 'app_install_first_open'
      and occurred_at >= p_start
  ),
  ads as (
    select install_id,
      bool_or(
        (props->'attribution') = 'true'::jsonb
        and props->>'campaign_id' = '2144888758'
      ) as asa
    from kpi.app_events
    where event_name = 'apple_ads_attribution'
      and install_id is not null
    group by install_id
  ),
  first_onboarding as (
    select user_id, min(occurred_at) as at
    from events
    where event_name = 'onboarding_complete'
      and user_id is not null
    group by user_id
  ),
  first_meal as (
    select user_id, min(occurred_at) as at
    from events
    where event_name = 'food_entry_added'
      and user_id is not null
    group by user_id
  )
  select pg_catalog.jsonb_build_object(
    'first_opens', (select count(*) from opens),
    'first_opens_asa', (
      select count(*) from opens o
      join ads a on a.install_id = o.install_id
      where a.asa
    ),
    'first_opens_other', (
      select count(*) from opens o
      join ads a on a.install_id = o.install_id
      where not a.asa
    ),
    'first_opens_unknown', (
      select count(*) from opens o
      where not exists (select 1 from ads a where a.install_id = o.install_id)
    ),
    'registrations', (
      select count(*)
      from auth.users u
      where u.created_at >= p_start
        and u.created_at < p_end
        and u.deleted_at is null
        and coalesce(u.is_anonymous, false) = false
        and not exists (select 1 from kpi.excluded_user_ids x where x.user_id = u.id)
        and not exists (
          select 1 from public.users p
          where p.id = u.id and p.deleted_at is not null
        )
        and not exists (
          select 1 from public.app_events e
          where e.user_id = u.id
            and exists (
              select 1 from kpi.excluded_install_ids i where i.install_id = e.install_id
            )
        )
    ),
    'onboarding_completes', (
      select count(*)
      from first_onboarding f
      join kpi.app_settings s on s.user_id = f.user_id and s.onboarding_complete
      where f.at >= p_start
    ),
    'first_meals', (select count(*) from first_meal where at >= p_start),
    'paywall_openers', (
      select count(distinct user_id)
      from events
      where event_name = 'paywall_open'
        and user_id is not null
        and occurred_at >= p_start
    ),
    'trial_starts', (
      select count(distinct coalesce(nullif(n.original_transaction_id, ''), n.notification_uuid::text))
      from public.store_server_notifications n
      where n.verification_status = 'verified'
        and n.environment = 'Production'
        and (n.notification_type = 'INITIAL_BUY' or n.subtype = 'INITIAL_BUY')
        and (
          pg_catalog.upper(coalesce(n.offer_discount_type, '')) = 'FREE_TRIAL'
          or (
            pg_catalog.upper(coalesce(n.offer_discount_type, '')) not in ('PAY_AS_YOU_GO', 'PAY_UP_FRONT')
            and n.offer_type = 1
            and n.price_milliunits = 0
          )
        )
        and n.signed_date >= p_start
        and n.signed_date < p_end
        and (n.user_id is null or not exists (
          select 1 from kpi.excluded_user_ids x where x.user_id = n.user_id
        ))
    ),
    'sessions', (
      select count(*) from events
      where event_name = 'session_start' and occurred_at >= p_start
    ),
    'session_duration_seconds', (
      select coalesce(pg_catalog.round(sum((props->>'duration_seconds')::numeric)), 0)::bigint
      from events
      where event_name = 'session_end'
        and occurred_at >= p_start
        and (props->>'duration_seconds') ~ '^[0-9]+(\.[0-9]+)?$'
    ),
    'searches', (
      select count(*) from events
      where event_name in ('food_search', 'exercise_search')
        and occurred_at >= p_start
    ),
    'siri_uses', (
      select count(*) from events
      where event_name in ('siri_request_started', 'siri_registration_imported', 'siri_open_search')
        and occurred_at >= p_start
    ),
    'widget_uses', (
      select count(*) from events
      where event_name in ('widget_tap', 'widget_registration_imported')
        and occurred_at >= p_start
    )
  );
$$;

revoke all on function kpi.collect_app_activity(timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function kpi.collect_app_activity(timestamptz, timestamptz) to service_role;

-- 直近14日の推移。規則は collect_app_activity と同じ。
create function kpi.collect_app_activity_windows(p_windows jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_row jsonb;
  v_out jsonb := '[]'::jsonb;
  v_count integer := 0;
begin
  if pg_catalog.jsonb_typeof(p_windows) is distinct from 'array' then
    return '[]'::jsonb;
  end if;
  for v_item in select value from pg_catalog.jsonb_array_elements(p_windows)
  loop
    v_count := v_count + 1;
    if v_count > 16 then
      exit;
    end if;
    v_row := kpi.collect_app_activity(
      (v_item->>'start')::timestamptz,
      (v_item->>'end')::timestamptz
    );
    v_out := v_out || pg_catalog.jsonb_build_array(
      v_row || pg_catalog.jsonb_build_object('report_date', v_item->>'report_date')
    );
  end loop;
  return v_out;
end;
$$;

revoke all on function kpi.collect_app_activity_windows(jsonb) from public, anon, authenticated;
grant execute on function kpi.collect_app_activity_windows(jsonb) to service_role;

create function kpi.daily_report_outbox()
returns table (
  data_date date,
  content_hash text,
  slack_text text,
  payload jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.data_date, s.content_hash, s.slack_text, s.payload
  from kpi.daily_report_delivery d
  join kpi.daily_report_snapshot s on s.data_date = d.data_date
  where d.status = 'reserved'
    and s.publishable
    and d.content_hash = s.content_hash
  order by s.data_date;
$$;

create function kpi.finish_daily_report_delivery(p_data_date date, p_status text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  if p_status not in ('posted', 'failed') then
    raise exception 'invalid status';
  end if;
  update kpi.daily_report_delivery
  set status = p_status,
      posted_at = case when p_status = 'posted' then pg_catalog.now() else posted_at end,
      updated_at = pg_catalog.now()
  where data_date = p_data_date
    and status = 'reserved';
  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

revoke all on function kpi.daily_report_outbox() from public, anon, authenticated;
revoke all on function kpi.finish_daily_report_delivery(date, text) from public, anon, authenticated;
grant execute on function kpi.daily_report_outbox() to service_role;
grant execute on function kpi.finish_daily_report_delivery(date, text) to service_role;

-- Edge Function が service_role で呼ぶ。anon と authenticated には渡さない。
-- Actions は DB へ直接つながず、関数の outbox / finish を読む。
create function public.daily_report_ingest_rpc(p_op text, p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_date date;
  v_status text;
  v_updated integer;
  v_result jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authenticated';
  end if;
  if p_body is null or pg_catalog.jsonb_typeof(p_body) is distinct from 'object' then
    raise exception 'invalid body';
  end if;

  if p_op = 'get_delivery' then
    v_date := (p_body->>'data_date')::date;
    return coalesce((
      select pg_catalog.jsonb_build_object(
        'status', status,
        'attempt', attempt,
        'updated_at_ms', (pg_catalog.date_part('epoch', updated_at) * 1000)::bigint,
        'content_hash', content_hash
      )
      from kpi.daily_report_delivery
      where data_date = v_date
    ), pg_catalog.jsonb_build_object('status', 'none'));
  end if;

  if p_op = 'claim' then
    v_date := (p_body->>'data_date')::date;
    if coalesce(p_body->>'content_hash', '') = '' then
      raise exception 'invalid hash';
    end if;
    with ins as (
      insert into kpi.daily_report_delivery (
        data_date, status, attempt, content_hash, reserved_at, updated_at
      ) values (
        v_date, 'reserved', 1, p_body->>'content_hash', pg_catalog.now(), pg_catalog.now()
      )
      on conflict (data_date) do update
        set status = 'reserved',
            attempt = kpi.daily_report_delivery.attempt + 1,
            content_hash = excluded.content_hash,
            reserved_at = pg_catalog.now(),
            updated_at = pg_catalog.now()
        where (
            kpi.daily_report_delivery.status = 'failed'
            and kpi.daily_report_delivery.updated_at <= pg_catalog.now() - pg_catalog.make_interval(
              secs => least(
                1800,
                (30 * pg_catalog.power(
                  2,
                  least(greatest(kpi.daily_report_delivery.attempt - 1, 0), 6)
                ))::integer
              )
            )
          )
          or (
            kpi.daily_report_delivery.status = 'reserved'
            and kpi.daily_report_delivery.updated_at <= pg_catalog.now() - interval '30 minutes'
          )
          or (
            coalesce(p_body->>'revise', '') = 'true'
            and kpi.daily_report_delivery.status = 'posted'
          )
      returning 1
    )
    select pg_catalog.jsonb_build_object(
      'result', case when exists (select 1 from ins) then 'claimed' else 'skip' end
    )
    into v_result;
    return v_result;
  end if;

  if p_op = 'save_usage' then
    v_date := (p_body->>'data_date')::date;
    v_status := p_body->>'installs_state';
    if v_status not in ('present', 'absent', 'pending')
      or (p_body->>'sessions_state') not in ('present', 'absent', 'pending')
      or (p_body->>'crashes_state') not in ('present', 'absent', 'pending') then
      raise exception 'invalid usage state';
    end if;
    insert into kpi.asc_usage_daily (
      data_date, installs, uninstalls, installs_state,
      sessions, session_duration_seconds, unique_devices, sessions_state,
      crash_count, crashes_by_version, crashes_by_device, crashes_state, fetched_at
    ) values (
      v_date,
      (p_body->>'installs')::integer,
      (p_body->>'uninstalls')::integer,
      p_body->>'installs_state',
      (p_body->>'sessions')::integer,
      (p_body->>'session_duration_seconds')::bigint,
      (p_body->>'unique_devices')::integer,
      p_body->>'sessions_state',
      (p_body->>'crash_count')::integer,
      p_body->'crashes_by_version',
      p_body->'crashes_by_device',
      p_body->>'crashes_state',
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set installs = excluded.installs,
          uninstalls = excluded.uninstalls,
          installs_state = excluded.installs_state,
          sessions = excluded.sessions,
          session_duration_seconds = excluded.session_duration_seconds,
          unique_devices = excluded.unique_devices,
          sessions_state = excluded.sessions_state,
          crash_count = excluded.crash_count,
          crashes_by_version = excluded.crashes_by_version,
          crashes_by_device = excluded.crashes_by_device,
          crashes_state = excluded.crashes_state,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_app_activity' then
    v_date := (p_body->>'data_date')::date;
    insert into kpi.app_activity_daily (
      data_date, window_start, window_end,
      first_opens, first_opens_asa, first_opens_other, first_opens_unknown,
      registrations, onboarding_completes, first_meals, paywall_openers, trial_starts,
      sessions, session_duration_seconds, searches, siri_uses, widget_uses, fetched_at
    ) values (
      v_date,
      (p_body->>'window_start')::timestamptz,
      (p_body->>'window_end')::timestamptz,
      (p_body->>'first_opens')::integer,
      (p_body->>'first_opens_asa')::integer,
      (p_body->>'first_opens_other')::integer,
      (p_body->>'first_opens_unknown')::integer,
      (p_body->>'registrations')::integer,
      (p_body->>'onboarding_completes')::integer,
      (p_body->>'first_meals')::integer,
      (p_body->>'paywall_openers')::integer,
      (p_body->>'trial_starts')::integer,
      (p_body->>'sessions')::integer,
      (p_body->>'session_duration_seconds')::bigint,
      (p_body->>'searches')::integer,
      (p_body->>'siri_uses')::integer,
      (p_body->>'widget_uses')::integer,
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set window_start = excluded.window_start,
          window_end = excluded.window_end,
          first_opens = excluded.first_opens,
          first_opens_asa = excluded.first_opens_asa,
          first_opens_other = excluded.first_opens_other,
          first_opens_unknown = excluded.first_opens_unknown,
          registrations = excluded.registrations,
          onboarding_completes = excluded.onboarding_completes,
          first_meals = excluded.first_meals,
          paywall_openers = excluded.paywall_openers,
          trial_starts = excluded.trial_starts,
          sessions = excluded.sessions,
          session_duration_seconds = excluded.session_duration_seconds,
          searches = excluded.searches,
          siri_uses = excluded.siri_uses,
          widget_uses = excluded.widget_uses,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_snapshot' then
    v_date := (p_body->>'data_date')::date;
    if coalesce(p_body->>'content_hash', '') = '' or coalesce(p_body->>'slack_text', '') = '' then
      raise exception 'invalid snapshot';
    end if;
    if pg_catalog.jsonb_typeof(p_body->'payload') is distinct from 'object' then
      raise exception 'invalid payload';
    end if;
    insert into kpi.daily_report_snapshot (
      data_date, heading, slack_text, payload, content_hash, publishable, updated_at
    ) values (
      v_date,
      p_body->>'heading',
      p_body->>'slack_text',
      p_body->'payload',
      p_body->>'content_hash',
      coalesce((p_body->>'publishable')::boolean, false),
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set heading = excluded.heading,
          slack_text = excluded.slack_text,
          payload = excluded.payload,
          content_hash = excluded.content_hash,
          publishable = excluded.publishable,
          updated_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'app_activity' then
    return kpi.collect_app_activity(
      (p_body->>'start')::timestamptz,
      (p_body->>'end')::timestamptz
    );
  end if;

  if p_op = 'app_activity_windows' then
    return kpi.collect_app_activity_windows(p_body->'windows');
  end if;

  if p_op = 'outbox' then
    return pg_catalog.jsonb_build_object(
      'rows', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'content_hash', content_hash,
          'slack_text', slack_text,
          'payload', payload
        ) order by data_date)
        from kpi.daily_report_outbox()
      ), '[]'::jsonb)
    );
  end if;

  if p_op = 'finish' then
    return pg_catalog.jsonb_build_object(
      'ok', kpi.finish_daily_report_delivery((p_body->>'data_date')::date, p_body->>'status')
    );
  end if;

  if p_op = 'history_extra' then
    return pg_catalog.jsonb_build_object(
      'usage', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'installs', installs,
          'uninstalls', uninstalls,
          'installs_state', installs_state,
          'sessions', sessions,
          'session_duration_seconds', session_duration_seconds,
          'unique_devices', unique_devices,
          'sessions_state', sessions_state,
          'crash_count', crash_count,
          'crashes_by_version', crashes_by_version,
          'crashes_by_device', crashes_by_device,
          'crashes_state', crashes_state
        ) order by data_date)
        from kpi.asc_usage_daily
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb),
      'activity', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'first_opens', first_opens,
          'first_opens_asa', first_opens_asa,
          'first_opens_other', first_opens_other,
          'first_opens_unknown', first_opens_unknown,
          'registrations', registrations,
          'onboarding_completes', onboarding_completes,
          'first_meals', first_meals,
          'paywall_openers', paywall_openers,
          'trial_starts', trial_starts,
          'sessions', sessions,
          'session_duration_seconds', session_duration_seconds,
          'searches', searches,
          'siri_uses', siri_uses,
          'widget_uses', widget_uses
        ) order by data_date)
        from kpi.app_activity_daily
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb)
    );
  end if;

  raise exception 'unknown op';
end;
$$;

revoke all on function public.daily_report_ingest_rpc(text, jsonb) from public, anon, authenticated;
grant execute on function public.daily_report_ingest_rpc(text, jsonb) to service_role;
