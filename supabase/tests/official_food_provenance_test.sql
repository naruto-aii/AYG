-- Food code and official name are real columns. Attribution on a
-- composition-table My Food cannot be cleared, and the row can stay public.
-- The trigger functions are not directly executable by authenticated.

do $$
begin
  if has_function_privilege(
       'authenticated',
       'public.enforce_mext_saved_food_attribution()',
       'execute'
     )
     or has_function_privilege(
       'anon',
       'public.enforce_mext_saved_food_attribution()',
       'execute'
     )
     or has_function_privilege(
       'authenticated',
       'public.enforce_mext_food_entry_code()',
       'execute'
     )
     or has_function_privilege(
       'anon',
       'public.enforce_mext_food_entry_code()',
       'execute'
     ) then
    raise exception 'trigger functions are still executable by anon or authenticated';
  end if;
end
$$;

do $$
declare
  uid uuid := '11111111-1111-1111-1111-111111111111';
  copier uuid := '33333333-3333-3333-3333-333333333333';
  attribution text;
  got_source text;
  got_code text;
  got_name text;
begin
  insert into auth.users (id, email)
  values
    (uid, 'provenance@example.com'),
    (copier, 'copier@example.com');
  insert into public.users (id, email)
  values
    (uid, 'provenance@example.com'),
    (copier, 'copier@example.com');

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

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, visibility
  ) values (
    uid, 'plain-soup', '味噌汁', '味噌汁', 200, 'ml',
    'manual', 'private'
  );
  perform public.publish_saved_food('plain-soup');

  perform set_config('request.jwt.claim.sub', copier::text, true);

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id,
    official_food_code, official_food_name, source_attribution, visibility
  ) values (
    copier, 'mext-copy', '白ごはん', '白ごはん', 100, 'g',
    'copied', 'mext-rice', uid,
    null, null, null, 'private'
  );

  select source_type, official_food_code, official_food_name, source_attribution
    into got_source, got_code, got_name, attribution
  from public.saved_foods
  where user_id = copier and food_id = 'mext-copy';
  if got_source is distinct from 'mext_sfct'
     or got_code is distinct from '01088'
     or got_name is distinct from 'こめ　［水稲めし］　精白米　うるち米'
     or attribution is distinct from
       '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'copy dropped composition-table provenance: % % % %',
      got_source, got_code, got_name, attribution;
  end if;

  update public.saved_foods
  set source_type = 'copied',
      official_food_code = null,
      official_food_name = null,
      source_attribution = null
  where user_id = copier and food_id = 'mext-copy';

  select source_type, source_attribution
    into got_source, attribution
  from public.saved_foods
  where user_id = copier and food_id = 'mext-copy';
  if got_source is distinct from 'mext_sfct'
     or attribution is distinct from
       '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'copier cleared locked provenance: % %', got_source, attribution;
  end if;

  perform public.publish_saved_food('mext-copy');
  if (
    select visibility || ' ' || source_type || ' ' || source_attribution
    from public.saved_foods
    where user_id = copier and food_id = 'mext-copy'
  ) is distinct from
    'public mext_sfct 出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'published copy lost attribution';
  end if;

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id, visibility
  ) values (
    copier, 'plain-copy', 'うちのみそ汁', 'うちのみそ汁', 200, 'ml',
    'copied', 'plain-soup', uid, 'private'
  );
  if (
    select source_type from public.saved_foods
    where user_id = copier and food_id = 'plain-copy'
  ) is distinct from 'copied' then
    raise exception 'ordinary public food was rewritten as composition-table';
  end if;
end
$$;

-- Direct API as authenticated. A private plain copy that only points at a
-- composition-table food through another copy must still inherit provenance.
-- Publishing the unattributed middle row must fail.
do $$
declare
  uid uuid := '11111111-1111-1111-1111-111111111111';
  copier uuid := '33333333-3333-3333-3333-333333333333';
  got_source text;
  got_code text;
  attribution text;
begin
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id, visibility
  ) values (
    copier, 'mext-bridge', '経由', '経由', 100, 'g',
    'copied', 'mext-rice', uid, 'private'
  );
  if (
    select source_type from public.saved_foods
    where user_id = copier and food_id = 'mext-bridge'
  ) is distinct from 'copied' then
    raise exception 'owner fixture was rewritten before the client call';
  end if;

  perform set_config('request.jwt.claim.sub', copier::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id,
    official_food_code, official_food_name, source_attribution, visibility
  ) values (
    copier, 'mext-chain', 'さらに写し', 'さらに写し', 100, 'g',
    'copied', 'mext-bridge', copier,
    null, null, null, 'private'
  );

  select source_type, official_food_code, source_attribution
    into got_source, got_code, attribution
  from public.saved_foods
  where user_id = copier and food_id = 'mext-chain';
  if got_source is distinct from 'mext_sfct'
     or got_code is distinct from '01088'
     or attribution is distinct from
       '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'transitive copy dropped provenance: % % %',
      got_source, got_code, attribution;
  end if;

  begin
    perform public.publish_saved_food('mext-bridge');
    raise exception 'unattributed composition-table copy was published';
  exception
    when others then
      if sqlerrm not like '%attribution%' then
        raise;
      end if;
  end;

  if (
    select visibility from public.saved_foods
    where user_id = copier and food_id = 'mext-bridge'
  ) is distinct from 'private' then
    raise exception 'failed publish left the copy public';
  end if;

  perform public.publish_saved_food('mext-chain');
  if (
    select visibility || ' ' || source_attribution
    from public.saved_foods
    where user_id = copier and food_id = 'mext-chain'
  ) is distinct from
    'public 出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成' then
    raise exception 'attributed transitive copy could not be published';
  end if;
end
$$;

-- Forged copied_from. (c) A food code without the canonical attribution
-- cannot be published even when copied_from points at an ordinary food.
-- copied_from must be the writer's own row or a public row.
do $$
declare
  uid uuid := '11111111-1111-1111-1111-111111111111';
  copier uuid := '33333333-3333-3333-3333-333333333333';
  stranger uuid := '55555555-5555-5555-5555-555555555555';
begin
  insert into auth.users (id, email)
  values (stranger, 'stranger@example.com');
  insert into public.users (id, email)
  values (stranger, 'stranger@example.com');
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, visibility
  ) values (
    stranger, 'secret-food', '秘密の弁当', '秘密の弁当', 100, 'g',
    'manual', 'private'
  );

  perform set_config('request.jwt.claim.sub', copier::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id,
    official_food_code, official_food_name, source_attribution, visibility
  ) values (
    copier, 'forged-code', '偽装ごはん', '偽装ごはん', 100, 'g',
    'copied', 'plain-soup', uid,
    '01088', 'こめ　［水稲めし］　精白米　うるち米', null, 'private'
  );

  begin
    perform public.publish_saved_food('forged-code');
    raise exception 'forged copy with a food code was published without attribution';
  exception
    when others then
      if sqlerrm not like '%attribution%' then
        raise;
      end if;
  end;

  if (
    select visibility from public.saved_foods
    where user_id = copier and food_id = 'forged-code'
  ) is distinct from 'private' then
    raise exception 'failed forged publish left the food public';
  end if;

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, copied_from_food_id, copied_from_owner_user_id, visibility
    ) values (
      copier, 'forged-private', '見えない写し', '見えない写し', 100, 'g',
      'copied', 'secret-food', stranger, 'private'
    );
    raise exception 'copied_from accepted a food the user cannot read';
  exception
    when others then
      if sqlerrm not like '%copied_from%' then
        raise;
      end if;
  end;

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, copied_from_food_id, copied_from_owner_user_id,
      official_food_code, source_attribution, visibility
    ) values (
      copier, 'forged-owner', '所有者ちがい', '所有者ちがい', 100, 'g',
      'copied', 'mext-rice', copier,
      '01088', null, 'private'
    );
    raise exception 'copied_from accepted a food id with the wrong owner';
  exception
    when others then
      if sqlerrm not like '%copied_from%' then
        raise;
      end if;
  end;
end
$$;

-- (a) After the source becomes private, the copier can still edit and
-- publish their own row. (b) A copied_from with a null owner is rejected.
-- A private composition-table row and a private ordinary row fail the
-- same way, so publish_saved_food cannot be used to tell them apart.
do $$
declare
  uid uuid := '11111111-1111-1111-1111-111111111111';
  copier uuid := '33333333-3333-3333-3333-333333333333';
  stranger uuid := '55555555-5555-5555-5555-555555555555';
  got_name text;
  got_visibility text;
  manual_err text;
  mext_err text;
begin
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, visibility
  ) values (
    uid, 'hide-source', '隠すご飯', '隠すご飯', 100, 'g',
    'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米', 'private'
  );
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, visibility
  ) values (
    stranger, 'secret-mext', '秘密の成分表', '秘密の成分表', 100, 'g',
    'mext_sfct', '01088', 'こめ　［水稲めし］　精白米　うるち米', 'private'
  );

  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  perform public.publish_saved_food('hide-source');
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', copier::text, true);
  execute 'set local role authenticated';

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, copied_from_food_id, copied_from_owner_user_id, visibility
  ) values (
    copier, 'edit-after-private', '写し', '写し', 100, 'g',
    'copied', 'hide-source', uid, 'private'
  );

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, copied_from_food_id, copied_from_owner_user_id, visibility
    ) values (
      copier, 'null-owner', '所有者なし', '所有者なし', 100, 'g',
      'copied', 'hide-source', null, 'private'
    );
    raise exception 'copied_from accepted a null owner';
  exception
    when others then
      if sqlerrm not like '%copied_from_owner_user_id%' then
        raise;
      end if;
  end;

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, copied_from_food_id, copied_from_owner_user_id, visibility
    ) values (
      copier, 'probe-manual', '探る', '探る', 100, 'g',
      'copied', 'secret-food', stranger, 'private'
    );
    raise exception 'copied_from accepted a private ordinary food';
  exception
    when others then
      manual_err := sqlerrm;
  end;

  begin
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type,
      source_type, copied_from_food_id, copied_from_owner_user_id, visibility
    ) values (
      copier, 'probe-mext', '探る成分表', '探る成分表', 100, 'g',
      'copied', 'secret-mext', stranger, 'private'
    );
    raise exception 'copied_from accepted a private composition-table food';
  exception
    when others then
      mext_err := sqlerrm;
  end;

  if manual_err not like '%copied_from%'
     or mext_err not like '%copied_from%'
     or manual_err like '%attribution%'
     or mext_err like '%attribution%'
     or manual_err like '%mext%'
     or mext_err like '%mext%'
     or manual_err is distinct from mext_err then
    raise exception
      'private foods were distinguishable: manual=% mext=%',
      manual_err, mext_err;
  end if;

  execute 'reset role';
  update public.saved_foods
  set visibility = 'private'
  where user_id = uid and food_id = 'hide-source';

  execute 'set local role authenticated';
  update public.saved_foods
  set name = '編集できた', normalized_name = '編集できた'
  where user_id = copier and food_id = 'edit-after-private';

  select name into got_name
  from public.saved_foods
  where user_id = copier and food_id = 'edit-after-private';
  if got_name is distinct from '編集できた' then
    raise exception 'copy could not be edited after the source became private: %',
      got_name;
  end if;

  perform public.publish_saved_food('edit-after-private');
  select visibility into got_visibility
  from public.saved_foods
  where user_id = copier and food_id = 'edit-after-private';
  if got_visibility is distinct from 'public' then
    raise exception 'attributed copy could not be published after the source became private';
  end if;

  execute 'reset role';
  delete from public.saved_foods
  where user_id = uid and food_id = 'hide-source';

  execute 'set local role authenticated';
  update public.saved_foods
  set brand = '残った'
  where user_id = copier and food_id = 'edit-after-private';
  if (
    select brand from public.saved_foods
    where user_id = copier and food_id = 'edit-after-private'
  ) is distinct from '残った' then
    raise exception 'copy could not be edited after the source was deleted';
  end if;
end
$$;
