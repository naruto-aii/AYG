-- Food code, official name, and source attribution for composition-table
-- copies. Meal rows and My Foods each get their own columns. The food code
-- is not stored in supplementary_weight.
--
-- A My Food with source_type mext_sfct may be published. The attribution
-- text is written by the trigger and cannot be cleared or replaced.

alter table public.saved_foods
  add column official_food_code text,
  add column official_food_name text,
  add column source_attribution text;

alter table public.saved_foods
  add constraint saved_foods_official_food_code_check
  check (official_food_code is null or official_food_code ~ '^[0-9]{5}$');

alter table public.food_entries
  add column official_food_code text,
  add column official_food_name text;

alter table public.food_entries
  add constraint food_entries_official_food_code_check
  check (official_food_code is null or official_food_code ~ '^[0-9]{5}$');

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
      'open_food_facts',
      'mext_sfct'
    )
  );

create or replace function public.enforce_mext_saved_food_attribution()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Official-foods rollback relabels mext_sfct to copied. That script sets
  -- this flag so the attribution lock does not block the relabel.
  if pg_catalog.current_setting('ayg.allow_mext_source_change', true) = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.source_type = 'mext_sfct' then
    new.source_type := 'mext_sfct';
    new.official_food_code := old.official_food_code;
    new.official_food_name := old.official_food_name;
  end if;

  if new.source_type = 'mext_sfct' then
    if new.official_food_code is null or new.official_food_name is null then
      raise exception 'mext_sfct foods require official_food_code and official_food_name';
    end if;
    new.source_attribution :=
      '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_mext_saved_food_attribution on public.saved_foods;
create trigger enforce_mext_saved_food_attribution
  before insert or update on public.saved_foods
  for each row
  execute function public.enforce_mext_saved_food_attribution();

revoke all on function public.enforce_mext_saved_food_attribution() from public, anon, authenticated;
