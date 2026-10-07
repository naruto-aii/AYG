-- =====================================================================
-- 集計済みの月の操作は、受け付けない
-- 置き場所: supabase/migrations/20261008090260_app_events_closed_month.sql
--
-- 本番の insert_app_events と maintain_app_events を置き換える。
-- 20261008090300 の定期実行より先に適用する。
--
-- 月を集計して表を消したあと、同じ event_id と occurred_at が再送されると
-- 行がもう無いので再び入り、次の集計で二重に足されていた。
-- 集計する月（またはそれより古い月）は、追加の時点で弾く。
-- 境界は public.app_event_month_is_aggregated だけが決める。
-- 受け付けも削除も、この関数を使う。
--
-- 戻り値は {"inserted","rejected","rejected_event_ids"}。
-- 弾いた行はアプリがキューから捨て、再送しない。
-- 未来 36 時間より先は、これまで通り誤りとして拒否する。
-- =====================================================================

create or replace function public.app_event_month_is_aggregated(p_occurred_at timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $fn$
  select (
    (date_trunc('month', p_occurred_at at time zone 'utc') + interval '1 month')
    at time zone 'utc'
  ) <= (pg_catalog.now() - interval '90 days');
$fn$;

revoke all on function public.app_event_month_is_aggregated(timestamptz)
  from public, anon, authenticated;

comment on function public.app_event_month_is_aggregated(timestamptz) is
  'その時刻の月を maintain_app_events が集計対象にするなら true。月の終わりが今から90日以上前。';

drop function public.insert_app_events(jsonb);

create function public.insert_app_events(events jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  uid uuid := auth.uid();
  inserted_count integer := 0;
  rejected_count integer := 0;
  rejected_ids uuid[] := array[]::uuid[];
  item jsonb;
  n integer;
  row_event_id uuid;
  row_occurred_at timestamptz;
  month_start date;
  months date[] := array[]::date[];
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if events is null or jsonb_typeof(events) is distinct from 'array' then
    raise exception 'events must be a json array' using errcode = '22023';
  end if;
  n := jsonb_array_length(events);
  if n = 0 then
    return jsonb_build_object(
      'inserted', 0,
      'rejected', 0,
      'rejected_event_ids', '[]'::jsonb
    );
  end if;
  if n > 100 then
    raise exception 'too many events' using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(events) loop
    row_event_id := (item->>'event_id')::uuid;
    row_occurred_at := (item->>'occurred_at')::timestamptz;
    if row_event_id is null or row_occurred_at is null then
      raise exception 'event_id and occurred_at are required' using errcode = '22023';
    end if;
    if public.app_event_month_is_aggregated(row_occurred_at) then
      rejected_count := rejected_count + 1;
      rejected_ids := array_append(rejected_ids, row_event_id);
      continue;
    end if;
    if row_occurred_at > pg_catalog.now() + interval '36 hours' then
      raise exception 'occurred_at out of range' using errcode = '22023';
    end if;
    month_start := (date_trunc('month', row_occurred_at at time zone 'utc'))::date;
    if not month_start = any (months) then
      months := array_append(months, month_start);
    end if;
  end loop;

  foreach month_start in array months loop
    perform public.ensure_app_events_partition(month_start);
  end loop;

  with incoming as (
    select
      (payload->>'event_id')::uuid as event_id,
      uid as user_id,
      payload->>'event_name' as event_name,
      (payload->>'occurred_at')::timestamptz as occurred_at,
      nullif(payload->>'client_sent_at', '')::timestamptz as client_sent_at,
      payload->>'origin' as origin,
      (payload->>'install_id')::uuid as install_id,
      nullif(payload->>'session_id', '')::uuid as session_id,
      payload->>'stream' as stream,
      (payload->>'sequence_number')::bigint as sequence_number,
      payload->>'app_version' as app_version,
      payload->>'app_build' as app_build,
      nullif(payload->>'os_version', '') as os_version,
      nullif(payload->>'device_model', '') as device_model,
      nullif(payload->>'locale', '') as locale,
      nullif(payload->>'time_zone', '') as time_zone,
      coalesce(nullif(payload->>'schema_version', '')::smallint, 1) as schema_version,
      case
        when payload->'props' is null or jsonb_typeof(payload->'props') = 'null'
          then '{}'::jsonb
        else payload->'props'
      end as props,
      false as advertising_use
    from jsonb_array_elements(events) as payload
    where not public.app_event_month_is_aggregated(
      (payload->>'occurred_at')::timestamptz
    )
  ),
  written as (
    insert into public.app_events (
      event_id,
      user_id,
      event_name,
      occurred_at,
      client_sent_at,
      origin,
      install_id,
      session_id,
      stream,
      sequence_number,
      app_version,
      app_build,
      os_version,
      device_model,
      locale,
      time_zone,
      schema_version,
      props,
      advertising_use
    )
    select
      incoming.event_id,
      incoming.user_id,
      incoming.event_name,
      incoming.occurred_at,
      incoming.client_sent_at,
      incoming.origin,
      incoming.install_id,
      incoming.session_id,
      incoming.stream,
      incoming.sequence_number,
      incoming.app_version,
      incoming.app_build,
      incoming.os_version,
      incoming.device_model,
      incoming.locale,
      incoming.time_zone,
      incoming.schema_version,
      incoming.props,
      incoming.advertising_use
    from incoming
    on conflict (event_id, occurred_at) do nothing
    returning 1
  )
  select count(*)::integer into inserted_count from written;

  return jsonb_build_object(
    'inserted', inserted_count,
    'rejected', rejected_count,
    'rejected_event_ids', to_jsonb(rejected_ids)
  );
end;
$function$;

revoke all on function public.insert_app_events(jsonb) from public, anon, authenticated;
grant execute on function public.insert_app_events(jsonb) to authenticated;

comment on function public.insert_app_events(jsonb) is
  '本人の操作を追加する。集計済みの月は弾き、その event_id を戻り値に入れる。user_id は auth.uid() で上書きする。';

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
begin
  perform pg_catalog.pg_advisory_xact_lock(908030250);

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
  where public.app_event_month_is_aggregated(range_start);

  foreach part_name in array part_names loop
    select range_start, range_end
    into part_range_start, part_range_end
    from public.app_event_partitions
    where partition_name = part_name;
    if part_range_start is null or part_range_end is null then
      continue;
    end if;

    execute format(
      $rollup$
        insert into public.app_event_daily_totals (day, event_name, origin, event_count)
        select (occurred_at at time zone 'utc')::date, event_name, origin, count(*)
        from public.%I
        group by 1, 2, 3
        on conflict (day, event_name, origin) do update
          set event_count = public.app_event_daily_totals.event_count + excluded.event_count
      $rollup$,
      part_name
    );

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
        on conflict (user_id, day) do update
          set event_count = public.app_event_user_days.event_count + excluded.event_count,
              events = coalesce((
                select jsonb_object_agg(merged.key, merged.total)
                from (
                  select e.key, sum((e.value #>> '{}')::bigint) as total
                  from (
                    select key, value
                    from jsonb_each(public.app_event_user_days.events)
                    union all
                    select key, value
                    from jsonb_each(excluded.events)
                  ) e
                  group by e.key
                ) merged
              ), '{}'::jsonb)
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

comment on function public.maintain_app_events() is
  'app_event_month_is_aggregated が真の月を日次集計へ足してから表を消す。';
