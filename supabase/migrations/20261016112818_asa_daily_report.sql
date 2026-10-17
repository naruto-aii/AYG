-- =====================================================================
-- Apple Ads の日次レポートを置く表（新規だけ）
--
-- 既存の public の表、既存の kpi ビュー、既存の関数は変えない。
-- kpi は Data API の公開スキーマに入れない。
-- Edge Function は public.asa_daily_report_rpc だけを service_role で呼ぶ。
--
-- このファイルを置いただけでは本番に適用されない。適用は承認後。
-- =====================================================================

create table kpi.asa_daily_campaigns (
  data_date date not null,
  campaign_id bigint not null,
  campaign_name text not null,
  impressions integer not null,
  taps integer not null,
  installs integer not null,
  spend numeric(14, 2) not null,
  currency text not null,
  cpa numeric(14, 4),
  fetched_at timestamptz not null default pg_catalog.now(),
  primary key (data_date, campaign_id),
  constraint asa_daily_campaigns_id_check check (campaign_id > 0),
  constraint asa_daily_campaigns_name_check check (char_length(campaign_name) between 1 and 200),
  constraint asa_daily_campaigns_counts_check check (
    impressions between 0 and 2000000000
    and taps between 0 and 2000000000
    and installs between 0 and 2000000000
    and spend >= 0
    and spend <= 100000000
  ),
  constraint asa_daily_campaigns_currency_check check (currency ~ '^[A-Z]{3}$'),
  constraint asa_daily_campaigns_cpa_check check (
    (installs = 0 and cpa is null)
    or (installs > 0 and cpa is not null and cpa >= 0)
  )
);

create table kpi.asa_daily_keywords (
  data_date date not null,
  campaign_id bigint not null,
  ad_group_id bigint not null,
  keyword_id bigint not null,
  keyword text not null,
  match_type text not null,
  ad_group_name text not null default '',
  impressions integer not null,
  taps integer not null,
  installs integer not null,
  spend numeric(14, 2) not null,
  currency text not null,
  cpa numeric(14, 4),
  fetched_at timestamptz not null default pg_catalog.now(),
  primary key (data_date, campaign_id, ad_group_id, keyword_id),
  constraint asa_daily_keywords_campaign_fk
    foreign key (data_date, campaign_id)
    references kpi.asa_daily_campaigns (data_date, campaign_id)
    on delete cascade,
  constraint asa_daily_keywords_id_check check (
    campaign_id > 0 and ad_group_id > 0 and keyword_id > 0
  ),
  constraint asa_daily_keywords_text_check check (
    char_length(keyword) between 1 and 200
    and char_length(match_type) between 1 and 40
    and char_length(ad_group_name) <= 200
  ),
  constraint asa_daily_keywords_counts_check check (
    impressions between 0 and 2000000000
    and taps between 0 and 2000000000
    and installs between 0 and 2000000000
    and spend >= 0
    and spend <= 100000000
  ),
  constraint asa_daily_keywords_currency_check check (currency ~ '^[A-Z]{3}$'),
  constraint asa_daily_keywords_cpa_check check (
    (installs = 0 and cpa is null)
    or (installs > 0 and cpa is not null and cpa >= 0)
  )
);

-- 投稿前の予約。主キーが (report_type, data_date) の一意制約。
create table kpi.asa_report_posts (
  report_type text not null,
  data_date date not null,
  status text not null,
  attempt integer not null default 1,
  reserved_at timestamptz not null default pg_catalog.now(),
  posted_at timestamptz,
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (report_type, data_date),
  constraint asa_report_posts_type_check check (report_type = 'daily'),
  constraint asa_report_posts_status_check check (status in ('reserved', 'posted', 'failed')),
  constraint asa_report_posts_attempt_check check (attempt >= 1)
);

alter table kpi.asa_daily_campaigns enable row level security;
alter table kpi.asa_daily_keywords enable row level security;
alter table kpi.asa_report_posts enable row level security;

revoke all on table kpi.asa_daily_campaigns from public, anon, authenticated;
revoke all on table kpi.asa_daily_keywords from public, anon, authenticated;
revoke all on table kpi.asa_report_posts from public, anon, authenticated;

grant select, insert, update, delete on table kpi.asa_daily_campaigns to service_role;
grant select, insert, update, delete on table kpi.asa_daily_keywords to service_role;
grant select, insert, update, delete on table kpi.asa_report_posts to service_role;

comment on table kpi.asa_daily_campaigns is
  'Apple Ads のキャンペーン日次。日本時間の暦日。カロナビのキャンペーンだけ。';
comment on table kpi.asa_daily_keywords is
  '同じ日のキーワード内訳。検索語句は保存しない。';
comment on table kpi.asa_report_posts is
  'Slack 投稿の予約。投稿前に行を入れ、同じ日付を二重に送らない。';

-- ---------------------------------------------------------------------
-- service_role だけが呼ぶ入口。秘密も本文の控えも置かない。
-- 待ち時間は Edge Function の nextClaim と同じ。失敗の attempt 1 は 30 秒、
-- その後倍々で、上限 30 分。reserved は 30 分を過ぎたら取り直す。posted は取り直さない。
-- ---------------------------------------------------------------------

create or replace function public.asa_daily_report_rpc(p_op text, p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_date date;
  v_type text;
  v_status text;
  v_item jsonb;
  v_updated integer;
  v_result jsonb;
  v_installs integer;
  v_spend numeric(14, 2);
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authenticated';
  end if;
  if p_body is null or pg_catalog.jsonb_typeof(p_body) is distinct from 'object' then
    raise exception 'invalid body';
  end if;

  if p_op = 'get_post' then
    v_type := p_body->>'report_type';
    v_date := (p_body->>'data_date')::date;
    if v_type is distinct from 'daily' then
      raise exception 'invalid report type';
    end if;
    return coalesce((
      select pg_catalog.jsonb_build_object(
        'status', status,
        'attempt', attempt,
        'updated_at_ms', (pg_catalog.date_part('epoch', updated_at) * 1000)::bigint
      )
      from kpi.asa_report_posts
      where report_type = v_type and data_date = v_date
    ), pg_catalog.jsonb_build_object('status', 'none'));
  end if;

  if p_op = 'claim' then
    v_type := p_body->>'report_type';
    v_date := (p_body->>'data_date')::date;
    if v_type is distinct from 'daily' then
      raise exception 'invalid report type';
    end if;
    with ins as (
      insert into kpi.asa_report_posts (
        report_type, data_date, status, attempt, reserved_at, updated_at
      ) values (
        v_type, v_date, 'reserved', 1, pg_catalog.now(), pg_catalog.now()
      )
      on conflict (report_type, data_date) do update
        set status = 'reserved',
            attempt = kpi.asa_report_posts.attempt + 1,
            reserved_at = pg_catalog.now(),
            updated_at = pg_catalog.now()
        where (
            kpi.asa_report_posts.status = 'failed'
            and kpi.asa_report_posts.updated_at <= pg_catalog.now() - pg_catalog.make_interval(
              secs => least(
                1800,
                (30 * pg_catalog.power(
                  2,
                  least(greatest(kpi.asa_report_posts.attempt - 1, 0), 6)
                ))::integer
              )
            )
          )
          or (
            -- reserved のまま 30 分を過ぎた行は、投稿済みと確認できないので取り直す。
            -- posted はここには入らない。期限内の reserved も残し、二重投稿を止める。
            kpi.asa_report_posts.status = 'reserved'
            and kpi.asa_report_posts.updated_at <= pg_catalog.now() - pg_catalog.make_interval(secs => 1800)
          )
      returning 1
    )
    select pg_catalog.jsonb_build_object(
      'result', case when exists (select 1 from ins) then 'claimed' else 'skip' end
    )
    into v_result;
    return v_result;
  end if;

  if p_op = 'finish' then
    v_type := p_body->>'report_type';
    v_date := (p_body->>'data_date')::date;
    v_status := p_body->>'status';
    if v_type is distinct from 'daily' or v_status not in ('posted', 'failed') then
      raise exception 'invalid finish';
    end if;
    update kpi.asa_report_posts
    set status = v_status,
        posted_at = case when v_status = 'posted' then pg_catalog.now() else posted_at end,
        updated_at = pg_catalog.now()
    where report_type = v_type
      and data_date = v_date
      and status = 'reserved';
    get diagnostics v_updated = row_count;
    return pg_catalog.jsonb_build_object('updated', v_updated = 1);
  end if;

  if p_op = 'save_day' then
    v_date := (p_body->>'data_date')::date;
    if pg_catalog.jsonb_typeof(p_body->'campaigns') is distinct from 'array'
      or pg_catalog.jsonb_typeof(p_body->'keywords') is distinct from 'array' then
      raise exception 'invalid day';
    end if;
    if pg_catalog.jsonb_array_length(p_body->'campaigns') > 200
      or pg_catalog.jsonb_array_length(p_body->'keywords') > 5000 then
      raise exception 'too many rows';
    end if;
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtext('asa-daily-report'),
      (v_date - date '2000-01-01')
    );
    delete from kpi.asa_daily_keywords where data_date = v_date;
    delete from kpi.asa_daily_campaigns where data_date = v_date;
    for v_item in select value from pg_catalog.jsonb_array_elements(p_body->'campaigns')
    loop
      v_installs := (v_item->>'installs')::integer;
      v_spend := (v_item->>'spend')::numeric(14, 2);
      insert into kpi.asa_daily_campaigns (
        data_date, campaign_id, campaign_name, impressions, taps, installs,
        spend, currency, cpa, fetched_at
      ) values (
        v_date,
        (v_item->>'campaign_id')::bigint,
        v_item->>'campaign_name',
        (v_item->>'impressions')::integer,
        (v_item->>'taps')::integer,
        v_installs,
        v_spend,
        v_item->>'currency',
        case when v_installs = 0 then null else pg_catalog.round(v_spend / v_installs, 4) end,
        pg_catalog.now()
      );
    end loop;
    for v_item in select value from pg_catalog.jsonb_array_elements(p_body->'keywords')
    loop
      v_installs := (v_item->>'installs')::integer;
      v_spend := (v_item->>'spend')::numeric(14, 2);
      insert into kpi.asa_daily_keywords (
        data_date, campaign_id, ad_group_id, keyword_id, keyword, match_type,
        ad_group_name, impressions, taps, installs, spend, currency, cpa, fetched_at
      ) values (
        v_date,
        (v_item->>'campaign_id')::bigint,
        (v_item->>'ad_group_id')::bigint,
        (v_item->>'keyword_id')::bigint,
        v_item->>'keyword',
        v_item->>'match_type',
        coalesce(v_item->>'ad_group_name', ''),
        (v_item->>'impressions')::integer,
        (v_item->>'taps')::integer,
        v_installs,
        v_spend,
        v_item->>'currency',
        case when v_installs = 0 then null else pg_catalog.round(v_spend / v_installs, 4) end,
        pg_catalog.now()
      );
    end loop;
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown op';
end;
$function$;

revoke all on function public.asa_daily_report_rpc(text, jsonb) from public, anon, authenticated;
grant execute on function public.asa_daily_report_rpc(text, jsonb) to service_role;

comment on function public.asa_daily_report_rpc(text, jsonb) is
  'Apple Ads 日次の保存と投稿予約。service_role だけ。秘密と投稿本文は保存しない。';
