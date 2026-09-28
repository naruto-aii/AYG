-- Reverse 20260928140000_official_food_provenance.sql.
-- Meal rows and My Foods stay. The composition-table columns go away.
-- food_entries.source_type mext_sfct is relabeled manual so the previous
-- check can be restored. saved_foods.source_type is left for the official
-- foods down script.
--
-- Before any column is dropped, every public My Food that is composition-table
-- derived (itself, or through copied_from) becomes private. The rows stay.

update public.saved_foods as sf
set visibility = 'private'
where sf.visibility = 'public'
  and (
    sf.source_type = 'mext_sfct'
    or sf.official_food_code is not null
    or sf.source_attribution is not null
    or exists (
      with recursive walk as (
        select
          s.food_id,
          s.user_id,
          s.copied_from_food_id,
          s.copied_from_owner_user_id,
          s.source_type,
          s.official_food_code,
          s.source_attribution,
          1 as depth
        from public.saved_foods s
        where s.user_id = sf.user_id
          and s.food_id = sf.food_id
        union all
        select
          p.food_id,
          p.user_id,
          p.copied_from_food_id,
          p.copied_from_owner_user_id,
          p.source_type,
          p.official_food_code,
          p.source_attribution,
          walk.depth + 1
        from walk
        join public.saved_foods p
          on p.food_id = walk.copied_from_food_id
         and (
           walk.copied_from_owner_user_id is null
           or p.user_id = walk.copied_from_owner_user_id
         )
        where walk.depth < 8
          and walk.source_type is distinct from 'mext_sfct'
          and walk.official_food_code is null
          and walk.source_attribution is null
      )
      select 1
      from walk
      where walk.source_type = 'mext_sfct'
         or walk.official_food_code is not null
         or walk.source_attribution is not null
    )
  );

drop trigger if exists enforce_mext_food_entry_code on public.food_entries;
drop trigger if exists enforce_mext_saved_food_attribution on public.saved_foods;
drop function if exists public.enforce_mext_food_entry_code();
drop function if exists public.enforce_mext_saved_food_attribution();

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
