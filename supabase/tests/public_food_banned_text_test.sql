-- pgTAP: 公開食品の禁止語。ローカルの Postgres だけ。本番には繋がない。
-- 先にマイグレーションと supabase/tests/food_master_v1_1_test_helpers.sql を流す。

begin;

create extension if not exists pgtap;

-- Runs one statement as the app user, then returns the session role to postgres
-- before pgtap calls ok(). A raised error keeps its original SQLSTATE.
create or replace function ayg_test.run_as(p_user uuid, p_sql text)
returns void
language plpgsql
as $$
begin
  perform ayg_test.set_auth(p_user);
  execute p_sql;
  perform ayg_test.reset_role();
exception
  when others then
    raise;
end;
$$;

select plan(95);

select ok(
  position(
    'update public.saved_foods'
    in pg_get_functiondef('moderation.reject_banned_public_food_text()'::regprocedure)
  ) = 0,
  'the trigger does not rewrite saved_foods'
);

select ok(not moderation.text_is_banned('キャベツ'), 'cabbage stays');
select ok(not moderation.text_is_banned('テスト'), 'production public name stays');
select ok(not moderation.text_is_banned('てすと'), 'production reading stays');
select ok(not moderation.text_is_banned('g'), 'unit g stays');
select ok(moderation.text_is_banned('ＦＵＣＫ'), 'full-width latin is rejected');
select ok(moderation.text_is_banned('f u c k'), 'spaced latin is rejected');
select ok(not moderation.text_is_banned('shiitake'), 'shiitake is not a banned token');
select ok(not moderation.text_is_banned('イエロー'), 'yellow is not a short kana hit');
select ok(moderation.text_is_banned(U&'f\00FAck'), 'precomposed accent is rejected');
select ok(moderation.text_is_banned(U&'fu\0301ck'), 'combining accent is rejected');
select ok(moderation.text_is_banned(U&'fu\0441k'), 'cyrillic lookalike is rejected');
select ok(moderation.text_is_banned('5h1t'), 'digit substitution is rejected');
select ok(moderation.text_is_banned('c0ck'), 'zero substitution is rejected');
select ok(moderation.text_is_banned('$hit'), 'dollar substitution is rejected');
select ok(moderation.text_is_banned('sh!t'), 'exclamation substitution is rejected');
select ok(
  moderation.text_is_banned(U&'\FF77\FF81\FF76\FF9E\FF72'),
  'halfwidth voiced kana is rejected'
);
select ok(not moderation.text_is_banned('sea bass'), 'sea bass stays');
select ok(not moderation.text_is_banned('cocktail'), 'cocktail stays');
select ok(not moderation.text_is_banned('カフェラテ'), 'cafe latte stays');
select ok(not moderation.text_is_banned('ポークソテー'), 'pork saute stays');
select ok(not moderation.text_is_banned('ポークソーセージ'), 'pork sausage stays');
select ok(not moderation.text_is_banned('ミルクソフト'), 'milk soft stays');
select ok(not moderation.text_is_banned('スモークソルト'), 'smoked salt stays');
select ok(not moderation.text_is_banned('サンマンコ'), 'sanmanko stays');
select ok(not moderation.text_is_banned('からしねぎ'), 'karashi negi stays');
select ok(not moderation.text_is_banned('ちんげん菜'), 'chingensai stays');
select ok(not moderation.text_is_banned('ぎょにくそーせーじ'), 'gyoniku sausage reading stays');
select ok(moderation.text_is_banned('くそラーメン'), 'prefixed kuso is rejected');
select ok(moderation.text_is_banned('エロラーメン'), 'prefixed ero is rejected');
select ok(moderation.text_is_banned('まんこ丼'), 'prefixed manko is rejected');
select ok(moderation.text_is_banned('ラーメンくそ'), 'suffixed kuso is rejected');
select ok(not moderation.text_is_banned('超くそラーメン'), 'kuso in the middle of kana stays');
select ok(moderation.text_is_banned('kuso'), 'romaji kuso is rejected');
select ok(moderation.text_is_banned('unko'), 'romaji unko is rejected');
select ok(moderation.text_is_banned('chinko'), 'romaji chinko is rejected');
select ok(moderation.text_is_banned('manko'), 'romaji manko is rejected');
select ok(moderation.text_is_banned('ero'), 'romaji ero is rejected');
select ok(moderation.text_is_banned('eroramen'), 'prefixed romaji ero is rejected');
select ok(moderation.text_is_banned('ero ramen'), 'spaced romaji ero is rejected');
select ok(not moderation.text_is_banned('ramenero'), 'ero at the end of a latin word stays');
select ok(not moderation.text_is_banned('zero'), 'zero stays');
select ok(not moderation.text_is_banned('hero'), 'hero stays');
select ok(not moderation.text_is_banned('cordero'), 'cordero stays');
select ok(moderation.text_is_banned('kusoramen'), 'affixed romaji kuso is rejected');
select ok(moderation.text_is_banned('しね'), 'hiragana shine is rejected');
select ok(moderation.text_is_banned('なかだし'), 'hiragana nakadashi is rejected');
select ok(moderation.text_is_banned('ころす'), 'hiragana korosu is rejected');
select ok(moderation.text_is_banned('しねラーメン'), 'prefixed shine is rejected');
select ok(moderation.text_is_banned('f*ck'), 'star inside fuck is rejected');
select ok(moderation.text_is_banned('f@ck'), 'at inside fuck is rejected');
select ok(not moderation.text_is_banned('Cock tail'), 'spaced cocktail phrase stays');
select ok(not moderation.text_is_banned('rape seed oil'), 'rape seed oil stays');
select ok(not moderation.text_is_banned('ブラックソース'), 'black sauce stays');
select ok(not moderation.text_is_banned('やくそう'), 'herbal medicine stays');
select ok(not moderation.text_is_banned('ぶっかけうどん'), 'bukkake udon stays');
select ok(not moderation.text_is_banned('冷やしぶっかけそば'), 'chilled bukkake soba stays');
select ok(not moderation.text_is_banned('ごっくん馬路村'), 'drink name stays');
select ok(not moderation.text_is_banned('潮吹き貝'), 'shellfish stays');
select ok(moderation.text_is_banned('クソまずい'), 'insulting compound is rejected');
select ok(moderation.text_is_banned('エロい'), 'eroi is rejected');
select ok(moderation.text_is_banned('エロすぎ'), 'erosugi is rejected');
select ok(moderation.text_is_banned('おまんこ'), 'explicit compound is rejected');
select ok(moderation.text_is_banned('オマンコ'), 'katakana explicit compound is rejected');
select ok(moderation.text_is_banned('フェラチオ'), 'fellatio kana is rejected');
select ok(moderation.text_is_banned('ふぇらちお'), 'hiragana fellatio is rejected');
select ok(moderation.text_is_banned('イラマチオ'), 'irrumatio is rejected');
select ok(moderation.text_is_banned('おまんこカレー'), 'compound beside a food word is rejected');
select ok(moderation.text_is_banned('fellatio'), 'latin fellatio is rejected');
select ok(moderation.text_is_banned('くそ'), 'bare short kana term is rejected');
select ok(moderation.text_is_banned('フェラ'), 'bare kana term is rejected');
select ok(moderation.text_is_banned('まんこ'), 'bare short term is rejected');
select ok(moderation.text_is_banned('cock'), 'bare latin term is rejected');
select ok(moderation.text_is_banned('rape'), 'bare rape is rejected');
select ok(
  moderation.text_is_banned('fuck rape seed oil'),
  'banned word beside an allowed phrase is rejected'
);
select ok(
  moderation.text_is_banned(U&'\FF81\FF9D\FF8E\FF9F'),
  'halfwidth handakuten is rejected'
);

do $$
declare
  v_user uuid := '66666666-6666-6666-6666-666666666666';
begin
  delete from public.saved_foods where user_id = v_user;
  delete from public.users where id = v_user;
  delete from auth.users where id = v_user;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) values (
    v_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'banned-name@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()
  );
  insert into public.users (id, email) values (v_user, 'banned-name@test.local');

  perform ayg_test.set_auth(v_user);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values
    (v_user, 'banned-publish', 'fuck', 'fuck', 100, 'g', 'private'),
    (v_user, 'ok-publish', 'キャベツ', 'キャベツ', 100, 'g', 'private'),
    (v_user, 'brand-banned', 'キャベツ', 'キャベツ', 100, 'g', 'private');

  update public.saved_foods
  set brand = 'shit'
  where user_id = v_user and food_id = 'brand-banned';

  -- set_auth is SET LOCAL and would otherwise hide pgtap from this role.
  perform ayg_test.reset_role();
end;
$$;

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$select public.publish_saved_food('banned-publish')$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'publishing a banned name fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$select public.publish_saved_food('brand-banned')$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'publishing a banned brand fails'
);

select lives_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$select public.publish_saved_food('ok-publish')$q$
  )$sql$,
  'an ordinary name can be published'
);

select is(
  (
    select visibility
    from public.saved_foods
    where food_id = 'banned-publish'
  ),
  'private',
  'a rejected publish stays private'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set name = 'うんこ', normalized_name = 'うんこ'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'renaming a public food to a banned word fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set brand = 'c0ck'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'a banned brand on a public food fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set serving_unit_label = 'sh!t'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'a banned unit label on a public food fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set supplementary_weight = 'fuck'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'banned supplementary text on a public food fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set barcode = 'fuck'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'a banned barcode on a public food fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set voice_reading = 'くそ', voice_katakana = 'クソ', voice_normalized = 'くそ'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'banned voice text on a public food fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set voice_katakana = 'ファック'
      where food_id = 'ok-publish'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'a banned voice katakana on a public food fails'
);

select lives_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods set kcal_per_base = 40 where food_id = 'ok-publish'$q$
  )$sql$,
  'a non-text update of a public row still works'
);

select is(
  (select kcal_per_base from public.saved_foods where food_id = 'ok-publish'),
  40::double precision,
  'the calorie update was stored'
);

select is(
  (select name from public.saved_foods where food_id = 'ok-publish'),
  'キャベツ',
  'the rejected rename did not replace the public name'
);

do $$
begin
  perform ayg_test.set_service_role();
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility, voice_reading
  ) values (
    '66666666-6666-6666-6666-666666666666',
    'voice-replaced', 'にんじん', 'にんじん', 80, 'g', 'public', 'くそ'
  );
  perform ayg_test.reset_role();
end;
$$;

select ok(
  (select voice_reading from public.saved_foods where food_id = 'voice-replaced')
    is distinct from 'くそ',
  'a client banned reading is replaced from the name before the ban check'
);

select ok(
  not moderation.text_is_banned(
    '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成'
  ),
  'the composition-table attribution is not banned'
);

do $$
begin
  perform ayg_test.set_service_role();
  alter table public.saved_foods disable trigger saved_foods_reject_banned_public_text;
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (
    '66666666-6666-6666-6666-666666666666',
    'legacy-banned', 'fuck', 'fuck', 50, 'g', 'public'
  );
  alter table public.saved_foods enable trigger saved_foods_reject_banned_public_text;
  perform ayg_test.reset_role();
end;
$$;

select lives_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods set kcal_per_base = 12 where food_id = 'legacy-banned'$q$
  )$sql$,
  'an already public banned name can still change other fields'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$update public.saved_foods
      set name = 'shit', normalized_name = 'shit'
      where food_id = 'legacy-banned'$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'changing that legacy name to another banned word fails'
);

select throws_ok(
  $sql$select ayg_test.run_as(
    '66666666-6666-6666-6666-666666666666',
    $q$insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
    ) values (
      '66666666-6666-6666-6666-666666666666',
      'unlisted-banned', 'うんこ', 'うんこ', 10, 'g', 'unlisted'
    )$q$
  )$sql$,
  '23514',
  'moderation banned public food text',
  'an unlisted banned name is rejected'
);

select * from finish();

rollback;
