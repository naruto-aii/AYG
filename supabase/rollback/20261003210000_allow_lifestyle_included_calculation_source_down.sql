-- lifestyle_included を許可した制約だけを、元の3値へ戻す。
-- その値の行があるときは、行を消さずに失敗する。列は消さない。
-- 2回実行しても、行が無ければ失敗しない。

begin;

do $$
declare
  cname text;
begin
  if exists (
    select 1
    from public.exercise_entries
    where calculation_source = 'lifestyle_included'
  ) then
    raise exception
      'lifestyle_included rows exist; refusing to narrow the check or delete them';
  end if;

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
      'template'
    )
  );

commit;
