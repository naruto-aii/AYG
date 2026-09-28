-- Reverse 20260928120000_official_foods.sql.
-- Does not drop pg_trgm. Official rows go away with the tables.
-- Private saved_foods copies that used source_type mext_sfct are relabeled
-- copied so the previous check constraint can be restored. They are not deleted.
--
-- This file is one transaction. Run the provenance down first and commit it
-- before this file. If provenance triggers or columns are still installed,
-- this script stops before dropping official_foods. Otherwise the food-entry
-- trigger keeps querying that table and every meal insert fails, including
-- manual ones, while the official-foods down still commits when no public
-- composition-table copy blocks the source relabel.

begin;

do $require_provenance_down$
begin
  if to_regprocedure('public.enforce_mext_saved_food_attribution()') is not null
     or to_regprocedure('public.enforce_mext_food_entry_code()') is not null
     or exists (
       select 1
       from pg_catalog.pg_trigger t
       join pg_catalog.pg_class c on c.oid = t.tgrelid
       join pg_catalog.pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public'
         and c.relname in ('saved_foods', 'food_entries')
         and t.tgname in (
           'enforce_mext_saved_food_attribution',
           'enforce_mext_food_entry_code'
         )
         and not t.tgisinternal
     )
     or exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and (
           (
             table_name = 'saved_foods'
             and column_name in (
               'official_food_code',
               'official_food_name',
               'source_attribution'
             )
           )
           or (
             table_name = 'food_entries'
             and column_name in ('official_food_code', 'official_food_name')
           )
         )
     ) then
    raise exception
      'provenance objects from 20260928140000 are still installed; run supabase/rollback/20260928140000_official_food_provenance_down.sql first. Dropping official_foods while enforce_mext_food_entry_code remains makes every food_entries insert fail, including manual meals';
  end if;
end
$require_provenance_down$;

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

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.saved_foods'::regclass
      and conname = 'saved_foods_source_type_check'
  ) then
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
  end if;
end
$$;

commit;
