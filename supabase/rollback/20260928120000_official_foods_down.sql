-- Reverse 20260928120000_official_foods.sql.
-- Does not drop pg_trgm. Official rows go away with the tables.
-- Private saved_foods copies that used source_type mext_sfct are relabeled
-- copied so the previous check constraint can be restored. They are not deleted.

drop function if exists public.search_official_foods(text, integer);
drop function if exists public.normalize_food_search_text(text);

drop table if exists public.official_food_aliases;
drop table if exists public.official_foods;

-- The attribution trigger allows this relabel when the current user is
-- postgres, service_role, or the saved_foods owner. Run this script as
-- that role. The new source is copied, so the food-code check does not
-- look up official_foods. Provenance down should still run first.
update public.saved_foods
set source_type = 'copied'
where source_type = 'mext_sfct';

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
      and rel.relname = 'saved_foods'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%source_type%'
  loop
    execute format('alter table public.saved_foods drop constraint %I', cname);
  end loop;
end
$$;

alter table public.saved_foods
  add constraint saved_foods_source_type_check
  check (
    source_type in (
      'manual',
      'open_food_facts',
      'open_food_facts_derived',
      'copied'
    )
  );
