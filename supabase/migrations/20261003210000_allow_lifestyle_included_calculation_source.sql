-- 生活活動（家事、掃除）は calculation_source に lifestyle_included を書く。
-- 列は足さない。既存の列は消さない。既存の行は更新しない。truncate しない。
-- このファイルをこのエージェントから本番へは適用しない。

begin;

do $$
declare
  cname text;
begin
  for cname in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'exercise_entries'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%calculation_source%'
  loop
    execute format(
      'alter table public.exercise_entries drop constraint %I',
      cname
    );
  end loop;
end
$$;

alter table public.exercise_entries
  add constraint exercise_entries_calculation_source_check
  check (
    calculation_source is null
    or calculation_source in (
      'met_estimate',
      'manual_override',
      'template',
      'lifestyle_included'
    )
  );

comment on column public.exercise_entries.calculation_source is
  'met_estimate、manual_override、template、lifestyle_included。生活活動の追加消費は 0。';

commit;
