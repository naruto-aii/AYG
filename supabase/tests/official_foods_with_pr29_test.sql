-- My Food writes after PR #29's column grants plus this branch's columns.
-- authenticated must be able to insert, update, and publish while naming
-- official_food_code, official_food_name, and source_attribution.

do $$
declare
  uid uuid := '44444444-4444-4444-4444-444444444444';
  attribution text :=
    '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';
begin
  if not has_column_privilege(
       'authenticated', 'public.saved_foods', 'official_food_code', 'INSERT'
     )
     or not has_column_privilege(
       'authenticated', 'public.saved_foods', 'official_food_name', 'INSERT'
     )
     or not has_column_privilege(
       'authenticated', 'public.saved_foods', 'source_attribution', 'INSERT'
     )
     or not has_column_privilege(
       'authenticated', 'public.saved_foods', 'official_food_code', 'UPDATE'
     )
     or not has_column_privilege(
       'authenticated', 'public.saved_foods', 'official_food_name', 'UPDATE'
     )
     or not has_column_privilege(
       'authenticated', 'public.saved_foods', 'source_attribution', 'UPDATE'
     ) then
    raise exception 'authenticated lacks column privileges on the provenance columns';
  end if;

  insert into auth.users (id, email)
  values (uid, 'column-grant@example.com');
  insert into public.users (id, email)
  values (uid, 'column-grant@example.com');

  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, source_attribution
  ) values (
    uid, 'plain-grant', 'りんご', 'りんご', 100, 'g',
    'manual', null, null, null
  );

  update public.saved_foods
  set name = 'りんご更新',
      normalized_name = 'りんご更新',
      official_food_code = null,
      official_food_name = null,
      source_attribution = null
  where user_id = uid and food_id = 'plain-grant';

  if not found then
    raise exception 'authenticated update did not see the plain food';
  end if;

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type,
    source_type, official_food_code, official_food_name, source_attribution
  ) values (
    uid, 'mext-grant', 'ご飯', 'ご飯', 100, 'g',
    'mext_sfct', '01088', 'こめ', attribution
  );

  update public.saved_foods
  set name = 'ごはん',
      normalized_name = 'ごはん',
      official_food_code = '01088',
      official_food_name = 'こめ',
      source_attribution = attribution
  where user_id = uid and food_id = 'mext-grant';

  perform public.publish_saved_food('mext-grant');

  if (
    select visibility || ' ' || coalesce(source_attribution, '')
    from public.saved_foods
    where user_id = uid and food_id = 'mext-grant'
  ) is distinct from 'public ' || attribution then
    raise exception 'authenticated publish lost attribution';
  end if;
end
$$;
