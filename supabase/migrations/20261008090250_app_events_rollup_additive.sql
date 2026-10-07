-- =====================================================================
-- 集計済みの月へ遅れて届いた操作を、足し算で残す
-- 置き場所: supabase/migrations/20261008090250_app_events_rollup_additive.sql
--
-- 本番の maintain_app_events（20261007094142）を置き換える。表は増やさない。
-- 20261008090300 の定期実行より先に適用する。
--
-- 受け付けは過去 100 日のままにする。生の表は 90 日より古い月を消すが、
-- 日次の集計は 2 年残る。100 日まで受けるのは、オフラインの再送を集計に
-- 残すため。90 日に縮めると、その再送自体が捨てられる。
--
-- 以前は、消す月の集計を消してから残っている行だけで作り直していた。
-- 集計済みの月に遅れた行が届くと、その月の集計が遅れた分だけになっていた。
-- 今は、今ある行の件数を既存の集計へ足してから表を消す。
-- 足した行は同じ処理で表ごと消える。同じ event_id と occurred_at は
-- insert_app_events が無視するので、もう一度足されない。
-- 足す処理と表の削除は同じトランザクションなので、途中で失敗したら両方戻る。
-- =====================================================================

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
  '90日より古い月の行を日次集計へ足してから表を消す。遅れて届いた行は既存の集計に足し、同じ行は二度足さない。';
