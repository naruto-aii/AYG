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
  v_from_code text;
  v_from_name text;
  v_chain_mext boolean := false;
  v_food_id text;
  v_owner uuid;
  v_row_source text;
  v_next_food text;
  v_next_owner uuid;
  v_depth integer := 0;
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

  -- Follow copied_from through plain copies until a composition-table row.
  -- Row level security hides foods this role cannot read. The table owner
  -- is not rewritten, so rollback can relabel source_type to copied.
  -- Publishing a copy in that chain without provenance is rejected below.
  v_food_id := new.copied_from_food_id;
  v_owner := new.copied_from_owner_user_id;
  while v_food_id is not null and v_depth < 8 loop
    v_depth := v_depth + 1;
    select s.official_food_code, s.official_food_name, s.source_type,
           s.copied_from_food_id, s.copied_from_owner_user_id
      into v_from_code, v_from_name, v_row_source, v_next_food, v_next_owner
    from public.saved_foods s
    where s.food_id = v_food_id
      and (v_owner is null or s.user_id = v_owner)
    limit 1;
    exit when not found;
    if v_row_source = 'mext_sfct' or v_from_code is not null then
      v_chain_mext := true;
      exit;
    end if;
    exit when v_next_food is null or v_next_food = v_food_id;
    v_food_id := v_next_food;
    v_owner := v_next_owner;
  end loop;

  if v_chain_mext and not v_may_relabel then
    new.source_type := 'mext_sfct';
    new.official_food_code := v_from_code;
    new.official_food_name := v_from_name;
  end if;

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

  if v_chain_mext
     and new.visibility = 'public'
     and (
       new.source_type is distinct from 'mext_sfct'
       or new.official_food_code is null
       or new.official_food_name is null
       or new.source_attribution is distinct from
         '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成'
     ) then
    raise exception
      'publishing a composition-table copy requires mext_sfct attribution';
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

-- 20260927150000 (PR #29) revokes table INSERT/UPDATE and replaces them
-- with an explicit column list. Columns added after that list, including
-- these three, are then denied to authenticated and every My Food write
-- that mentions them fails. Column grants are redundant when the table
-- grant is still in place, and they do not widen access to other columns.
grant insert (
  official_food_code,
  official_food_name,
  source_attribution
), update (
  official_food_code,
  official_food_name,
  source_attribution
) on table public.saved_foods to authenticated;
