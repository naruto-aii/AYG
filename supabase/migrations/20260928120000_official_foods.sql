-- Official MEXT food composition rows and search aliases.
-- Does not reuse saved_foods (that table is user-owned UGC).
-- Timestamp is after every migration in PRs #25-#29 (latest there is
-- 20260927180000) so this file sorts last when those migrations are
-- applied in the same batch.
--
-- The banned-word trigger from PR #26 is attached to saved_foods only.
-- Official rows are not user-generated and clients cannot write them,
-- so that trigger is not installed here.

create schema if not exists extensions;

do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_trgm') then
    create extension pg_trgm with schema extensions;
  end if;
end
$$;

create table public.official_foods (
  food_code text primary key check (food_code ~ '^[0-9]{5}$'),
  food_group text,
  index_no text,
  name text not null,
  display_name text,
  normalized_name text not null,
  reading text,
  base_amount numeric not null default 100,
  unit_type text not null default 'g',
  refuse_pct numeric,
  kcal numeric,
  protein_g numeric,
  protein_aa_g numeric,
  fat_g numeric,
  fat_tag_g numeric,
  carb_g numeric,
  carb_avail_g numeric,
  fiber_g numeric,
  salt_eq_g numeric,
  raw_values jsonb,
  estimated_fields text[],
  source text not null default 'mext_sfct',
  edition text not null default '八訂増補2023',
  errata_version text,
  source_url text,
  imported_at timestamptz not null default now()
);

create table public.official_food_aliases (
  id bigserial primary key,
  food_code text not null references public.official_foods (food_code) on delete cascade,
  alias text not null,
  reading text,
  normalized text not null,
  priority integer not null default 100,
  note text,
  source text not null default 'karonavi_alias_v1',
  -- One alias text may point at several foods. is_candidate marks a row the
  -- user still has to choose. Confirmed aliases keep is_candidate false and
  -- sort ahead of candidates. candidate_rank orders candidates of one alias.
  is_candidate boolean not null default false,
  candidate_rank integer,
  unique (food_code, normalized)
);

-- pg_trgm may already live in `extensions` (Supabase) or `public`.
do $$
declare
  opschema text;
begin
  select n.nspname into opschema
  from pg_opclass c
  join pg_namespace n on n.oid = c.opcnamespace
  where c.opcname = 'gin_trgm_ops'
  order by case when n.nspname = 'extensions' then 0 else 1 end
  limit 1;

  if opschema is null then
    raise exception 'gin_trgm_ops is missing after creating pg_trgm';
  end if;

  execute format(
    'create index official_foods_normalized_name_trgm_idx on public.official_foods using gin (normalized_name %I.gin_trgm_ops)',
    opschema
  );
  execute format(
    'create index official_foods_reading_trgm_idx on public.official_foods using gin (reading %I.gin_trgm_ops)',
    opschema
  );
  execute format(
    'create index official_food_aliases_normalized_trgm_idx on public.official_food_aliases using gin (normalized %I.gin_trgm_ops)',
    opschema
  );
  execute format(
    'create index official_food_aliases_reading_trgm_idx on public.official_food_aliases using gin (reading %I.gin_trgm_ops)',
    opschema
  );
end
$$;

-- Search key shared with lib/utils/food_search_normalizer.dart.
-- NFKC, halfwidth kana to fullwidth (via NFKC, after composing dakuten),
-- katakana to hiragana, lower case, drop long-vowel marks and hyphens,
-- drop whitespace. Does not call normalize_public_food_name: that
-- function keeps spaces and the long vowel, and it ships only with PR #26.
create or replace function public.normalize_food_search_text(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_text, '');
  v_out text := '';
  i integer := 1;
  n integer;
  ch text;
  nxt text;
  cp integer;
  base_at integer;
  dakuten_base constant text := 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';
  dakuten_to constant text := 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ';
  handakuten_base constant text := 'ﾊﾋﾌﾍﾎ';
  handakuten_to constant text := 'パピプペポ';
begin
  n := pg_catalog.char_length(v);
  while i <= n loop
    ch := pg_catalog.substr(v, i, 1);
    if i < n then
      nxt := pg_catalog.substr(v, i + 1, 1);
      if nxt = pg_catalog.chr(65438) then
        base_at := pg_catalog.strpos(dakuten_base, ch);
        if base_at > 0 then
          v_out := v_out || pg_catalog.substr(dakuten_to, base_at, 1);
          i := i + 2;
          continue;
        end if;
      elsif nxt = pg_catalog.chr(65439) then
        base_at := pg_catalog.strpos(handakuten_base, ch);
        if base_at > 0 then
          v_out := v_out || pg_catalog.substr(handakuten_to, base_at, 1);
          i := i + 2;
          continue;
        end if;
      end if;
    end if;
    v_out := v_out || ch;
    i := i + 1;
  end loop;

  v := pg_catalog.normalize(v_out, 'NFKC');
  v_out := '';
  n := pg_catalog.char_length(v);
  for i in 1..n loop
    ch := pg_catalog.substr(v, i, 1);
    cp := pg_catalog.ascii(ch);

    if cp between 12449 and 12534 then
      cp := cp - 96;
      ch := pg_catalog.chr(cp);
    end if;

    if cp between 65 and 90 then
      cp := cp + 32;
      ch := pg_catalog.chr(cp);
    end if;

    -- Long vowel and hyphen-like marks.
    if cp = 12540
       or cp = 45
       or cp = 8208
       or cp = 8209
       or cp = 8211
       or cp = 8212
       or cp = 8722 then
      continue;
    end if;

    -- Whitespace, including leftovers NFKC did not fold.
    if cp = 9 or cp = 10 or cp = 11 or cp = 12 or cp = 13
       or cp = 32 or cp = 133 or cp = 160
       or cp = 5760
       or cp between 8192 and 8202
       or cp = 8232 or cp = 8233 or cp = 8239
       or cp = 8287 or cp = 12288 or cp = 65279 then
      continue;
    end if;

    v_out := v_out || ch;
  end loop;

  return v_out;
end;
$$;

create or replace function public.search_official_foods(
  p_query text,
  p_limit integer default 30
)
returns table (
  food_code text,
  food_group text,
  index_no text,
  name text,
  display_name text,
  reading text,
  base_amount numeric,
  unit_type text,
  refuse_pct numeric,
  kcal numeric,
  protein_g numeric,
  fat_g numeric,
  carb_g numeric,
  fiber_g numeric,
  salt_eq_g numeric,
  matched_alias text,
  matched_alias_reading text,
  match_rank integer,
  is_candidate boolean,
  candidate_rank integer
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  -- Character cap, same as OfficialFoodLimits.maxQueryLength. Applied
  -- before normalization so a huge argument never enters the per-character
  -- loop. The pattern is inlined as a literal so the planner can use the
  -- gin_trgm_ops indexes on the stored columns.
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_query text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_pattern text;
  v_limit integer := least(greatest(coalesce(p_limit, 30), 0), 100);
begin
  if v_query = '' or v_limit = 0 then
    return;
  end if;

  v_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(
           pg_catalog.replace(v_query, '\', '\\'),
           '%',
           '\%'
         ),
         '_',
         '\_'
       )
    || '%';

  -- One indexed column per arm. OR would hide the index, and wrapping the
  -- column in normalize_food_search_text would too. normalized_name and
  -- aliases.normalized are already the search key. reading is stored text
  -- (hiragana in the alias dictionary) and is compared as stored.
  return query execute format(
    $sql$
    with hits as (
      select
        f.food_code,
        f.food_group,
        f.index_no,
        f.name,
        f.display_name,
        f.reading,
        f.base_amount,
        f.unit_type,
        f.refuse_pct,
        f.kcal,
        f.protein_g,
        f.fat_g,
        f.carb_g,
        f.fiber_g,
        f.salt_eq_g,
        null::text as matched_alias,
        null::text as matched_alias_reading,
        100 as priority,
        false as is_candidate,
        null::integer as candidate_rank,
        case
          when f.normalized_name = %L then 0
          when pg_catalog.strpos(f.normalized_name, %L) = 1 then 1
          when pg_catalog.strpos(f.normalized_name, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_foods f
      where f.normalized_name like %L escape '\'
      union all
      select
        f.food_code,
        f.food_group,
        f.index_no,
        f.name,
        f.display_name,
        f.reading,
        f.base_amount,
        f.unit_type,
        f.refuse_pct,
        f.kcal,
        f.protein_g,
        f.fat_g,
        f.carb_g,
        f.fiber_g,
        f.salt_eq_g,
        null::text as matched_alias,
        null::text as matched_alias_reading,
        100 as priority,
        false as is_candidate,
        null::integer as candidate_rank,
        case
          when f.reading = %L then 0
          when pg_catalog.strpos(f.reading, %L) = 1 then 1
          when pg_catalog.strpos(f.reading, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_foods f
      where f.reading like %L escape '\'
      union all
      select
        f.food_code,
        f.food_group,
        f.index_no,
        f.name,
        f.display_name,
        f.reading,
        f.base_amount,
        f.unit_type,
        f.refuse_pct,
        f.kcal,
        f.protein_g,
        f.fat_g,
        f.carb_g,
        f.fiber_g,
        f.salt_eq_g,
        a.alias,
        a.reading,
        a.priority,
        a.is_candidate,
        a.candidate_rank,
        case
          when a.normalized = %L then 0
          when pg_catalog.strpos(a.normalized, %L) = 1 then 1
          when pg_catalog.strpos(a.normalized, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_food_aliases a
      join public.official_foods f on f.food_code = a.food_code
      where a.normalized like %L escape '\'
      union all
      select
        f.food_code,
        f.food_group,
        f.index_no,
        f.name,
        f.display_name,
        f.reading,
        f.base_amount,
        f.unit_type,
        f.refuse_pct,
        f.kcal,
        f.protein_g,
        f.fat_g,
        f.carb_g,
        f.fiber_g,
        f.salt_eq_g,
        a.alias,
        a.reading,
        a.priority,
        a.is_candidate,
        a.candidate_rank,
        case
          when a.reading = %L then 0
          when pg_catalog.strpos(a.reading, %L) = 1 then 1
          when pg_catalog.strpos(a.reading, %L) > 0 then 2
          else 9
        end as rank_value
      from public.official_food_aliases a
      join public.official_foods f on f.food_code = a.food_code
      where a.reading like %L escape '\'
    ),
    matched as (
      select *
      from hits
      where rank_value < 9
    ),
    best as (
      select distinct on (matched.food_code)
        matched.*
      from matched
      order by
        matched.food_code,
        matched.rank_value,
        matched.is_candidate,
        matched.candidate_rank nulls last,
        (matched.matched_alias is null),
        matched.priority,
        matched.matched_alias
    )
    select
      best.food_code,
      best.food_group,
      best.index_no,
      best.name,
      best.display_name,
      best.reading,
      best.base_amount,
      best.unit_type,
      best.refuse_pct,
      best.kcal,
      best.protein_g,
      best.fat_g,
      best.carb_g,
      best.fiber_g,
      best.salt_eq_g,
      best.matched_alias,
      best.matched_alias_reading,
      best.rank_value,
      best.is_candidate,
      best.candidate_rank
    from best
    order by
      best.rank_value,
      best.is_candidate,
      best.candidate_rank nulls last,
      (best.matched_alias is null),
      best.priority,
      best.food_code
    limit %s
    $sql$,
    v_query, v_query, v_query, v_pattern,
    v_query, v_query, v_query, v_pattern,
    v_query, v_query, v_query, v_pattern,
    v_query, v_query, v_query, v_pattern,
    v_limit
  );
end;
$$;

alter table public.official_foods enable row level security;
alter table public.official_food_aliases enable row level security;

drop policy if exists official_foods_select_authenticated on public.official_foods;
create policy official_foods_select_authenticated
  on public.official_foods
  for select
  to authenticated
  using (true);

drop policy if exists official_food_aliases_select_authenticated
  on public.official_food_aliases;
create policy official_food_aliases_select_authenticated
  on public.official_food_aliases
  for select
  to authenticated
  using (true);

revoke all on table public.official_foods from public, anon, authenticated;
revoke all on table public.official_food_aliases from public, anon, authenticated;
grant select on table public.official_foods to authenticated;
grant select on table public.official_food_aliases to authenticated;
revoke insert, update, delete, truncate on table public.official_foods from anon, authenticated;
revoke insert, update, delete, truncate on table public.official_food_aliases from anon, authenticated;

revoke all on sequence public.official_food_aliases_id_seq from public, anon, authenticated;

revoke all on function public.normalize_food_search_text(text) from public, anon, authenticated;
grant execute on function public.normalize_food_search_text(text) to authenticated;

revoke all on function public.search_official_foods(text, integer) from public, anon, authenticated;
grant execute on function public.search_official_foods(text, integer) to authenticated;

-- Allow private copies of an official food. Down migration removes the value.
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
      'copied',
      'mext_sfct'
    )
  );
