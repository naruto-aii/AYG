-- Reverse 20260928140000_official_food_provenance.sql.
-- Meal rows and My Foods stay. The composition-table columns go away.
-- food_entries.source_type mext_sfct is relabeled manual so the previous
-- check can be restored. saved_foods.source_type is left for the official
-- foods down script.

drop trigger if exists enforce_mext_food_entry_code on public.food_entries;
drop trigger if exists enforce_mext_saved_food_attribution on public.saved_foods;
drop function if exists public.enforce_mext_food_entry_code();
drop function if exists public.enforce_mext_saved_food_attribution();

-- source_attribution is about to disappear. Take published composition-table
-- foods off the public catalog first, so official-derived values do not stay
-- public with no attribution. Private rows are kept and relabeled later.
update public.saved_foods
set visibility = 'private'
where source_type = 'mext_sfct'
  and visibility = 'public';

alter table public.saved_foods
  drop constraint if exists saved_foods_official_food_code_check;
alter table public.saved_foods
  drop column if exists source_attribution,
  drop column if exists official_food_name,
  drop column if exists official_food_code;

update public.food_entries
set source_type = 'manual'
where source_type = 'mext_sfct';

alter table public.food_entries
  drop constraint if exists food_entries_official_food_code_check;
alter table public.food_entries
  drop column if exists official_food_name,
  drop column if exists official_food_code;

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
      and rel.relname = 'food_entries'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%source_type%'
  loop
    execute format('alter table public.food_entries drop constraint %I', cname);
  end loop;
end
$$;

alter table public.food_entries
  add constraint food_entries_source_type_check
  check (
    source_type is null
    or source_type in (
      'manual',
      'saved_food',
      'template',
      'open_food_facts'
    )
  );
