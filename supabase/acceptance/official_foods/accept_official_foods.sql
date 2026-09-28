-- Black-box acceptance for the MEXT official-foods import. Read-only against
-- user data: the only writes are denied-by-design probes (INSERT/UPDATE/DELETE/
-- TRUNCATE as anon and authenticated) inside subtransactions that roll back.
-- A passing run leaves official_foods, official_food_aliases, and every
-- pre-existing user table unchanged.
--
-- Run AFTER the feature migration and the data import, in the same database
-- you snapshotted with snapshot_user_tables.sql. Paste that jsonb into
-- v_baseline below. Use the same git revision of these files for both steps.
--
-- Success: this script returns one row, status = PASS, and raises no error.
-- Failure: an exception whose message starts with "ACCEPTANCE FAIL:".
-- Do not treat a notice as a pass. Do not commit this file with a production
-- snapshot pasted in.
--
-- Aligned to PR #31 (cursor/official-foods-import-0702 @ 5eab90b).
-- Apply order after the snapshot:
--   supabase/migrations/20260928120000_official_foods.sql
--   supabase/migrations/20260928140000_official_food_provenance.sql
-- search_official_foods orders by rank_value, so v_rank_column stays null.
-- It is security definer with an empty search_path: authenticated cannot
-- execute normalize_food_search_text (capped at 256), and search is the
-- caller. v_exclude_* ignores brand-new objects only; it cannot silence a
-- change to a table that already existed. v_ignore_signature_for is the
-- only signature waiver, and row counts still have to match. 20260928120000
-- replaces saved_foods_source_type_check to add mext_sfct. 20260928140000
-- adds official_food_code, official_food_name, and source_attribution on
-- saved_foods, and official_food_code plus official_food_name on
-- food_entries (and mext_sfct on that table's source_type check). Those are
-- reviewed signature changes. Neither table is new, so neither name belongs
-- in v_exclude_tables. enforce_mext_saved_food_attribution and
-- enforce_mext_food_entry_code belong in v_exclude_routines. The attribution
-- lock follows current_user (postgres, service_role, or the table owner may
-- relabel). A session GUC does not bypass it.
--
-- Values below were read from the official workbook on 2026-09-28, sheet
-- 表全体, component id ENERC_KCAL (per 100 g edible portion), not from memory.
--   https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_02.xlsx
--   sha256 0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c
--   5-digit food numbers: 2538 unique
-- The 2026-03-27 errata workbook is already reflected in that xlsx. 11183
-- ENERC_KCAL is 241 (errata sheet 本表第2章 records the previous 244 as 誤).
--   https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_16.xlsx
--   sha256 fb61037c7f66af0db1fb0729977913a629bc17097bc3ff7bf75217f9110acabb
-- 01088 is cooked rice (水稲めし・精白米), 156 kcal. 01083 is the raw grain,
-- 342 kcal. Names keep the workbook's ideographic spaces (U+3000), including
-- the trailing U+3000 on 11183.

begin;
set local statement_timeout = '120s';
set local lock_timeout = '3s';

do $accept$
declare
  -- =========================================================================
  -- CONFIG. Change names here when the feature PR lands. Do not scatter
  -- renames through the checks below.
  -- =========================================================================
  v_baseline jsonb := null;
  -- Replace the line above with the snapshot (one line), for example:
  --   v_baseline jsonb := $of_baseline$
  --   {"kind":"official_foods_user_table_snapshot",...}
  --   $of_baseline$::jsonb;

  v_schema text := 'public';
  v_foods_table text := 'official_foods';
  v_aliases_table text := 'official_food_aliases';
  v_food_code_col text := 'food_code';
  v_name_col text := 'name';
  v_kcal_col text := 'kcal';
  v_source_col text := 'source';
  v_edition_col text := 'edition';
  v_base_amount_col text := 'base_amount';
  v_unit_type_col text := 'unit_type';
  v_check_base_amount boolean := true;
  v_expected_base_amount numeric := 100;
  v_expected_unit text := 'g';
  v_source text := 'mext_sfct';
  v_edition text := '八訂増補2023';
  v_expected_count bigint := 2538;
  v_expected_total bigint := 2538; -- raise only when a second edition is loaded on purpose

  v_norm_fn text := 'normalize_food_search_text';
  v_search_fn text := 'search_official_foods';
  v_out_food_code text := 'food_code';
  v_rank_column text := null; -- null: trust the RPC's returned order. Set a column name only if it does not.
  v_rank_ascending boolean := true;
  v_search_limit int := 30;
  v_search_limit_cap int := 30;
  v_expect_first text := '01088';

  v_gyudon_query text := '牛丼';
  v_gyudon_codes text[] := array['18031', '01088'];

  v_anon_role text := 'anon';
  v_auth_role text := 'authenticated';
  v_anon_may_select boolean := false;
  v_auth_may_select boolean := true;
  v_live_dml_probe boolean := true;

  -- ~64 character search cap. The normalizer itself stops at 256 and is
  -- not executable by anon or authenticated. Do not raise either cap.
  v_search_input_cap int := 64;
  v_require_search_input_cap boolean := true;
  v_norm_input_cap int := 256;

  -- Provenance from 20260928140000 on meal rows (food_entries) and My Foods
  -- (saved_foods), and the non-removable full sentence on a published
  -- mext_sfct food. The compact UI fallback is not stored.
  v_require_published_attribution boolean := true;
  v_meal_table text := 'food_entries';
  v_my_foods_table text := 'saved_foods';
  v_prov_code_col text := 'official_food_code';
  v_prov_name_col text := 'official_food_name';
  v_prov_source_col text := 'source_type';
  v_attr_col text := 'source_attribution';
  v_published_attribution text :=
    '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';

  v_require_trgm boolean := true;
  v_trgm_targets text[] := array[
    'official_foods.normalized_name',
    'official_foods.reading',
    'official_food_aliases.normalized',
    'official_food_aliases.reading'
  ];

  -- Brand-new objects created by the feature migration. A name that already
  -- existed in the snapshot is still compared; this list cannot hide that.
  v_exclude_tables text[] := array['official_foods', 'official_food_aliases'];
  v_exclude_routines text[] := array[
    'normalize_food_search_text',
    'search_official_foods',
    'enforce_mext_saved_food_attribution',
    'enforce_mext_food_entry_code'
  ];
  v_exclude_new_views text[] := array[]::text[];
  -- saved_foods: source_type check gains mext_sfct, then provenance and
  -- attribution columns. food_entries: meal-row provenance and mext_sfct.
  -- Row counts of both tables must still match the snapshot. Do not move
  -- either name into v_exclude_tables.
  v_ignore_signature_for text[] := array['saved_foods', 'food_entries'];
  v_count_match_required boolean := true;

  v_foods jsonb := jsonb_build_array(
    -- 01088 こめ［水稲めし］精白米 うるち米
    jsonb_build_object('food_code', '01088', 'kcal', 156, 'name', U&'\3053\3081\3000\FF3B\6C34\7A32\3081\3057\FF3D\3000\7CBE\767D\7C73\3000\3046\308B\3061\7C73'),
    -- 01083 こめ［水稲穀粒］精白米 うるち米 (raw; must not be confused with 01088)
    jsonb_build_object('food_code', '01083', 'kcal', 342, 'name', U&'\3053\3081\3000\FF3B\6C34\7A32\7A40\7C92\FF3D\3000\7CBE\767D\7C73\3000\3046\308B\3061\7C73'),
    -- 12004 鶏卵 全卵 生
    jsonb_build_object('food_code', '12004', 'kcal', 142, 'name', U&'\9D8F\5375\3000\5168\5375\3000\751F'),
    -- 01048 中華めん ゆで
    jsonb_build_object('food_code', '01048', 'kcal', 133, 'name', U&'\3053\3080\304E\3000\FF3B\4E2D\83EF\3081\3093\985E\FF3D\3000\4E2D\83EF\3081\3093\3000\3086\3067'),
    -- 11220 若どり むね 皮なし 生
    jsonb_build_object('food_code', '11220', 'kcal', 105, 'name', U&'\FF1C\9CE5\8089\985E\FF1E\3000\306B\308F\3068\308A\3000\FF3B\82E5\3069\308A\30FB\4E3B\54C1\76EE\FF3D\3000\3080\306D\3000\76AE\306A\3057\3000\751F'),
    -- 04032 木綿豆腐
    jsonb_build_object('food_code', '04032', 'kcal', 73, 'name', U&'\3060\3044\305A\3000\FF3B\8C46\8150\30FB\6CB9\63DA\3052\985E\FF3D\3000\6728\7DBF\8C46\8150'),
    -- 13003 普通牛乳
    jsonb_build_object('food_code', '13003', 'kcal', 61, 'name', U&'\FF1C\725B\4E73\53CA\3073\4E73\88FD\54C1\FF1E\3000\FF08\6DB2\72B6\4E73\985E\FF09\3000\666E\901A\725B\4E73'),
    -- 18031 牛飯の具
    jsonb_build_object('food_code', '18031', 'kcal', 122, 'name', U&'\548C\98A8\6599\7406\3000\716E\7269\985E\3000\725B\98EF\306E\5177'),
    -- 11183 ばらベーコン, trailing U+3000 preserved, errata kcal 241
    jsonb_build_object('food_code', '11183', 'kcal', 241, 'name', U&'\FF1C\755C\8089\985E\FF1E\3000\3076\305F\3000\FF3B\30D9\30FC\30B3\30F3\985E\FF3D\3000\3070\3089\30D9\30FC\30B3\30F3\3000\3070\3089\30D9\30FC\30B3\30F3\3000')
  );

  v_norm_cases jsonb := jsonb_build_array(
    jsonb_build_array('ゴハン', 'ごはん'),
    jsonb_build_array(U&'\FF7A\FF9E\FF8A\FF9D', 'ごはん'),
    jsonb_build_array('ご飯', 'ご飯'),
    jsonb_build_array('白米', '白米'),
    jsonb_build_array('ライス', 'らいす'),
    jsonb_build_array('ラーメン', 'らめん'),
    jsonb_build_array(U&'\FF97\FF70\FF92\FF9D', 'らめん'),
    jsonb_build_array(U&'\3054\3000\98EF', 'ご飯'),
    jsonb_build_array(U&'\FF32\FF29\FF23\FF25', 'rice')
  );

  v_step text := 'start';
  v_me text := current_user;
  v_half text := U&'\FF7A\FF9E\FF8A\FF9D';
  v_queries text[];
  v_ident text;
  v_target text;
  v_tbl text;
  v_col text;
  v_food jsonb;
  v_pair jsonb;
  v_code text;
  v_expect_name text;
  v_name text;
  v_kcal numeric;
  v_base numeric;
  v_unit text;
  v_row_source text;
  v_row_edition text;
  v_n bigint;
  v_distinct bigint;
  v_total bigint;
  v_input text;
  v_expect text;
  v_got text;
  v_hits bigint;
  v_query text;
  v_dir text;
  v_sql text;
  v_codes jsonb;
  v_trgm_schema text;
  v_has boolean;
  v_norm_oid oid;
  v_search_oid oid;
  v_secdef boolean;
  v_volatile text;
  v_proconfig text[];
  v_table text;
  v_rls boolean;
  v_owner text;
  v_priv text;
  v_role text;
  v_anon_oid oid;
  v_auth_oid oid;
  v_pol record;
  v_public boolean;
  v_hit_anon boolean;
  v_hit_auth boolean;
  v_auth_select boolean;
  v_label text;
  v_stmt text;
  v_stage text;
  v_canary bigint;
  v_seen bigint;
  v_fp_sql text;
  v_src text;
  v_uid uuid;
  v_copier uuid;
  v_other uuid;
  v_probe_name text;
  v_got_attr text;
  v_got_code text;
  v_got_orig text;
  v_got_source text;
  v_current jsonb;
  v_key text;
  v_rname text;
  v_owner_table text;
  v_deltas jsonb := '[]'::jsonb;
  v_seq_deltas jsonb := '[]'::jsonb;
  v_sig_fails jsonb := '[]'::jsonb;
  v_ignored jsonb := '[]'::jsonb;
  v_search_first jsonb := '{}'::jsonb;
  v_detail jsonb;
  v_base_obj jsonb;
  v_cur_obj jsonb;
begin
  v_step := 'config';
  if v_baseline is null or jsonb_typeof(v_baseline) <> 'object' then
    raise exception 'ACCEPTANCE FAIL: v_baseline is empty. Run snapshot_user_tables.sql first and paste its jsonb into the CONFIG block.';
  end if;
  if v_baseline->>'kind' is distinct from 'official_foods_user_table_snapshot' then
    raise exception 'ACCEPTANCE FAIL: v_baseline is not a snapshot_user_tables.sql result';
  end if;
  if v_baseline->>'database' is distinct from current_database() then
    raise exception 'ACCEPTANCE FAIL: snapshot database % does not match %', v_baseline->>'database', current_database();
  end if;
  if v_search_limit is null or v_search_limit < 1 or v_search_limit > v_search_limit_cap then
    raise exception 'ACCEPTANCE FAIL: v_search_limit must be between 1 and % (product default). Do not raise the cap to drag 牛丼 into the window.', v_search_limit_cap;
  end if;
  if char_length(v_half) <> 4
     or ascii(substring(v_half from 1 for 1)) <> 65402
     or ascii(substring(v_half from 2 for 1)) <> 65438
     or ascii(substring(v_half from 3 for 1)) <> 65418
     or ascii(substring(v_half from 4 for 1)) <> 65437 then
    raise exception 'ACCEPTANCE FAIL: halfwidth ゴハン literal in this file is corrupted (expected U+FF7A U+FF9E U+FF8A U+FF9D)';
  end if;
  v_queries := array['ご飯', 'ゴハン', v_half, '白米', 'ライス'];

  if v_require_search_input_cap
     and (v_search_input_cap is null or v_search_input_cap < 1 or v_search_input_cap > 64) then
    raise exception 'ACCEPTANCE FAIL: v_search_input_cap must be between 1 and 64';
  end if;
  foreach v_ident in array array[
    v_schema, v_foods_table, v_aliases_table, v_food_code_col, v_name_col,
    v_kcal_col, v_source_col, v_edition_col, v_norm_fn, v_search_fn,
    v_out_food_code, v_anon_role, v_auth_role, v_meal_table, v_my_foods_table,
    v_prov_code_col, v_prov_name_col, v_prov_source_col, v_attr_col
  ] loop
    if v_ident is null or v_ident !~ '^[a-z_][a-z0-9_]*$' then
      raise exception 'ACCEPTANCE FAIL: [%] is not a simple lowercase identifier', v_ident;
    end if;
  end loop;
  if v_check_base_amount then
    if v_base_amount_col !~ '^[a-z_][a-z0-9_]*$' or v_unit_type_col !~ '^[a-z_][a-z0-9_]*$' then
      raise exception 'ACCEPTANCE FAIL: base amount / unit column name is not a simple identifier';
    end if;
  end if;
  if v_rank_column is not null and v_rank_column !~ '^[a-z_][a-z0-9_]*$' then
    raise exception 'ACCEPTANCE FAIL: v_rank_column is not a simple identifier';
  end if;
  foreach v_target in array v_trgm_targets loop
    if v_target !~ '^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$' then
      raise exception 'ACCEPTANCE FAIL: trgm target [%] must be table.column', v_target;
    end if;
  end loop;
  if v_me in (v_anon_role, v_auth_role) then
    raise exception 'ACCEPTANCE FAIL: run as the migration owner via execute_sql, not as %', v_me;
  end if;

  v_step := 'objects';
  if to_regclass(format('%I.%I', v_schema, v_foods_table)) is null
     or to_regclass(format('%I.%I', v_schema, v_aliases_table)) is null then
    raise exception 'ACCEPTANCE FAIL: missing %.% or %.%. Apply the feature migration, or fix the CONFIG names.',
      v_schema, v_foods_table, v_schema, v_aliases_table;
  end if;

  v_step := 'extension';
  if v_require_trgm then
    select n.nspname into v_trgm_schema
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pg_trgm';
    if v_trgm_schema is null then
      raise exception 'ACCEPTANCE FAIL: extension pg_trgm is not installed';
    end if;
    foreach v_target in array v_trgm_targets loop
      v_tbl := split_part(v_target, '.', 1);
      v_col := split_part(v_target, '.', 2);
      select exists (
        select 1
        from pg_index i
        join pg_class t on t.oid = i.indrelid
        join pg_namespace ns on ns.oid = t.relnamespace
        join pg_class ix on ix.oid = i.indexrelid
        join pg_am am on am.oid = ix.relam
        join pg_attribute a
          on a.attrelid = t.oid
         and a.attname = v_col
         and a.attnum = any (i.indkey)
        where ns.nspname = v_schema
          and t.relname = v_tbl
          and am.amname = 'gin'
          and pg_get_indexdef(i.indexrelid) ilike '%gin_trgm_ops%'
      ) into v_has;
      if not v_has then
        raise exception 'ACCEPTANCE FAIL: no gin_trgm_ops index on %.%', v_tbl, v_col;
      end if;
    end loop;
  end if;

  v_step := 'functions';
  begin
    select p.oid, p.prosecdef, p.provolatile::text, p.proconfig
      into strict v_norm_oid, v_secdef, v_volatile, v_proconfig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = v_schema and p.proname = v_norm_fn;
  exception
    when no_data_found then
      raise exception 'ACCEPTANCE FAIL: function %.% is missing. Fix v_norm_fn if the feature PR renamed it.', v_schema, v_norm_fn;
    when too_many_rows then
      raise exception 'ACCEPTANCE FAIL: more than one %.% ; disambiguate in CONFIG', v_schema, v_norm_fn;
  end;
  if v_volatile is distinct from 'i' then
    raise exception 'ACCEPTANCE FAIL: %.% must be immutable', v_schema, v_norm_fn;
  end if;
  if v_proconfig is null or not exists (
    select 1 from unnest(v_proconfig) c where c like 'search_path=%'
  ) then
    raise exception 'ACCEPTANCE FAIL: %.% must set search_path (empty search_path, per the brief)', v_schema, v_norm_fn;
  end if;

  begin
    select p.oid, p.prosecdef, p.provolatile::text
      into strict v_search_oid, v_secdef, v_volatile
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = v_schema and p.proname = v_search_fn;
  exception
    when no_data_found then
      raise exception 'ACCEPTANCE FAIL: function %.% is missing. Fix v_search_fn if the feature PR renamed it.', v_schema, v_search_fn;
    when too_many_rows then
      raise exception 'ACCEPTANCE FAIL: more than one %.%', v_schema, v_search_fn;
  end;
  if not v_secdef then
    raise exception 'ACCEPTANCE FAIL: %.% must be security definer so authenticated search can call the normalizer', v_schema, v_search_fn;
  end if;
  select p.proconfig into v_proconfig
  from pg_proc p
  where p.oid = v_search_oid;
  if v_proconfig is null or not exists (
    select 1 from unnest(v_proconfig) c where c like 'search_path=%'
  ) then
    raise exception 'ACCEPTANCE FAIL: %.% must set search_path', v_schema, v_search_fn;
  end if;
  if v_volatile is distinct from 's' then
    raise exception 'ACCEPTANCE FAIL: %.% must be stable', v_schema, v_search_fn;
  end if;
  if has_function_privilege(v_anon_role, v_search_oid, 'execute') then
    raise exception 'ACCEPTANCE FAIL: % can execute %', v_anon_role, v_search_fn;
  end if;
  if not has_function_privilege(v_auth_role, v_search_oid, 'execute') then
    raise exception 'ACCEPTANCE FAIL: % cannot execute %', v_auth_role, v_search_fn;
  end if;
  if has_function_privilege(v_anon_role, v_norm_oid, 'execute')
     or has_function_privilege(v_auth_role, v_norm_oid, 'execute') then
    raise exception 'ACCEPTANCE FAIL: anon or authenticated can execute %', v_norm_fn;
  end if;
  select p.prosrc into v_src from pg_proc p where p.oid = v_norm_oid;
  if position(v_norm_input_cap::text in v_src) = 0 then
    raise exception 'ACCEPTANCE FAIL: %.% does not cap input at % characters',
      v_schema, v_norm_fn, v_norm_input_cap;
  end if;
  foreach v_role in array array[v_anon_role, v_auth_role] loop
    begin
      execute format('set local role %I', v_role);
      execute format('select %I.%I($1)', v_schema, v_norm_fn) using 'あ';
      raise exception 'ACCEPTANCE FAIL: % executed %', v_role, v_norm_fn;
    exception
      when insufficient_privilege then
        null;
    end;
  end loop;

  -- Direct EXECUTE on the composition-table triggers is revoked. Row
  -- writes still fire them as the table owner. A trigger-only error
  -- means the role could still execute the function, so it fails the check.
  foreach v_ident in array array[
    'enforce_mext_saved_food_attribution',
    'enforce_mext_food_entry_code'
  ] loop
    if has_function_privilege(v_anon_role, format('%I.%I()', v_schema, v_ident)::regprocedure, 'execute')
       or has_function_privilege(v_auth_role, format('%I.%I()', v_schema, v_ident)::regprocedure, 'execute') then
      raise exception 'ACCEPTANCE FAIL: anon or authenticated can execute %', v_ident;
    end if;
    foreach v_role in array array[v_anon_role, v_auth_role] loop
      begin
        execute format('set local role %I', v_role);
        execute format('select %I.%I()', v_schema, v_ident);
        raise exception 'ACCEPTANCE FAIL: % executed %', v_role, v_ident;
      exception
        when insufficient_privilege then
          null;
      end;
    end loop;
  end loop;

  v_step := 'counts';
  execute format(
    'select count(*)::bigint, count(distinct %I)::bigint from %I.%I where %I = $1 and %I = $2',
    v_food_code_col, v_schema, v_foods_table, v_source_col, v_edition_col
  ) into v_n, v_distinct using v_source, v_edition;
  if v_n is distinct from v_expected_count or v_distinct is distinct from v_expected_count then
    raise exception 'ACCEPTANCE FAIL: edition % / source % has % rows (% distinct codes); expected %',
      v_edition, v_source, v_n, v_distinct, v_expected_count;
  end if;
  execute format('select count(*)::bigint from %I.%I', v_schema, v_foods_table) into v_total;
  if v_total is distinct from v_expected_total then
    raise exception 'ACCEPTANCE FAIL: % has % rows in total; expected %', v_foods_table, v_total, v_expected_total;
  end if;

  v_step := 'spot-check';
  for v_food in select value from jsonb_array_elements(v_foods) loop
    v_code := v_food->>'food_code';
    v_expect_name := v_food->>'name';
    if v_code = '11183' and ascii(right(v_expect_name, 1)) <> 12288 then
      raise exception 'ACCEPTANCE FAIL: the 11183 name literal in this file lost its trailing U+3000';
    end if;
    if v_code = '01088' and (position('水稲めし' in v_expect_name) = 0 or position('精白米' in v_expect_name) = 0) then
      raise exception 'ACCEPTANCE FAIL: the 01088 name literal in this file is corrupted';
    end if;
    if v_check_base_amount then
      execute format(
        'select %I, %I::numeric, %I, %I, %I::numeric, %I from %I.%I where %I = $1',
        v_name_col, v_kcal_col, v_source_col, v_edition_col, v_base_amount_col, v_unit_type_col,
        v_schema, v_foods_table, v_food_code_col
      ) into v_name, v_kcal, v_row_source, v_row_edition, v_base, v_unit using v_code;
    else
      execute format(
        'select %I, %I::numeric, %I, %I from %I.%I where %I = $1',
        v_name_col, v_kcal_col, v_source_col, v_edition_col,
        v_schema, v_foods_table, v_food_code_col
      ) into v_name, v_kcal, v_row_source, v_row_edition using v_code;
    end if;
    if not found then
      raise exception 'ACCEPTANCE FAIL: food % is missing', v_code;
    end if;
    if v_name is distinct from v_expect_name then
      raise exception 'ACCEPTANCE FAIL: % name is [%] expected [%]', v_code, v_name, v_expect_name;
    end if;
    if v_kcal is distinct from (v_food->>'kcal')::numeric then
      raise exception 'ACCEPTANCE FAIL: % kcal per 100g is % expected %', v_code, v_kcal, v_food->>'kcal';
    end if;
    if v_row_source is distinct from v_source or v_row_edition is distinct from v_edition then
      raise exception 'ACCEPTANCE FAIL: % source/edition is % / %', v_code, v_row_source, v_row_edition;
    end if;
    if v_check_base_amount and (v_base is distinct from v_expected_base_amount or v_unit is distinct from v_expected_unit) then
      raise exception 'ACCEPTANCE FAIL: % base is % %; expected % %', v_code, v_base, v_unit, v_expected_base_amount, v_expected_unit;
    end if;
  end loop;

  v_step := 'normalizer';
  for v_pair in select value from jsonb_array_elements(v_norm_cases) loop
    v_input := v_pair->>0;
    v_expect := v_pair->>1;
    execute format('select %I.%I($1)', v_schema, v_norm_fn) into v_got using v_input;
    if v_got is distinct from v_expect then
      raise exception 'ACCEPTANCE FAIL: normalize(%) = [%] expected [%]', v_input, v_got, v_expect;
    end if;
  end loop;

  v_step := 'rls';
  select oid into v_anon_oid from pg_roles where rolname = v_anon_role;
  select oid into v_auth_oid from pg_roles where rolname = v_auth_role;
  if v_anon_oid is null or v_auth_oid is null then
    raise exception 'ACCEPTANCE FAIL: role % or % is missing', v_anon_role, v_auth_role;
  end if;
  if exists (
    select 1 from pg_roles
    where rolname in (v_anon_role, v_auth_role)
      and (rolsuper or rolbypassrls)
  ) then
    raise exception 'ACCEPTANCE FAIL: anon or authenticated is superuser or bypasses RLS';
  end if;

  foreach v_table in array array[v_foods_table, v_aliases_table] loop
    select c.relrowsecurity, pg_get_userbyid(c.relowner)
      into v_rls, v_owner
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = v_schema and c.relname = v_table;
    if not v_rls then
      raise exception 'ACCEPTANCE FAIL: %.% does not have row level security enabled', v_schema, v_table;
    end if;
    if v_owner in (v_anon_role, v_auth_role) then
      raise exception 'ACCEPTANCE FAIL: %.% is owned by client role %', v_schema, v_table, v_owner;
    end if;

    foreach v_priv in array array['insert', 'update', 'delete', 'truncate'] loop
      if has_table_privilege(v_anon_role, format('%I.%I', v_schema, v_table), v_priv)
         or has_table_privilege(v_auth_role, format('%I.%I', v_schema, v_table), v_priv) then
        raise exception 'ACCEPTANCE FAIL: client role still has % on %.%', v_priv, v_schema, v_table;
      end if;
    end loop;
    if has_table_privilege(v_anon_role, format('%I.%I', v_schema, v_table), 'select')
       is distinct from v_anon_may_select then
      raise exception 'ACCEPTANCE FAIL: anon SELECT on %.% does not match v_anon_may_select=%',
        v_schema, v_table, v_anon_may_select;
    end if;
    if has_table_privilege(v_auth_role, format('%I.%I', v_schema, v_table), 'select')
       is distinct from v_auth_may_select then
      raise exception 'ACCEPTANCE FAIL: authenticated SELECT on %.% does not match v_auth_may_select=%',
        v_schema, v_table, v_auth_may_select;
    end if;

    v_auth_select := false;
    for v_pol in
      select pol.polname, pol.polcmd::text as polcmd, pol.polpermissive, pol.polroles
      from pg_policy pol
      join pg_class c on c.oid = pol.polrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = v_schema and c.relname = v_table
    loop
      v_public := coalesce(cardinality(v_pol.polroles), 0) = 0;
      v_hit_anon := v_public or v_anon_oid = any (v_pol.polroles);
      v_hit_auth := v_public or v_auth_oid = any (v_pol.polroles);
      if v_pol.polpermissive and v_pol.polcmd in ('a', 'w', 'd', '*') and (v_hit_anon or v_hit_auth) then
        raise exception 'ACCEPTANCE FAIL: %.% has permissive write policy %', v_schema, v_table, v_pol.polname;
      end if;
      if v_pol.polpermissive and v_pol.polcmd in ('r', '*') and v_hit_anon and not v_anon_may_select then
        raise exception 'ACCEPTANCE FAIL: %.% select policy % applies to anon', v_schema, v_table, v_pol.polname;
      end if;
      if v_pol.polpermissive and v_pol.polcmd in ('r', '*') and v_hit_auth then
        v_auth_select := true;
      end if;
    end loop;
    if v_auth_may_select and not v_auth_select then
      raise exception 'ACCEPTANCE FAIL: %.% has no permissive SELECT policy for %', v_schema, v_table, v_auth_role;
    end if;
  end loop;

  v_step := 'search';
  v_dir := case when v_rank_ascending then 'asc' else 'desc' end;
  if v_dir not in ('asc', 'desc') then
    raise exception 'ACCEPTANCE FAIL: bad rank direction';
  end if;
  foreach v_query in array v_queries loop
    v_got := null;
    v_hits := null;
    begin
      begin
        execute format('set local role %I', v_auth_role);
        if current_user is distinct from v_auth_role then
          raise exception 'ACCEPTANCE FAIL: set role % did not take effect', v_auth_role;
        end if;
        if v_rank_column is null then
          execute format(
            'select t.%I::text from %I.%I($1, $2) as t limit 1',
            v_out_food_code, v_schema, v_search_fn
          ) into v_got using v_query, v_search_limit;
        else
          execute format(
            'select t.%I::text from %I.%I($1, $2) as t order by t.%I %s limit 1',
            v_out_food_code, v_schema, v_search_fn, v_rank_column, v_dir
          ) into v_got using v_query, v_search_limit;
        end if;
        execute format(
          'select count(*)::bigint from %I.%I($1, $2) as t where t.%I::text = $3',
          v_schema, v_search_fn, v_out_food_code
        ) into v_hits using v_query, v_search_limit, v_expect_first;
        raise exception using errcode = 'P0001', message = 'ACCEPTANCE_PROBE_DONE';
      exception
        when sqlstate 'P0001' then
          if sqlerrm is distinct from 'ACCEPTANCE_PROBE_DONE' then
            raise;
          end if;
      end;
    exception when others then
      raise exception 'ACCEPTANCE FAIL: search [%] as % failed: % %', v_query, v_auth_role, sqlstate, sqlerrm;
    end;
    if v_got is distinct from v_expect_first then
      raise exception 'ACCEPTANCE FAIL: search [%] first code is [%]; expected %', v_query, v_got, v_expect_first;
    end if;
    if v_hits is distinct from 1 then
      raise exception 'ACCEPTANCE FAIL: search [%] returned % rows for %; expected exactly one', v_query, v_hits, v_expect_first;
    end if;
    v_search_first := v_search_first || jsonb_build_object(v_query, v_got);
  end loop;

  v_codes := '[]'::jsonb;
  begin
    begin
      execute format('set local role %I', v_auth_role);
      execute format(
        'select coalesce(jsonb_agg(distinct t.%I::text), ''[]''::jsonb) from %I.%I($1, $2) as t',
        v_out_food_code, v_schema, v_search_fn
      ) into v_codes using v_gyudon_query, v_search_limit;
      raise exception using errcode = 'P0001', message = 'ACCEPTANCE_PROBE_DONE';
    exception
      when sqlstate 'P0001' then
        if sqlerrm is distinct from 'ACCEPTANCE_PROBE_DONE' then
          raise;
        end if;
    end;
  exception when others then
    raise exception 'ACCEPTANCE FAIL: search [%] as % failed: % %', v_gyudon_query, v_auth_role, sqlstate, sqlerrm;
  end;
  if jsonb_array_length(v_codes) < 2 then
    raise exception 'ACCEPTANCE FAIL: search [%] returned % candidates; expected multiple', v_gyudon_query, v_codes;
  end if;
  foreach v_code in array v_gyudon_codes loop
    if not (v_codes @> jsonb_build_array(v_code)) then
      raise exception 'ACCEPTANCE FAIL: search [%] did not return % (got %)', v_gyudon_query, v_code, v_codes;
    end if;
  end loop;

  if not v_anon_may_select then
    v_stage := 'set_role';
    begin
      execute format('set local role %I', v_anon_role);
      v_stage := 'call';
      execute format(
        'select t.%I::text from %I.%I($1, $2) as t limit 1',
        v_out_food_code, v_schema, v_search_fn
      ) into v_got using 'ご飯', v_search_limit;
      v_stage := 'succeeded';
      raise exception 'ACCEPTANCE FAIL: anon search succeeded (%)', v_got;
    exception
      when insufficient_privilege then
        if v_stage = 'set_role' then
          raise exception 'ACCEPTANCE FAIL: cannot set role % (%)', v_anon_role, sqlerrm;
        end if;
      when others then
        if v_stage = 'succeeded' or position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
          raise;
        end if;
        raise exception 'ACCEPTANCE FAIL: anon search failed with % % (expected 42501)', sqlstate, sqlerrm;
    end;
  end if;

  v_step := 'authenticated-select';
  v_seen := null;
  begin
    begin
      execute format('set local role %I', v_auth_role);
      execute format('select count(*)::bigint from %I.%I', v_schema, v_foods_table) into v_seen;
      raise exception using errcode = 'P0001', message = 'ACCEPTANCE_PROBE_DONE';
    exception
      when sqlstate 'P0001' then
        if sqlerrm is distinct from 'ACCEPTANCE_PROBE_DONE' then
          raise;
        end if;
    end;
  exception when others then
    raise exception 'ACCEPTANCE FAIL: authenticated select failed: % %', sqlstate, sqlerrm;
  end;
  if v_seen is distinct from v_expected_count then
    raise exception 'ACCEPTANCE FAIL: authenticated select sees % rows; expected %', v_seen, v_expected_count;
  end if;

  v_step := 'dml-probe';
  if v_live_dml_probe then
    foreach v_role in array array[v_anon_role, v_auth_role] loop
      foreach v_table in array array[v_foods_table, v_aliases_table] loop
        foreach v_label in array array['insert', 'update', 'delete', 'truncate'] loop
          if v_label = 'insert' then
            v_stmt := format('insert into %I.%I (%I) values (%L)', v_schema, v_table, v_food_code_col, '00000');
          elsif v_label = 'update' then
            v_stmt := format('update %I.%I set %I = %I where %I = %L', v_schema, v_table, v_food_code_col, v_food_code_col, v_food_code_col, '01088');
          elsif v_label = 'delete' then
            v_stmt := format('delete from %I.%I where %I = %L', v_schema, v_table, v_food_code_col, '01088');
          else
            v_stmt := format('truncate table %I.%I', v_schema, v_table);
          end if;
          v_stage := 'set_role';
          begin
            execute format('set local role %I', v_role);
            v_stage := 'dml';
            if current_user is distinct from v_role then
              raise exception 'ACCEPTANCE FAIL: set role % did not take effect (now %)', v_role, current_user;
            end if;
            execute v_stmt;
            v_stage := 'succeeded';
            raise exception 'ACCEPTANCE FAIL: % % on %.% was not denied', v_role, v_label, v_schema, v_table;
          exception
            when insufficient_privilege then
              if v_stage = 'set_role' then
                raise exception 'ACCEPTANCE FAIL: cannot set role % (%). Run via the migration owner.', v_role, sqlerrm;
              end if;
            when others then
              if v_stage = 'succeeded' or position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
                raise;
              end if;
              raise exception 'ACCEPTANCE FAIL: % % on %.% ended with % % (expected 42501)',
                v_role, v_label, v_schema, v_table, sqlstate, sqlerrm;
          end;
        end loop;
      end loop;
    end loop;
  end if;

  if current_user is distinct from v_me then
    raise exception 'ACCEPTANCE FAIL: role did not return to % (now %)', v_me, current_user;
  end if;

  v_step := 'canary';
  foreach v_table in array array[v_foods_table, v_aliases_table] loop
    execute format(
      'select count(*)::bigint from %I.%I where %I = %L',
      v_schema, v_table, v_food_code_col, '00000'
    ) into v_canary;
    if v_canary <> 0 then
      raise exception 'ACCEPTANCE FAIL: probe row food_code 00000 remains in %.%', v_schema, v_table;
    end if;
  end loop;
  execute format(
    'select count(*)::bigint from %I.%I where %I = $1 and %I = $2',
    v_schema, v_foods_table, v_source_col, v_edition_col
  ) into v_n using v_source, v_edition;
  if v_n is distinct from v_expected_count then
    raise exception 'ACCEPTANCE FAIL: row count changed during probes (%); the script must not commit writes', v_n;
  end if;

  v_step := 'search-input-cap';
  if v_require_search_input_cap then
    select coalesce(string_agg(p.prosrc, E'\n'), '')
      into v_src
    from pg_proc p
    where p.oid in (v_norm_oid, v_search_oid);
    if position(v_search_input_cap::text in v_src) = 0 then
      raise exception 'ACCEPTANCE FAIL: search input cap: %.% and %.% do not enforce a % character limit',
        v_schema, v_norm_fn, v_schema, v_search_fn, v_search_input_cap;
    end if;
    begin
      begin
        execute 'set local statement_timeout = ''8s''';
        execute format('set local role %I', v_auth_role);
        execute format(
          'select count(*)::bigint from %I.%I($1, $2)',
          v_schema, v_search_fn
        ) into v_seen using repeat('あ', 100000), v_search_limit;
        raise exception using errcode = 'P0001', message = 'ACCEPTANCE_PROBE_DONE';
      exception
        when sqlstate 'P0001' then
          if sqlerrm is distinct from 'ACCEPTANCE_PROBE_DONE' then
            raise;
          end if;
        when query_canceled then
          raise exception 'ACCEPTANCE FAIL: search input cap: 100000-character query did not finish within 8s';
      end;
    exception when others then
      if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
        raise;
      end if;
      if position(v_search_input_cap::text in sqlerrm) = 0
         and position('too long' in lower(sqlerrm)) = 0
         and position('exceed' in lower(sqlerrm)) = 0 then
        raise exception 'ACCEPTANCE FAIL: search input cap probe failed: % %', sqlstate, sqlerrm;
      end if;
    end;
  end if;

  v_step := 'published-attribution';
  if v_require_published_attribution then
    foreach v_table in array array[v_meal_table, v_my_foods_table] loop
      foreach v_col in array array[v_prov_code_col, v_prov_name_col] loop
        perform 1
        from information_schema.columns
        where table_schema = v_schema
          and table_name = v_table
          and column_name = v_col;
        if not found then
          raise exception 'ACCEPTANCE FAIL: %.% is missing provenance column % (official_food_code / official_food_name). Align CONFIG if the feature PR used another name.',
            v_schema, v_table, v_col;
        end if;
      end loop;
      select exists (
        select 1
        from pg_constraint con
        join pg_class rel on rel.oid = con.conrelid
        join pg_namespace nsp on nsp.oid = rel.relnamespace
        where nsp.nspname = v_schema
          and rel.relname = v_table
          and con.contype = 'c'
          and pg_get_constraintdef(con.oid) ilike '%source_type%'
          and pg_get_constraintdef(con.oid) ilike '%mext_sfct%'
      ) into v_has;
      if not v_has then
        raise exception 'ACCEPTANCE FAIL: %.% source_type check does not allow mext_sfct',
          v_schema, v_table;
      end if;
    end loop;
    perform 1
    from information_schema.columns
    where table_schema = v_schema
      and table_name = v_my_foods_table
      and column_name = v_attr_col;
    if not found then
      raise exception 'ACCEPTANCE FAIL: %.% is missing % for the non-removable published attribution',
        v_schema, v_my_foods_table, v_attr_col;
    end if;

    select coalesce(string_agg(p.prosrc, E'\n'), '')
      into v_src
    from pg_trigger tg
    join pg_proc p on p.oid = tg.tgfoid
    join pg_class c on c.oid = tg.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = v_schema
      and c.relname = v_my_foods_table
      and not tg.tgisinternal;
    if position(v_published_attribution in v_src) = 0
       or position('mext_sfct' in v_src) = 0
       or position('publishing a food with an official food code requires the composition-table attribution' in v_src) = 0
       or position('copied_from_owner_user_id is required' in v_src) = 0
       or position('copied_from must reference your own saved food or a public saved food' in v_src) = 0 then
      raise exception 'ACCEPTANCE FAIL: no % trigger locks a published mext_sfct food to the attribution sentence, or it no longer rejects an unattributed official food code',
        v_my_foods_table;
    end if;
    select exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = v_schema
        and p.proname = 'enforce_mext_saved_food_attribution'
        and p.prosecdef
    ) into v_has;
    if v_has then
      raise exception 'ACCEPTANCE FAIL: enforce_mext_saved_food_attribution is security definer, so the lock would see the owner and never apply';
    end if;

    -- Hosted Supabase auth.users has required columns this probe does not
    -- fill. The trigger text check above still applies there. The live
    -- probe runs when id is the only required column (local Postgres / CI).
    select count(*)::bigint into v_n
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'auth'
      and c.relname = 'users'
      and a.attnum > 0
      and not a.attisdropped
      and a.attnotnull
      and not a.atthasdef
      and a.attname <> 'id';
    if v_n = 0 then
    v_uid := '00000000-0000-4000-8000-000000000088';
    v_copier := '00000000-0000-4000-8000-000000000089';
    v_other := '00000000-0000-4000-8000-000000000090';
    v_probe_name := 'acceptance-original-name';
    begin
      begin
        insert into auth.users (id) values (v_uid), (v_copier), (v_other);
        insert into public.users (id) values (v_uid), (v_copier), (v_other);
        begin
          execute format(
            'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, %I, %I, %I) values ($1, $2, ''private'', ''active'', $3, $3, 100, ''g'', 156, $4, $5, $6, null)',
            v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col
          ) using v_uid, 'of-accept-probe', 'probe rice', v_source, '01088', v_probe_name;
        exception
          when not_null_violation then
            execute format(
              'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, %I, %I, %I) values ($1, $2, ''private'', ''active'', $3, $3, 100, ''g'', 156, $4, $5, $6, $7)',
              v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col
            ) using v_uid, 'of-accept-probe', 'probe rice', v_source, '01088', v_probe_name, 'pending';
        end;
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I) values ($1, $2, ''private'', ''active'', $3, $3, 240, ''g'', 10, ''manual'')',
          v_schema, v_my_foods_table, v_prov_source_col
        ) using v_other, 'of-accept-secret', 'probe secret';
        perform set_config('request.jwt.claim.sub', v_uid::text, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        perform set_config('ayg.allow_mext_source_change', 'on', true);
        execute format('set local role %I', v_auth_role);

        execute format(
          'update %I.%I set %I = $3, %I = null, %I = $4, %I = ''manual'' where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table, v_attr_col, v_prov_code_col, v_prov_name_col, v_prov_source_col
        ) using v_uid, 'of-accept-probe', 'removed', 'renamed';
        if not found then
          raise exception 'ACCEPTANCE FAIL: authenticated update did not see the mext food';
        end if;
        execute format(
          'select %I, %I, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_code_col, v_prov_name_col, v_prov_source_col,
          v_schema, v_my_foods_table
        ) into v_got_attr, v_got_code, v_got_orig, v_got_source
        using v_uid, 'of-accept-probe';
        if v_got_attr is distinct from v_published_attribution
           or v_got_code is distinct from '01088'
           or v_got_orig is distinct from v_probe_name
           or v_got_source is distinct from v_source then
          raise exception 'ACCEPTANCE FAIL: authenticated bypassed the attribution lock after set_config (now % / % / % / %)',
            v_got_attr, v_got_code, v_got_orig, v_got_source;
        end if;

        perform public.publish_saved_food('of-accept-probe');
        execute format(
          'select %I, %I, %I, %I, visibility from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_code_col, v_prov_name_col, v_prov_source_col,
          v_schema, v_my_foods_table
        ) into v_got_attr, v_got_code, v_got_orig, v_got_source, v_unit
        using v_uid, 'of-accept-probe';
        if v_got_attr is distinct from v_published_attribution
           or v_got_code is distinct from '01088'
           or v_got_orig is distinct from v_probe_name
           or v_got_source is distinct from v_source
           or v_unit is distinct from 'public' then
          raise exception 'ACCEPTANCE FAIL: publishing a mext_sfct food did not keep attribution [%], food code [%], official food name [%], source [%], visibility [%]',
            v_got_attr, v_got_code, v_got_orig, v_got_source, v_unit;
        end if;

        execute 'reset role';
        -- The source is public. postgres may relabel, so this copy stays
        -- unattributed. A private source would be rejected: copied_from may
        -- name only the writer's own row or a public row. authenticated
        -- publish of the copy must still fail.
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 150, ''g'', 156, ''copied'', $4, $5)',
          v_schema, v_my_foods_table, v_prov_source_col
        ) using v_copier, 'of-accept-bridge', 'probe bridge', 'of-accept-probe', v_uid;
        execute format(
          'select %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_prov_source_col, v_attr_col, v_schema, v_my_foods_table
        ) into v_got_source, v_got_attr
        using v_copier, 'of-accept-bridge';
        if v_got_source is distinct from 'copied' or v_got_attr is not null then
          raise exception 'ACCEPTANCE FAIL: owner fixture for an unattributed copy was rewritten before the client call (% / %)',
            v_got_source, v_got_attr;
        end if;

        perform set_config('request.jwt.claim.sub', v_copier::text, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        execute format('set local role %I', v_auth_role);
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id, %I, %I, %I) values ($1, $2, ''private'', ''active'', $3, $3, 180, ''g'', 156, ''copied'', $4, $5, null, null, null)',
          v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col
        ) using v_copier, 'of-accept-copy', 'probe copy', 'of-accept-probe', v_uid;
        execute format(
          'select %I, %I, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_code_col, v_prov_name_col, v_prov_source_col,
          v_schema, v_my_foods_table
        ) into v_got_attr, v_got_code, v_got_orig, v_got_source
        using v_copier, 'of-accept-copy';
        if v_got_attr is distinct from v_published_attribution
           or v_got_code is distinct from '01088'
           or v_got_orig is distinct from v_probe_name
           or v_got_source is distinct from v_source then
          raise exception 'ACCEPTANCE FAIL: direct copy of a public mext food dropped attribution [%], food code [%], official food name [%], source [%]',
            v_got_attr, v_got_code, v_got_orig, v_got_source;
        end if;

        begin
          perform public.publish_saved_food('of-accept-bridge');
          raise exception 'ACCEPTANCE FAIL: unattributed composition-table copy was published';
        exception
          when others then
            if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
              raise;
            end if;
            if position('attribution' in sqlerrm) = 0 then
              raise exception 'ACCEPTANCE FAIL: publish without attribution failed for another reason: % %', sqlstate, sqlerrm;
            end if;
        end;
        execute format(
          'select visibility from %I.%I where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) into v_unit
        using v_copier, 'of-accept-bridge';
        if v_unit is distinct from 'private' then
          raise exception 'ACCEPTANCE FAIL: failed publish left the unattributed copy %', v_unit;
        end if;

        perform public.publish_saved_food('of-accept-copy');
        execute format(
          'select visibility, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_source_col, v_schema, v_my_foods_table
        ) into v_unit, v_got_attr, v_got_source
        using v_copier, 'of-accept-copy';
        if v_unit is distinct from 'public'
           or v_got_attr is distinct from v_published_attribution
           or v_got_source is distinct from v_source then
          raise exception 'ACCEPTANCE FAIL: attributed copy did not stay public with the sentence (% / % / %)',
            v_unit, v_got_attr, v_got_source;
        end if;

        -- Spoofed copied_from: the target is a plain food this role can
        -- read, while this row carries an official food code and no
        -- attribution. Publishing must fail and the row must stay private.
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I) values ($1, $2, ''private'', ''active'', $3, $3, 200, ''g'', 10, ''manual'')',
          v_schema, v_my_foods_table, v_prov_source_col
        ) using v_copier, 'of-accept-plain', 'probe plain';
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id, %I, %I, %I) values ($1, $2, ''private'', ''active'', $3, $3, 210, ''g'', 156, ''copied'', $4, $5, $6, $7, null)',
          v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col
        ) using v_copier, 'of-accept-forged', 'probe forged', 'of-accept-plain', v_copier, '01088', v_probe_name;
        execute format(
          'select %I, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_prov_source_col, v_prov_code_col, v_attr_col, v_schema, v_my_foods_table
        ) into v_got_source, v_got_code, v_got_attr
        using v_copier, 'of-accept-forged';
        if v_got_source is distinct from 'copied'
           or v_got_code is distinct from '01088'
           or v_got_attr is not null then
          raise exception 'ACCEPTANCE FAIL: spoofed copied_from was rewritten before publish (% / % / %)',
            v_got_source, v_got_code, v_got_attr;
        end if;
        begin
          perform public.publish_saved_food('of-accept-forged');
          raise exception 'ACCEPTANCE FAIL: spoofed copied_from published an official food code without attribution';
        exception
          when others then
            if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
              raise;
            end if;
            if position('attribution' in sqlerrm) = 0 then
              raise exception 'ACCEPTANCE FAIL: spoofed publish failed for another reason: % %', sqlstate, sqlerrm;
            end if;
        end;
        execute format(
          'select visibility from %I.%I where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) into v_unit
        using v_copier, 'of-accept-forged';
        if v_unit is distinct from 'private' then
          raise exception 'ACCEPTANCE FAIL: failed spoofed publish left the food %', v_unit;
        end if;

        begin
          execute format(
            'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 220, ''g'', 10, ''copied'', $4, null)',
            v_schema, v_my_foods_table, v_prov_source_col
          ) using v_copier, 'of-accept-null-owner', 'probe null owner', 'of-accept-plain';
          raise exception 'ACCEPTANCE FAIL: copied_from accepted a null owner';
        exception
          when others then
            if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
              raise;
            end if;
            if position('copied_from_owner_user_id' in sqlerrm) = 0 then
              raise exception 'ACCEPTANCE FAIL: null owner failed for another reason: % %', sqlstate, sqlerrm;
            end if;
        end;
        execute format(
          'select count(*) from %I.%I where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) into v_n
        using v_copier, 'of-accept-null-owner';
        if v_n <> 0 then
          raise exception 'ACCEPTANCE FAIL: rejected null-owner insert left a row';
        end if;

        execute 'reset role';
        execute format(
          'update %I.%I set visibility = ''private'' where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) using v_uid, 'of-accept-probe';
        perform set_config('request.jwt.claim.sub', v_copier::text, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        execute format('set local role %I', v_auth_role);
        execute format(
          'update %I.%I set name = $3, normalized_name = $3 where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) using v_copier, 'of-accept-copy', 'probe copy edited';
        if not found then
          raise exception 'ACCEPTANCE FAIL: copy update after the source became private did not see the row';
        end if;
        execute format(
          'select name, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_source_col, v_schema, v_my_foods_table
        ) into v_got_orig, v_got_attr, v_got_source
        using v_copier, 'of-accept-copy';
        if v_got_orig is distinct from 'probe copy edited'
           or v_got_attr is distinct from v_published_attribution
           or v_got_source is distinct from v_source then
          raise exception 'ACCEPTANCE FAIL: copy could not be edited after the source became private (% / % / %)',
            v_got_orig, v_got_attr, v_got_source;
        end if;

        -- PostgREST saves with POST, Prefer: resolution=merge-duplicates,
        -- on_conflict=user_id,food_id. That is INSERT ... ON CONFLICT
        -- (user_id, food_id) DO UPDATE, so the insert trigger runs on an
        -- edit. The same copied_from must not be re-checked.
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, %I, %I, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 180, ''g'', 156, $4, $5, $6, $7, $8, $9) on conflict (user_id, food_id) do update set name = excluded.name, normalized_name = excluded.normalized_name, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, copied_from_food_id = excluded.copied_from_food_id, copied_from_owner_user_id = excluded.copied_from_owner_user_id',
          v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col,
          v_prov_source_col, v_prov_source_col, v_prov_code_col, v_prov_code_col, v_prov_name_col, v_prov_name_col, v_attr_col, v_attr_col
        ) using v_copier, 'of-accept-copy', 'probe copy upsert private', v_source, '01088', v_probe_name, v_published_attribution, 'of-accept-probe', v_uid;
        execute format(
          'select name, %I, %I, copied_from_food_id from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_source_col, v_schema, v_my_foods_table
        ) into v_got_orig, v_got_attr, v_got_source, v_got
        using v_copier, 'of-accept-copy';
        if v_got_orig is distinct from 'probe copy upsert private'
           or v_got_attr is distinct from v_published_attribution
           or v_got_source is distinct from v_source
           or v_got is distinct from 'of-accept-probe' then
          raise exception 'ACCEPTANCE FAIL: upsert could not edit a copy after the source became private (% / % / % / %)',
            v_got_orig, v_got_attr, v_got_source, v_got;
        end if;

        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, %I, %I, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 180, ''g'', 156, ''manual'', null, null, null, $4, $5) on conflict (user_id, food_id) do update set name = excluded.name, normalized_name = excluded.normalized_name, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, copied_from_food_id = excluded.copied_from_food_id, copied_from_owner_user_id = excluded.copied_from_owner_user_id',
          v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col,
          v_prov_source_col, v_prov_source_col, v_prov_code_col, v_prov_code_col, v_prov_name_col, v_prov_name_col, v_attr_col, v_attr_col
        ) using v_copier, 'of-accept-copy', 'probe copy upsert stripped', 'of-accept-probe', v_uid;
        execute format(
          'select name, %I, %I, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_code_col, v_prov_source_col, v_schema, v_my_foods_table
        ) into v_got_orig, v_got_attr, v_got_code, v_got_source
        using v_copier, 'of-accept-copy';
        if v_got_orig is distinct from 'probe copy upsert stripped'
           or v_got_attr is distinct from v_published_attribution
           or v_got_code is distinct from '01088'
           or v_got_source is distinct from v_source then
          raise exception 'ACCEPTANCE FAIL: upsert stripped attribution (% / % / % / %)',
            v_got_orig, v_got_attr, v_got_code, v_got_source;
        end if;

        begin
          execute format(
            'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 180, ''g'', 156, ''copied'', $4, $5) on conflict (user_id, food_id) do update set name = excluded.name, normalized_name = excluded.normalized_name, copied_from_food_id = excluded.copied_from_food_id, copied_from_owner_user_id = excluded.copied_from_owner_user_id',
            v_schema, v_my_foods_table, v_prov_source_col
          ) using v_copier, 'of-accept-copy', 'probe copy upsert stolen', 'of-accept-secret', v_other;
          raise exception 'ACCEPTANCE FAIL: upsert accepted someone else''s private copied_from';
        exception
          when others then
            if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
              raise;
            end if;
            if position('copied_from' in sqlerrm) = 0
               or position('attribution' in sqlerrm) > 0 then
              raise exception 'ACCEPTANCE FAIL: upsert onto a private copied_from failed for another reason: % %',
                sqlstate, sqlerrm;
            end if;
        end;
        execute format(
          'select copied_from_food_id, %I from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_schema, v_my_foods_table
        ) into v_got, v_got_attr
        using v_copier, 'of-accept-copy';
        if v_got is distinct from 'of-accept-probe'
           or v_got_attr is distinct from v_published_attribution then
          raise exception 'ACCEPTANCE FAIL: failed upsert changed the copy (% / %)', v_got, v_got_attr;
        end if;

        execute 'reset role';
        execute format(
          'delete from %I.%I where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) using v_uid, 'of-accept-probe';
        perform set_config('request.jwt.claim.sub', v_copier::text, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        execute format('set local role %I', v_auth_role);
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, %I, %I, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 180, ''g'', 156, $4, $5, $6, $7, $8, $9) on conflict (user_id, food_id) do update set name = excluded.name, normalized_name = excluded.normalized_name, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, %I = excluded.%I, copied_from_food_id = excluded.copied_from_food_id, copied_from_owner_user_id = excluded.copied_from_owner_user_id',
          v_schema, v_my_foods_table, v_prov_source_col, v_prov_code_col, v_prov_name_col, v_attr_col,
          v_prov_source_col, v_prov_source_col, v_prov_code_col, v_prov_code_col, v_prov_name_col, v_prov_name_col, v_attr_col, v_attr_col
        ) using v_copier, 'of-accept-copy', 'probe copy upsert deleted', v_source, '01088', v_probe_name, v_published_attribution, 'of-accept-probe', v_uid;
        execute format(
          'select name, %I, %I, copied_from_food_id from %I.%I where user_id = $1 and food_id = $2',
          v_attr_col, v_prov_source_col, v_schema, v_my_foods_table
        ) into v_got_orig, v_got_attr, v_got_source, v_got
        using v_copier, 'of-accept-copy';
        if v_got_orig is distinct from 'probe copy upsert deleted'
           or v_got_attr is distinct from v_published_attribution
           or v_got_source is distinct from v_source
           or v_got is distinct from 'of-accept-probe' then
          raise exception 'ACCEPTANCE FAIL: upsert could not edit a copy after the source was deleted (% / % / % / %)',
            v_got_orig, v_got_attr, v_got_source, v_got;
        end if;

        execute 'reset role';
        execute format(
          'alter table %I.%I disable trigger enforce_mext_saved_food_attribution',
          v_schema, v_my_foods_table
        );
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 230, ''g'', 10, ''copied'', $4, null)',
          v_schema, v_my_foods_table, v_prov_source_col
        ) using v_copier, 'of-accept-legacy', 'probe legacy', 'of-accept-probe';
        execute format(
          'alter table %I.%I enable trigger enforce_mext_saved_food_attribution',
          v_schema, v_my_foods_table
        );
        perform set_config('request.jwt.claim.sub', v_copier::text, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        execute format('set local role %I', v_auth_role);
        execute format(
          'insert into %I.%I (user_id, food_id, visibility, status, name, normalized_name, base_amount, unit_type, kcal_per_base, %I, copied_from_food_id, copied_from_owner_user_id) values ($1, $2, ''private'', ''active'', $3, $3, 230, ''g'', 10, ''copied'', $4, null) on conflict (user_id, food_id) do update set name = excluded.name, normalized_name = excluded.normalized_name, copied_from_food_id = excluded.copied_from_food_id, copied_from_owner_user_id = excluded.copied_from_owner_user_id',
          v_schema, v_my_foods_table, v_prov_source_col
        ) using v_copier, 'of-accept-legacy', 'probe legacy upsert', 'of-accept-probe';
        execute format(
          'select name, copied_from_food_id, copied_from_owner_user_id::text from %I.%I where user_id = $1 and food_id = $2',
          v_schema, v_my_foods_table
        ) into v_got_orig, v_got, v_unit
        using v_copier, 'of-accept-legacy';
        if v_got_orig is distinct from 'probe legacy upsert'
           or v_got is distinct from 'of-accept-probe'
           or v_unit is not null then
          raise exception 'ACCEPTANCE FAIL: upsert could not edit a null-owner row (% / % / %)',
            v_got_orig, v_got, v_unit;
        end if;

        raise exception using errcode = 'P0001', message = 'ACCEPTANCE_PROBE_DONE';
      exception
        when sqlstate 'P0001' then
          if sqlerrm is distinct from 'ACCEPTANCE_PROBE_DONE' then
            raise;
          end if;
      end;
    exception when others then
      if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
        raise;
      end if;
      raise exception 'ACCEPTANCE FAIL: published attribution probe failed: % %', sqlstate, sqlerrm;
    end;
    end if;
  end if;

  v_step := 'user-objects';
  v_fp_sql := $fp$
select jsonb_build_object(
  'kind', 'official_foods_user_table_snapshot',
  'taken_at', timezone('utc', now()),
  'database', current_database(),
  'tables', coalesce((
    select jsonb_object_agg(s.relname, jsonb_build_object('n', s.n, 'sig', s.sig) order by s.relname)
    from (
      select
        t.relname,
        (
          select (xpath('//c/text()', query_to_xml(
            format('select count(*)::bigint as c from public.%I', t.relname),
            false, true, ''
          )))[1]::text::bigint
        ) as n,
        md5(concat_ws(e'\n',
          coalesce(t.relacl::text, ''),
          coalesce(obj_description(t.oid, 'pg_class'), ''),
          coalesce((
            select string_agg(
              concat_ws(':',
                a.attnum::text,
                a.attname,
                a.atttypid::text,
                a.atttypmod::text,
                a.attnotnull::text,
                a.attidentity,
                a.attgenerated,
                coalesce(pg_get_expr(ad.adbin, ad.adrelid), '')
              ),
              '|' order by a.attnum
            )
            from pg_attribute a
            left join pg_attrdef ad
              on ad.adrelid = a.attrelid
             and ad.adnum = a.attnum
            where a.attrelid = t.oid
              and a.attnum > 0
              and not a.attisdropped
          ), ''),
          coalesce((
            select string_agg(
              concat_ws(':', con.contype, con.conname, pg_get_constraintdef(con.oid)),
              '|' order by con.conname
            )
            from pg_constraint con
            where con.conrelid = t.oid
          ), ''),
          coalesce((
            select string_agg(pg_get_indexdef(i.indexrelid), '|' order by ic.relname)
            from pg_index i
            join pg_class ic on ic.oid = i.indexrelid
            where i.indrelid = t.oid
          ), ''),
          coalesce((
            select string_agg(pg_get_triggerdef(tg.oid), '|' order by tg.tgname)
            from pg_trigger tg
            where tg.tgrelid = t.oid
              and not tg.tgisinternal
          ), ''),
          coalesce((
            select string_agg(
              concat_ws(':',
                pol.polname,
                pol.polcmd,
                pol.polpermissive::text,
                pol.polroles::text,
                coalesce(pg_get_expr(pol.polqual, pol.polrelid), ''),
                coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')
              ),
              '|' order by pol.polname
            )
            from pg_policy pol
            where pol.polrelid = t.oid
          ), '')
        )) as sig
      from pg_class t
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relkind in ('r', 'p')
    ) s
  ), '{}'::jsonb),
  'views', coalesce((
    select jsonb_object_agg(
      c.relname,
      jsonb_build_object(
        'sig', md5(concat_ws(e'\n',
          c.relkind::text,
          coalesce(c.relacl::text, ''),
          coalesce(pg_get_viewdef(c.oid, false), '')
        ))
      )
      order by c.relname
    )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('v', 'm')
  ), '{}'::jsonb),
  'routines', coalesce((
    select jsonb_object_agg(
      p.prokind::text || ':' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
      jsonb_build_object(
        'name', p.proname,
        'sig', md5(concat_ws('|',
          p.prokind::text,
          p.prosecdef::text,
          p.provolatile,
          p.proowner::text,
          p.proargtypes::text,
          p.prorettype::text,
          coalesce(p.proconfig::text, ''),
          coalesce(p.probin, ''),
          p.prosrc
        ))
      )
      order by p.proname, pg_get_function_identity_arguments(p.oid)
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  ), '{}'::jsonb),
  'sequences', coalesce((
    select jsonb_object_agg(
      seq.relname,
      jsonb_build_object(
        'last', pg_sequence_last_value(seq.oid),
        'owner', t.relname
      )
      order by seq.relname
    )
    from pg_class seq
    join pg_namespace sn on sn.oid = seq.relnamespace
    join pg_depend d
      on d.objid = seq.oid
     and d.deptype in ('a', 'i')
    join pg_class t on t.oid = d.refobjid
    join pg_namespace tn on tn.oid = t.relnamespace
    where seq.relkind = 'S'
      and sn.nspname = 'public'
      and tn.nspname = 'public'
  ), '{}'::jsonb)
) as snapshot;
$fp$;
  execute v_fp_sql into v_current;

  v_base_obj := v_baseline->'tables';
  v_cur_obj := v_current->'tables';
  if v_base_obj ? v_foods_table or v_base_obj ? v_aliases_table then
    raise exception 'ACCEPTANCE FAIL: baseline already contains the official foods tables. Snapshot before the migration.';
  end if;
  if exists (
    select 1 from jsonb_object_keys(v_base_obj) k where k = any (v_exclude_tables)
  ) then
    raise exception 'ACCEPTANCE FAIL: v_exclude_tables names a table that already existed. It cannot hide changes to user tables.';
  end if;

  for v_key in
    select t.k from jsonb_object_keys(v_cur_obj) as t(k) order by 1
  loop
    if v_base_obj ? v_key then
      continue;
    end if;
    if v_key = any (v_exclude_tables) then
      continue;
    end if;
    raise exception 'ACCEPTANCE FAIL: new public table % is not listed in v_exclude_tables', v_key;
  end loop;

  for v_key in
    select t.k from jsonb_object_keys(v_base_obj) as t(k) order by 1
  loop
    if not (v_cur_obj ? v_key) then
      raise exception 'ACCEPTANCE FAIL: public table % disappeared', v_key;
    end if;
    if (v_base_obj->v_key->>'sig') is distinct from (v_cur_obj->v_key->>'sig') then
      if v_key = any (v_ignore_signature_for) then
        v_ignored := v_ignored || jsonb_build_array(v_key);
      else
        v_sig_fails := v_sig_fails || jsonb_build_array(v_key);
      end if;
    end if;
    if (v_base_obj->v_key->>'n')::bigint is distinct from (v_cur_obj->v_key->>'n')::bigint then
      v_deltas := v_deltas || jsonb_build_array(jsonb_build_object(
        'table', v_key,
        'before', v_base_obj->v_key->'n',
        'after', v_cur_obj->v_key->'n'
      ));
    end if;
  end loop;
  if v_sig_fails <> '[]'::jsonb then
    raise exception 'ACCEPTANCE FAIL: user table signature changed: %. Row contents are a separate check. Do not add these names to v_exclude_tables.', v_sig_fails;
  end if;
  if v_count_match_required and v_deltas <> '[]'::jsonb then
    raise exception 'ACCEPTANCE FAIL: user table row counts changed: %. Freeze writes and re-snapshot, or record the delta and set v_count_match_required only after review.', v_deltas;
  end if;

  v_base_obj := v_baseline->'views';
  v_cur_obj := v_current->'views';
  for v_key in select t.k from jsonb_object_keys(v_cur_obj) as t(k) order by 1 loop
    if (v_base_obj ? v_key) or v_key = any (v_exclude_new_views) then
      continue;
    end if;
    raise exception 'ACCEPTANCE FAIL: new public view % is not listed in v_exclude_new_views', v_key;
  end loop;
  for v_key in select t.k from jsonb_object_keys(v_base_obj) as t(k) order by 1 loop
    if not (v_cur_obj ? v_key) then
      raise exception 'ACCEPTANCE FAIL: public view % disappeared', v_key;
    end if;
    if (v_base_obj->v_key->>'sig') is distinct from (v_cur_obj->v_key->>'sig') then
      raise exception 'ACCEPTANCE FAIL: public view % changed', v_key;
    end if;
  end loop;

  v_base_obj := v_baseline->'routines';
  v_cur_obj := v_current->'routines';
  for v_key in select t.k from jsonb_object_keys(v_cur_obj) as t(k) order by 1 loop
    if v_base_obj ? v_key then
      continue;
    end if;
    v_rname := v_cur_obj->v_key->>'name';
    if v_rname = any (v_exclude_routines) then
      continue;
    end if;
    raise exception 'ACCEPTANCE FAIL: new public routine % (%) is not listed in v_exclude_routines', v_key, v_rname;
  end loop;
  for v_key in select t.k from jsonb_object_keys(v_base_obj) as t(k) order by 1 loop
    if not (v_cur_obj ? v_key) then
      raise exception 'ACCEPTANCE FAIL: public routine % disappeared', v_key;
    end if;
    if (v_base_obj->v_key->>'sig') is distinct from (v_cur_obj->v_key->>'sig') then
      raise exception 'ACCEPTANCE FAIL: public routine % changed', v_key;
    end if;
  end loop;

  v_base_obj := v_baseline->'sequences';
  v_cur_obj := v_current->'sequences';
  for v_key in select t.k from jsonb_object_keys(v_cur_obj) as t(k) order by 1 loop
    if v_base_obj ? v_key then
      continue;
    end if;
    v_owner_table := v_cur_obj->v_key->>'owner';
    if v_owner_table = any (v_exclude_tables) then
      continue;
    end if;
    raise exception 'ACCEPTANCE FAIL: new sequence % owned by %', v_key, v_owner_table;
  end loop;
  for v_key in select t.k from jsonb_object_keys(v_base_obj) as t(k) order by 1 loop
    if not (v_cur_obj ? v_key) then
      raise exception 'ACCEPTANCE FAIL: sequence % disappeared', v_key;
    end if;
    if (v_base_obj->v_key->>'owner') is distinct from (v_cur_obj->v_key->>'owner') then
      raise exception 'ACCEPTANCE FAIL: sequence % owner changed', v_key;
    end if;
    if (v_base_obj->v_key->'last') is distinct from (v_cur_obj->v_key->'last') then
      v_seq_deltas := v_seq_deltas || jsonb_build_array(jsonb_build_object(
        'sequence', v_key,
        'before', v_base_obj->v_key->'last',
        'after', v_cur_obj->v_key->'last'
      ));
    end if;
  end loop;
  if v_count_match_required and v_seq_deltas <> '[]'::jsonb then
    raise exception 'ACCEPTANCE FAIL: user sequence values changed: %', v_seq_deltas;
  end if;

  v_detail := jsonb_build_object(
    'database', current_database(),
    'edition_rows', v_expected_count,
    'total_rows', v_total,
    'trgm_schema', v_trgm_schema,
    'search_first', v_search_first,
    'gyudon_codes', v_codes,
    'user_table_count_deltas', v_deltas,
    'user_sequence_deltas', v_seq_deltas,
    'ignored_signature', v_ignored,
    'count_match_required', v_count_match_required,
    'search_input_cap', v_search_input_cap,
    'published_attribution', v_published_attribution
  );

  create temp table official_foods_acceptance_result (
    status text not null,
    detail jsonb not null
  ) on commit drop;
  insert into official_foods_acceptance_result values ('PASS', v_detail);
  raise notice 'ACCEPTANCE PASS %', v_detail::text;
exception
  when others then
    if position('ACCEPTANCE FAIL:' in sqlerrm) = 1 then
      raise;
    end if;
    if sqlerrm = 'ACCEPTANCE_PROBE_DONE' then
      raise exception 'ACCEPTANCE FAIL: probe marker escaped at step %', v_step;
    end if;
    raise exception 'ACCEPTANCE FAIL: step % failed: % %', v_step, sqlstate, sqlerrm;
end
$accept$;

select status, detail from official_foods_acceptance_result;

commit;
