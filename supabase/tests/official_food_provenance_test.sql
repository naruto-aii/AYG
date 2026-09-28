-- Food code and official name are real columns. Attribution on a
-- composition-table My Food cannot be cleared, and the row can stay public.

do $$
declare
  uid uuid := '11111111-1111-1111-1111-111111111111';
  attribution text;
  got_source text;
  got_code text;
  got_name text;
begin
  insert into auth.users (id, email)
  values (uid, 'provenance@example.com');
  insert into public.users (id, email)
  values (uid, 'provenance@example.com');

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, visibility
  ) values (
    uid, 'mext-rice', 'ご飯', 'ご飯', 100, 'g',
    'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米', 'private'
  );

  select source_attribution into attribution
  from public.saved_foods
  where food_id = 'mext-rice';
  if attribution is distinct from
    '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'attribution was not attached: %', attribution;
  end if;

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, official_food_code, official_food_name, visibility
    ) values (
      uid, 'mext-missing', '不明', '不明', 100, 'g',
      'mext_sfct', '99999', '存在しない食品', 'private'
    );
    raise exception 'missing official food code was accepted';
  exception
    when others then
      if sqlerrm not like '%official_foods%' then
        raise;
      end if;
  end;

  select source_type, official_food_code, official_food_name, source_attribution
    into got_source, got_code, got_name, attribution
  from public.saved_foods
  where food_id = 'mext-rice';
  if got_source is distinct from 'mext_sfct'
     or got_code is distinct from '01088'
     or got_name is distinct from 'こめ　［水稲めし］　精白米　うるち米'
     or attribution is distinct from
       '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'provenance was removed: % % % %',
      got_source, got_code, got_name, attribution;
  end if;

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, visibility
  ) values (
    uid, 'mext-relabel', '卵', '卵', 100, 'g',
    'mext_sfct', '12004', '鶏卵', 'private'
  );
  update public.saved_foods
  set source_type = 'copied',
      official_food_code = null,
      official_food_name = null,
      source_attribution = null
  where food_id = 'mext-relabel';
  if (
    select source_type from public.saved_foods where food_id = 'mext-relabel'
  ) is distinct from 'copied' then
    raise exception 'table owner could not relabel a composition-table food';
  end if;

  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('ayg.allow_mext_source_change', 'on', true);
  execute 'set local role authenticated';

  update public.saved_foods
  set source_attribution = null,
      source_type = 'manual',
      official_food_code = null
  where food_id = 'mext-rice';

  if not found then
    raise exception 'authenticated update did not see the row';
  end if;

  select source_type, official_food_code, official_food_name, source_attribution
    into got_source, got_code, got_name, attribution
  from public.saved_foods
  where food_id = 'mext-rice';
  if got_source is distinct from 'mext_sfct'
     or got_code is distinct from '01088'
     or got_name is distinct from 'こめ　［水稲めし］　精白米　うるち米'
     or attribution is distinct from
       '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'authenticated bypassed the attribution lock: % % % %',
      got_source, got_code, got_name, attribution;
  end if;

  perform public.publish_saved_food('mext-rice');

  if (
    select visibility from public.saved_foods where food_id = 'mext-rice'
  ) is distinct from 'public' then
    raise exception 'mext food could not be published';
  end if;

  update public.saved_foods
  set source_attribution = 'removed'
  where food_id = 'mext-rice';

  if (
    select source_attribution from public.saved_foods where food_id = 'mext-rice'
  ) is distinct from
    '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'published attribution was replaced';
  end if;

  begin
    insert into public.food_entries (
      user_id, entry_id, name, quantity, logged_at,
      source_type, official_food_code, official_food_name
    ) values (
      uid, 'entry-missing', '不明', 1, timezone('utc', now()),
      'mext_sfct', '99999', '存在しない食品'
    );
    raise exception 'meal record accepted a missing food code';
  exception
    when others then
      if sqlerrm not like '%official_foods%' then
        raise;
      end if;
  end;

  insert into public.food_entries (
    user_id, entry_id, name, quantity, logged_at,
    source_type, official_food_code, official_food_name
  ) values (
    uid, 'entry-rice', 'ご飯', 1.5, timezone('utc', now()),
    'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米'
  );

  select official_food_code, official_food_name
    into got_code, got_name
  from public.food_entries
  where entry_id = 'entry-rice';
  if got_code is distinct from '01088'
     or got_name is distinct from 'こめ　［水稲めし］　精白米　うるち米' then
    raise exception 'meal record lost provenance: % %', got_code, got_name;
  end if;
end
$$;
