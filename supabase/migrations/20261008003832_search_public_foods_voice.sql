-- search_public_foods_voice（本番適用済み: version 20261008003832 = 2026-10-08 09:38 JST）
-- Siri（ios/Runner/SiriVoiceLog.swift）の公開食品検索を、ログイン中のトークンが切れていても使えるようにする。
--
-- これまで Siri は search_public_foods を、アプリが App Group に書いたアクセストークンで呼んでいた。
-- トークンは約1時間で切れるので、アプリを1時間以上開いていないと公開食品が黙って見つからなかった。
--
-- 新しい関数は search_public_foods と同じ検索（完全一致・前方一致・部分一致・読み・1文字違い）で、
-- 次だけが違う。既存の search_public_foods は変えない（追加だけ）。
--   - auth.uid() を見ない。anon キーで呼べる。
--   - 返すのは is_saved_food_publicly_visible（public・active・未削除・非公開処分なし）の行だけ。
--     saved_foods は RLS の saved_foods_select_public で、この行をもともと anon にも読ませている
--     （表の SELECT 権限も anon にある）。この関数で新しく見える行や列は無い。
--   - 返す列は Siri が使うものだけ（作成者 id・食品 id・名前・量・単位・栄養・version・順位）。
--     作成者 id は記録の sourceOwnerUserId に要る。
--   - 作成者のブロック（is_saved_food_visible_to_viewer）はここでは見ない。アプリが App Group に書く
--     ブロック一覧（blockedFoodCreatorIds）で、Siri が端末側で外す。一覧が無いときは公開食品を使わない。
--   - p_limit の上限は search_public_foods と同じ 100。
-- 戻し方: supabase/rollback/20261008003832_search_public_foods_voice_down.sql

create function public.search_public_foods_voice(p_query text, p_limit integer default 30)
returns table(
  user_id uuid,
  food_id text,
  name text,
  base_amount numeric,
  unit_type text,
  kcal_per_base double precision,
  protein_per_base double precision,
  fat_per_base double precision,
  carb_per_base double precision,
  version integer,
  match_rank integer
)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_name text := pg_catalog.lower(
    pg_catalog.regexp_replace(pg_catalog.btrim(v_raw), '[[:space:]]+', ' ', 'g')
  );
  v_voice text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_barcode text := pg_catalog.btrim(v_raw);
  v_limit integer := least(greatest(coalesce(p_limit, 50), 0), 100);
  v_pattern text;
  v_prefix text;
  v_voice_pattern text;
  v_voice_prefix text;
begin
  -- auth.uid() は見ない。公開中（is_saved_food_publicly_visible）の行だけを返す。
  -- 作成者のブロックは、Siri がアプリから受け取ったブロック一覧で端末側で外す。
  if v_limit = 0 then
    return;
  end if;
  if v_name = '' and v_barcode = '' then
    return;
  end if;

  v_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(pg_catalog.replace(v_name, '\', '\\'), '%', '\%'),
         '_',
         '\_'
       )
    || '%';
  v_prefix :=
    pg_catalog.replace(
      pg_catalog.replace(pg_catalog.replace(v_name, '\', '\\'), '%', '\%'),
      '_',
      '\_'
    )
    || '%';

  return query execute format(
    $sql$
    select
      sf.user_id, sf.food_id, sf.name, sf.base_amount, sf.unit_type,
      sf.kcal_per_base, sf.protein_per_base, sf.fat_per_base, sf.carb_per_base,
      sf.version,
      case
        when sf.normalized_name = %L or sf.barcode = %L then 0
        when sf.normalized_name ilike %L escape '\' then 1
        else 2
      end as match_rank
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and (
        sf.normalized_name = %L
        or sf.normalized_name ilike %L escape '\'
        or (%L <> '' and sf.barcode = %L)
      )
    order by 11, sf.updated_at desc nulls last, sf.food_id
    limit %s
    $sql$,
    v_name, v_barcode, v_prefix,
    v_name, v_pattern, v_barcode, v_barcode,
    v_limit
  );
  if found then
    return;
  end if;

  if v_voice = '' then
    return;
  end if;

  v_voice_pattern :=
    '%'
    || pg_catalog.replace(
         pg_catalog.replace(pg_catalog.replace(v_voice, '\', '\\'), '%', '\%'),
         '_',
         '\_'
       )
    || '%';
  v_voice_prefix :=
    pg_catalog.replace(
      pg_catalog.replace(pg_catalog.replace(v_voice, '\', '\\'), '%', '\%'),
      '_',
      '\_'
    )
    || '%';

  return query execute format(
    $sql$
    select
      sf.user_id, sf.food_id, sf.name, sf.base_amount, sf.unit_type,
      sf.kcal_per_base, sf.protein_per_base, sf.fat_per_base, sf.carb_per_base,
      sf.version,
      case
        when sf.voice_normalized = %L or sf.voice_reading = %L then 0
        when sf.voice_normalized like %L escape '\'
          or sf.voice_reading like %L escape '\' then 1
        else 2
      end
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and (
        sf.voice_normalized like %L escape '\'
        or sf.voice_reading like %L escape '\'
      )
    order by 11, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
    limit %s
    $sql$,
    v_voice, v_voice, v_voice_prefix, v_voice_prefix, v_voice_pattern, v_voice_pattern, v_limit
  );
  if found then
    return;
  end if;

  if pg_catalog.char_length(v_voice) < 3 or pg_catalog.char_length(v_voice) > 16 then
    return;
  end if;

  return query
  select
    sf.user_id, sf.food_id, sf.name, sf.base_amount, sf.unit_type,
    sf.kcal_per_base, sf.protein_per_base, sf.fat_per_base, sf.carb_per_base,
    sf.version,
    2 + least(
      case
        when sf.voice_normalized is not null
         and pg_catalog.char_length(sf.voice_normalized)
             between pg_catalog.char_length(v_voice) - 2
                 and pg_catalog.char_length(v_voice) + 2
         and pg_catalog.left(sf.voice_normalized, 1) = pg_catalog.left(v_voice, 1)
        then public.food_search_edit_distance(sf.voice_normalized, v_voice)
        else 99
      end,
      case
        when sf.voice_reading is not null
         and pg_catalog.char_length(sf.voice_reading)
             between pg_catalog.char_length(v_voice) - 2
                 and pg_catalog.char_length(v_voice) + 2
         and pg_catalog.left(sf.voice_reading, 1) = pg_catalog.left(v_voice, 1)
        then public.food_search_edit_distance(sf.voice_reading, v_voice)
        else 99
      end
    )
  from public.saved_foods sf
  where public.is_saved_food_publicly_visible(
          sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
        )
    and pg_catalog.char_length(v_voice) >= 4
    and (
      (
        sf.voice_normalized is not null
        and pg_catalog.char_length(sf.voice_normalized)
            between pg_catalog.char_length(v_voice) - 2
                and pg_catalog.char_length(v_voice) + 2
        and pg_catalog.left(sf.voice_normalized, 1) = pg_catalog.left(v_voice, 1)
        and public.food_search_edit_distance(sf.voice_normalized, v_voice) = 1
        and public.food_search_edit_distance(sf.voice_normalized, v_voice)::numeric
            / pg_catalog.char_length(v_voice) <= 0.34
      )
      or (
        sf.voice_reading is not null
        and pg_catalog.char_length(sf.voice_reading)
            between pg_catalog.char_length(v_voice) - 2
                and pg_catalog.char_length(v_voice) + 2
        and pg_catalog.left(sf.voice_reading, 1) = pg_catalog.left(v_voice, 1)
        and public.food_search_edit_distance(sf.voice_reading, v_voice) = 1
        and public.food_search_edit_distance(sf.voice_reading, v_voice)::numeric
            / pg_catalog.char_length(v_voice) <= 0.34
      )
    )
  order by 11, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
  limit v_limit;
end;
$function$;

revoke all on function public.search_public_foods_voice(text, integer) from public;
grant execute on function public.search_public_foods_voice(text, integer) to anon, authenticated;

comment on function public.search_public_foods_voice(text, integer) is
  'Siri 用の公開食品検索。search_public_foods と同じ検索で、公開中の行だけを、Siri が使う列だけ返す。auth.uid() を使わないので anon キーで呼べる（アプリを長く開いていなくても使える）。作成者のブロックは端末側で外す。';
