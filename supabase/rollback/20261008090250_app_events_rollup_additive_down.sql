-- maintain_app_events を、本番の 20261007094142 の定義に戻す。
-- 集計は、消す月の行を消してから作り直す動きに戻る。表と行は消さない。
-- 定期実行 20261008090300 を戻したあとに、このファイルを流す。

begin;

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

commit;
