-- Search, privileges, and the shared normalizer cases.
-- The sample CSV is already loaded. Run as the migration owner, then as
-- authenticated. public_food_name_is_banned is optional (PR #26).

do $$
begin
  if to_regprocedure('public.public_food_name_is_banned(text)') is null then
    raise notice 'public_food_name_is_banned is absent; official names were not checked (PR #26)';
  else
    perform public.public_food_name_is_banned(name)
    from public.official_foods
    where food_code in ('01088', '12004', '13003');
    raise notice 'public_food_name_is_banned ran on official sample names';
  end if;
end
$$;

do $$
declare
  sample text;
  expected text;
  got text;
begin
  for sample, expected in
    select *
    from (values
      ('ご飯', 'ご飯'),
      ('ごはん', 'ごはん'),
      ('ゴハン', 'ごはん'),
      ('ｺﾞﾊﾝ', 'ごはん'),
      ('白米', '白米'),
      ('ライス', 'らいす'),
      ('ﾗｲｽ', 'らいす'),
      ('ラーメン', 'らめん'),
      ('トースト', 'とすと'),
      ('食パン', '食ぱん'),
      ('ギョーザ', 'ぎょざ'),
      ('カレーライスのルー', 'かれらいすのる'),
      ('ウィンナー', 'うぃんな'),
      ('ＡＢＣ', 'abc'),
      ('ご　飯', 'ご飯'),
      ('たまご', 'たまご'),
      ('タマゴ', 'たまご'),
      ('鶏むね', '鶏むね'),
      ('とうふ', 'とうふ'),
      ('ぎゅうにゅう', 'ぎゅうにゅう')
    ) as cases(sample, expected)
  loop
    got := public.normalize_food_search_text(sample);
    if got is distinct from expected then
      raise exception 'normalize(%) = %, expected %', sample, got, expected;
    end if;
  end loop;
end
$$;

set role authenticated;

do $$
declare
  n integer;
  got text;
  query text;
  expected text;
begin
  select count(*) into n from public.official_foods;
  if n <> 44 then
    raise exception 'authenticated select saw % official foods, expected 44', n;
  end if;

  select count(*) into n from public.search_official_foods('', 30);
  if n <> 0 then
    raise exception 'empty query returned % rows', n;
  end if;

  for query, expected in
    select *
    from (values
      ('ご飯', '01088'),
      ('ごはん', '01088'),
      ('ゴハン', '01088'),
      ('ｺﾞﾊﾝ', '01088'),
      ('白米', '01088'),
      ('ライス', '01088'),
      ('たまご', '12004'),
      ('玉子', '12004'),
      ('ラーメン', '01048'),
      ('らーめん', '01048'),
      ('鶏むね', '11220'),
      ('とうふ', '04032'),
      ('ぎゅうにゅう', '13003')
    ) as cases(query, expected)
  loop
    select s.food_code into got
    from public.search_official_foods(query, 30) s
    limit 1;
    if got is distinct from expected then
      raise exception '% first food_code = %, expected %', query, got, expected;
    end if;
  end loop;

  select s.is_candidate::text into got
  from public.search_official_foods('ご飯', 5) s
  limit 1;
  if got::text is distinct from 'false' then
    raise exception 'ご飯 first row is a candidate (%). Exact aliases sort first', got;
  end if;

  if (
    select count(*)
    from public.search_official_foods('牛丼', 30) s
    where s.is_candidate
  ) < 2 then
    raise exception '牛丼 returned fewer than 2 candidates';
  end if;
  if not exists (
    select 1
    from public.search_official_foods('牛丼', 30) s
    where s.is_candidate and s.name like '%牛飯の具%'
  ) then
    raise exception '牛丼 candidates do not include 牛飯の具';
  end if;
  if not exists (
    select 1
    from public.search_official_foods('牛丼', 30) s
    where s.is_candidate
      and s.name like '%水稲めし%'
      and s.name like '%精白米%'
  ) then
    raise exception '牛丼 candidates do not include 精白米めし';
  end if;
end
$$;

do $$
begin
  insert into public.official_foods (food_code, name, normalized_name)
  values ('99999', 'denied', 'denied');
  raise exception 'authenticated insert succeeded';
exception
  when insufficient_privilege then
    null;
end
$$;

set role anon;

do $$
begin
  insert into public.official_foods (food_code, name, normalized_name)
  values ('99998', 'denied', 'denied');
  raise exception 'anon insert succeeded';
exception
  when insufficient_privilege then
    null;
end
$$;

do $$
begin
  perform 1 from public.search_official_foods('ご飯', 1);
  raise exception 'anon search succeeded';
exception
  when insufficient_privilege then
    null;
end
$$;

reset role;
