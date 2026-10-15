-- =====================================================================
-- App Store Connect の日次レポートを置く表（新規だけ）
--
-- 既存の public の表、既存の kpi ビュー、既存の関数は変えない。
-- kpi は Data API の公開スキーマに入れない。既に利用者由来のビューがあるため。
-- Edge Function は public.asc_daily_report_rpc だけを service_role で呼ぶ。
--
-- このファイルを置いただけでは本番に適用されない。適用は社長の承認後。
-- =====================================================================

create table kpi.asc_daily_sales (
  data_date date primary key,
  new_downloads integer not null,
  redownloads integer not null,
  sales_jpy numeric(14, 2) not null,
  proceeds_jpy numeric(14, 2) not null,
  non_jpy_customer_rows integer not null,
  fetched_at timestamptz not null default pg_catalog.now(),
  constraint asc_daily_sales_counts_range check (
    new_downloads between -100000000 and 100000000
    and redownloads between -100000000 and 100000000
    and non_jpy_customer_rows between 0 and 100000000
  )
);

create table kpi.asc_daily_subscription (
  data_date date not null,
  plan text not null,
  active_paid integer not null,
  active_trials integer not null,
  fetched_at timestamptz not null default pg_catalog.now(),
  primary key (data_date, plan),
  constraint asc_daily_subscription_plan_check check (
    plan in ('monthly', 'half_year', 'yearly', 'other')
  ),
  constraint asc_daily_subscription_counts_check check (
    active_paid >= 0 and active_trials >= 0
  )
);

create table kpi.asc_daily_sub_events (
  data_date date primary key,
  trial_starts integer not null,
  paid_conversions integer not null,
  cancellations integer not null,
  fetched_at timestamptz not null default pg_catalog.now(),
  constraint asc_daily_sub_events_counts_check check (
    trial_starts >= 0
    and paid_conversions >= 0
    and cancellations >= 0
  )
);

create table kpi.asc_daily_reviews (
  data_date date primary key,
  review_count integer not null,
  average_rating numeric(3, 1),
  star_1 integer not null,
  star_2 integer not null,
  star_3 integer not null,
  star_4 integer not null,
  star_5 integer not null,
  excerpt text not null default '',
  written_only boolean not null default true,
  fetched_at timestamptz not null default pg_catalog.now(),
  constraint asc_daily_reviews_counts_check check (
    review_count >= 0
    and star_1 >= 0 and star_2 >= 0 and star_3 >= 0 and star_4 >= 0 and star_5 >= 0
    and star_1 + star_2 + star_3 + star_4 + star_5 = review_count
  ),
  constraint asc_daily_reviews_average_check check (
    (review_count = 0 and average_rating is null)
    or (review_count > 0 and average_rating between 1 and 5)
  ),
  constraint asc_daily_reviews_excerpt_check check (char_length(excerpt) <= 120),
  constraint asc_daily_reviews_written_only_check check (written_only)
);

create table kpi.asc_analytics_daily (
  data_date date primary key,
  impressions integer not null,
  product_page_views integer not null,
  source_search integer not null,
  source_other integer not null,
  downloads integer not null,
  conversion_rate numeric(12, 4),
  search_includes_ads boolean not null,
  fetched_at timestamptz not null default pg_catalog.now(),
  constraint asc_analytics_daily_counts_check check (
    impressions >= 0
    and product_page_views >= 0
    and source_search >= 0
    and source_other >= 0
    and downloads >= 0
  ),
  constraint asc_analytics_daily_conversion_check check (
    (impressions = 0 and conversion_rate is null)
    or (impressions > 0 and conversion_rate is not null and conversion_rate >= 0)
  ),
  constraint asc_analytics_daily_sources_check check (
    source_search + source_other = impressions
  )
);

-- 投稿前の予約。主キーが (report_type, data_date) の一意制約。
create table kpi.asc_report_posts (
  report_type text not null,
  data_date date not null,
  status text not null,
  attempt integer not null default 1,
  reserved_at timestamptz not null default pg_catalog.now(),
  posted_at timestamptz,
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (report_type, data_date),
  constraint asc_report_posts_type_check check (report_type in ('flash', 'acquisition')),
  constraint asc_report_posts_status_check check (status in ('reserved', 'posted', 'failed')),
  constraint asc_report_posts_attempt_check check (attempt >= 1)
);

alter table kpi.asc_daily_sales enable row level security;
alter table kpi.asc_daily_subscription enable row level security;
alter table kpi.asc_daily_sub_events enable row level security;
alter table kpi.asc_daily_reviews enable row level security;
alter table kpi.asc_analytics_daily enable row level security;
alter table kpi.asc_report_posts enable row level security;

revoke all on table kpi.asc_daily_sales from public, anon, authenticated;
revoke all on table kpi.asc_daily_subscription from public, anon, authenticated;
revoke all on table kpi.asc_daily_sub_events from public, anon, authenticated;
revoke all on table kpi.asc_daily_reviews from public, anon, authenticated;
revoke all on table kpi.asc_analytics_daily from public, anon, authenticated;
revoke all on table kpi.asc_report_posts from public, anon, authenticated;

grant select, insert, update, delete on table kpi.asc_daily_sales to service_role;
grant select, insert, update, delete on table kpi.asc_daily_subscription to service_role;
grant select, insert, update, delete on table kpi.asc_daily_sub_events to service_role;
grant select, insert, update, delete on table kpi.asc_daily_reviews to service_role;
grant select, insert, update, delete on table kpi.asc_analytics_daily to service_role;
grant select, insert, update, delete on table kpi.asc_report_posts to service_role;

comment on table kpi.asc_daily_sales is
  'Sales SUMMARY DAILY のアプリ単位集計。売上は顧客通貨 JPY、手取りは受取通貨 JPY。';
comment on table kpi.asc_daily_subscription is
  'SUBSCRIPTION DAILY のプラン別有効数とトライアル数。';
comment on table kpi.asc_daily_sub_events is
  'SUBSCRIPTION_EVENT DAILY のトライアル開始、無料トライアルからの有料化、解約。';
comment on table kpi.asc_daily_reviews is
  '本文のある Customer Reviews だけ。本文なしの星は API に無い。';
comment on table kpi.asc_analytics_daily is
  'Analytics の表示、製品ページ、流入、転換率。検索には Search Ads が含まれる。';
comment on table kpi.asc_report_posts is
  'Slack 投稿の予約。投稿前に行を入れ、同じ日付を二重に送らない。';

-- ---------------------------------------------------------------------
-- service_role だけが呼ぶ入口。秘密も本文の控えも置かない。
-- 待ち時間は Edge Function の nextClaim と同じ。失敗の attempt 1 は 30 秒、
-- その後倍々で、上限 30 分。
-- ---------------------------------------------------------------------

create or replace function public.asc_daily_report_rpc(p_op text, p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_date date;
  v_type text;
  v_status text;
  v_plan text;
  v_item jsonb;
  v_excerpt text;
  v_count integer;
  v_updated integer;
  v_result jsonb;
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
    if v_type not in ('flash', 'acquisition') then
      raise exception 'invalid report type';
    end if;
    return coalesce((
      select pg_catalog.jsonb_build_object(
        'status', status,
        'attempt', attempt,
        'updated_at_ms', (pg_catalog.date_part('epoch', updated_at) * 1000)::bigint
      )
      from kpi.asc_report_posts
      where report_type = v_type and data_date = v_date
    ), pg_catalog.jsonb_build_object('status', 'none'));
  end if;

  if p_op = 'claim' then
    v_type := p_body->>'report_type';
    v_date := (p_body->>'data_date')::date;
    if v_type not in ('flash', 'acquisition') then
      raise exception 'invalid report type';
    end if;
    with ins as (
      insert into kpi.asc_report_posts (
        report_type, data_date, status, attempt, reserved_at, updated_at
      ) values (
        v_type, v_date, 'reserved', 1, pg_catalog.now(), pg_catalog.now()
      )
      on conflict (report_type, data_date) do update
        set status = 'reserved',
            attempt = kpi.asc_report_posts.attempt + 1,
            reserved_at = pg_catalog.now(),
            updated_at = pg_catalog.now()
        where kpi.asc_report_posts.status = 'failed'
          and kpi.asc_report_posts.updated_at <= pg_catalog.now() - pg_catalog.make_interval(
            secs => least(
              1800,
              (30 * pg_catalog.power(
                2,
                least(greatest(kpi.asc_report_posts.attempt - 1, 0), 6)
              ))::integer
            )
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
    if v_type not in ('flash', 'acquisition') or v_status not in ('posted', 'failed') then
      raise exception 'invalid finish';
    end if;
    update kpi.asc_report_posts
    set status = v_status,
        posted_at = case when v_status = 'posted' then pg_catalog.now() else posted_at end,
        updated_at = pg_catalog.now()
    where report_type = v_type
      and data_date = v_date
      and status = 'reserved';
    get diagnostics v_updated = row_count;
    return pg_catalog.jsonb_build_object('updated', v_updated = 1);
  end if;

  if p_op = 'save_sales' then
    v_date := (p_body->>'data_date')::date;
    insert into kpi.asc_daily_sales (
      data_date, new_downloads, redownloads, sales_jpy, proceeds_jpy,
      non_jpy_customer_rows, fetched_at
    ) values (
      v_date,
      (p_body->>'new_downloads')::integer,
      (p_body->>'redownloads')::integer,
      (p_body->>'sales_jpy')::numeric,
      (p_body->>'proceeds_jpy')::numeric,
      (p_body->>'non_jpy_customer_rows')::integer,
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set new_downloads = excluded.new_downloads,
          redownloads = excluded.redownloads,
          sales_jpy = excluded.sales_jpy,
          proceeds_jpy = excluded.proceeds_jpy,
          non_jpy_customer_rows = excluded.non_jpy_customer_rows,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_subscription' then
    v_date := (p_body->>'data_date')::date;
    if pg_catalog.jsonb_typeof(p_body->'plans') is distinct from 'array' then
      raise exception 'invalid plans';
    end if;
    delete from kpi.asc_daily_subscription where data_date = v_date;
    for v_item in select value from pg_catalog.jsonb_array_elements(p_body->'plans')
    loop
      v_plan := v_item->>'plan';
      if v_plan not in ('monthly', 'half_year', 'yearly', 'other') then
        raise exception 'invalid plan';
      end if;
      insert into kpi.asc_daily_subscription (
        data_date, plan, active_paid, active_trials, fetched_at
      ) values (
        v_date,
        v_plan,
        (v_item->>'active_paid')::integer,
        (v_item->>'active_trials')::integer,
        pg_catalog.now()
      );
    end loop;
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_events' then
    v_date := (p_body->>'data_date')::date;
    insert into kpi.asc_daily_sub_events (
      data_date, trial_starts, paid_conversions, cancellations, fetched_at
    ) values (
      v_date,
      (p_body->>'trial_starts')::integer,
      (p_body->>'paid_conversions')::integer,
      (p_body->>'cancellations')::integer,
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set trial_starts = excluded.trial_starts,
          paid_conversions = excluded.paid_conversions,
          cancellations = excluded.cancellations,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_reviews' then
    v_date := (p_body->>'data_date')::date;
    v_count := (p_body->>'review_count')::integer;
    v_excerpt := pg_catalog.left(
      pg_catalog.regexp_replace(coalesce(p_body->>'excerpt', ''), '[[:cntrl:]]', '', 'g'),
      120
    );
    insert into kpi.asc_daily_reviews (
      data_date, review_count, average_rating,
      star_1, star_2, star_3, star_4, star_5,
      excerpt, written_only, fetched_at
    ) values (
      v_date,
      v_count,
      case when v_count = 0 then null else (p_body->>'average_rating')::numeric end,
      (p_body->>'star_1')::integer,
      (p_body->>'star_2')::integer,
      (p_body->>'star_3')::integer,
      (p_body->>'star_4')::integer,
      (p_body->>'star_5')::integer,
      v_excerpt,
      true,
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set review_count = excluded.review_count,
          average_rating = excluded.average_rating,
          star_1 = excluded.star_1,
          star_2 = excluded.star_2,
          star_3 = excluded.star_3,
          star_4 = excluded.star_4,
          star_5 = excluded.star_5,
          excerpt = excluded.excerpt,
          written_only = true,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'save_analytics' then
    v_date := (p_body->>'data_date')::date;
    insert into kpi.asc_analytics_daily (
      data_date, impressions, product_page_views, source_search, source_other,
      downloads, conversion_rate, search_includes_ads, fetched_at
    ) values (
      v_date,
      (p_body->>'impressions')::integer,
      (p_body->>'product_page_views')::integer,
      (p_body->>'source_search')::integer,
      (p_body->>'source_other')::integer,
      (p_body->>'downloads')::integer,
      case
        when (p_body->>'impressions')::integer = 0 then null
        else (p_body->>'conversion_rate')::numeric
      end,
      coalesce((p_body->>'search_includes_ads')::boolean, true),
      pg_catalog.now()
    )
    on conflict (data_date) do update
      set impressions = excluded.impressions,
          product_page_views = excluded.product_page_views,
          source_search = excluded.source_search,
          source_other = excluded.source_other,
          downloads = excluded.downloads,
          conversion_rate = excluded.conversion_rate,
          search_includes_ads = excluded.search_includes_ads,
          fetched_at = pg_catalog.now();
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  if p_op = 'history' then
    return pg_catalog.jsonb_build_object(
      'sales', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'new_downloads', new_downloads,
          'redownloads', redownloads,
          'sales_jpy', sales_jpy,
          'proceeds_jpy', proceeds_jpy,
          'non_jpy_customer_rows', non_jpy_customer_rows
        ) order by data_date)
        from kpi.asc_daily_sales
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb),
      'subscriptions', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'plan', plan,
          'active_paid', active_paid,
          'active_trials', active_trials
        ) order by data_date, plan)
        from kpi.asc_daily_subscription
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb),
      'events', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'trial_starts', trial_starts,
          'paid_conversions', paid_conversions,
          'cancellations', cancellations
        ) order by data_date)
        from kpi.asc_daily_sub_events
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb),
      'reviews', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'review_count', review_count,
          'average_rating', average_rating,
          'star_1', star_1,
          'star_2', star_2,
          'star_3', star_3,
          'star_4', star_4,
          'star_5', star_5,
          'excerpt', excerpt
        ) order by data_date)
        from kpi.asc_daily_reviews
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb),
      'analytics', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'data_date', data_date,
          'impressions', impressions,
          'product_page_views', product_page_views,
          'source_search', source_search,
          'source_other', source_other,
          'downloads', downloads,
          'conversion_rate', conversion_rate,
          'search_includes_ads', search_includes_ads
        ) order by data_date)
        from kpi.asc_analytics_daily
        where data_date between (p_body->>'from')::date and (p_body->>'to')::date
      ), '[]'::jsonb)
    );
  end if;

  raise exception 'unknown op';
end;
$function$;

revoke all on function public.asc_daily_report_rpc(text, jsonb) from public, anon, authenticated;
grant execute on function public.asc_daily_report_rpc(text, jsonb) to service_role;

comment on function public.asc_daily_report_rpc(text, jsonb) is
  '日次レポートの保存と投稿予約。service_role だけ。秘密と投稿本文は保存しない。';
