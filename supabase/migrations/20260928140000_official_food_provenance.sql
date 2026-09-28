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
declare
  -- Invoker, not definer: security definer would make current_user the
  -- owner and the lock would never apply. Rollback runs as postgres,
  -- service_role, or the table owner.
  v_may_relabel boolean;
begin
  v_may_relabel :=
    current_user in ('postgres', 'service_role')
    or current_user = (
      select pg_catalog.pg_get_userbyid(c.relowner)
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'saved_foods'
    );

  if tg_op = 'UPDATE'
     and old.source_type = 'mext_sfct'
     and not v_may_relabel then
    new.source_type := 'mext_sfct';
    new.official_food_code := old.official_food_code;
    new.official_food_name := old.official_food_name;
  end if;

  if new.source_type = 'mext_sfct' then
    if new.official_food_code is null or new.official_food_name is null then
      raise exception 'mext_sfct foods require official_food_code and official_food_name';
    end if;
    if not exists (
      select 1
      from public.official_foods f
      where f.food_code = new.official_food_code
    ) then
      raise exception 'mext_sfct official_food_code must exist in official_foods';
    end if;
    new.source_attribution :=
      '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_mext_food_entry_code()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.source_type = 'mext_sfct'
     and not exists (
       select 1
       from public.official_foods f
       where f.food_code = new.official_food_code
     ) then
    raise exception 'mext_sfct official_food_code must exist in official_foods';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_mext_saved_food_attribution on public.saved_foods;
create trigger enforce_mext_saved_food_attribution
  before insert or update on public.saved_foods
  for each row
  execute function public.enforce_mext_saved_food_attribution();

drop trigger if exists enforce_mext_food_entry_code on public.food_entries;
create trigger enforce_mext_food_entry_code
  before insert or update on public.food_entries
  for each row
  execute function public.enforce_mext_food_entry_code();

-- Trigger functions must be executable by the role that writes the row.
revoke all on function public.enforce_mext_saved_food_attribution() from public, anon, authenticated;
revoke all on function public.enforce_mext_food_entry_code() from public, anon, authenticated;
grant execute on function public.enforce_mext_saved_food_attribution() to authenticated;
grant execute on function public.enforce_mext_food_entry_code() to authenticated;
