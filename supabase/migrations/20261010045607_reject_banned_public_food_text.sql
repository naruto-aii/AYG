-- 公開・限定公開の食品に、禁止語をサーバで拒否する。
-- 対象は insert と、公開になる update、公開中の自由文（食品名・正規化名・ブランド・
-- 単位・補足重量・バーコード・音声の読み）が変わる update。
-- 非公開の食品は見ない。既に公開されている行は書き換えない。
-- アプリの新しいビルドは要らない。publish_saved_food の update もこのトリガーを通る。
--
-- 関数は API に出さない schema moderation に置く。search_path は空。
-- coalesce、greatest、NFKC の第2引数は SQL の構文なので修飾しない。
-- pg_catalog.normalize の第2引数は文字列 'NFKC'。
-- 本番にはこのファイルを適用しない。戻し方は
-- supabase/rollback/20261010045607_reject_banned_public_food_text_down.sql。

create schema if not exists moderation;

create or replace function moderation.compose_halfwidth_voiced(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_text, '');
  v_out text := '';
  i integer := 1;
  n integer := pg_catalog.char_length(v);
  ch text;
  nxt text;
  base_at integer;
  dakuten_base constant text := 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';
  dakuten_to constant text := 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ';
  handakuten_base constant text := 'ﾊﾋﾌﾍﾎ';
  handakuten_to constant text := 'パピプペポ';
begin
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
  return v_out;
end;
$$;

-- 全角半角、かな、空白と記号、似た字を畳む。食品名の照合だけに使う。
create or replace function moderation.normalize_food_text(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := pg_catalog.normalize(
    moderation.compose_halfwidth_voiced(coalesce(p_name, '')),
    'NFKC'
  );
  v_out text := '';
  i integer;
  ch text;
  cp integer;
  hw_from constant text := 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
  hw_to constant text := 'をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';
  hw_at integer;
  fold_from constant text := 'àáâãäåÀÁÂÃÄÅèéêëÈÉÊËìíîïÌÍÎÏòóôõöÒÓÔÕÖùúûüÙÚÛÜýÿÝŸñÑçÇаАеЕоОрРсСуУхХіІјЈѕЅԁԀ013457$!';
  fold_to constant text := 'aaaaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuyyyynnccaaeeooppccyyxxiijjssddoieastsi';
begin
  v := pg_catalog.replace(v, 'ß', 'ss');
  v := pg_catalog.replace(v, 'æ', 'ae');
  v := pg_catalog.replace(v, 'Æ', 'ae');
  v := pg_catalog.replace(v, 'œ', 'oe');
  v := pg_catalog.replace(v, 'Œ', 'oe');
  v := pg_catalog.translate(v, fold_from, fold_to);

  for i in 1..pg_catalog.char_length(v) loop
    ch := pg_catalog.substr(v, i, 1);
    cp := pg_catalog.ascii(ch);

    if cp between 768 and 879 then
      continue;
    end if;

    if cp = 12288 or cp = 32 or cp = 9 or cp = 10 or cp = 13 then
      if v_out <> '' and pg_catalog.right(v_out, 1) <> ' ' then
        v_out := v_out || ' ';
      end if;
      continue;
    end if;

    if cp between 65296 and 65305 then
      cp := 48 + (cp - 65296);
    elsif cp between 65313 and 65338 then
      cp := 97 + (cp - 65313);
    elsif cp between 65345 and 65370 then
      cp := 97 + (cp - 65345);
    else
      hw_at := pg_catalog.strpos(hw_from, ch);
      if hw_at > 0 then
        ch := pg_catalog.substr(hw_to, hw_at, 1);
        cp := pg_catalog.ascii(ch);
      end if;
    end if;

    if cp between 12449 and 12531 then
      cp := cp - 96;
    end if;

    if cp between 65 and 90 then
      cp := 97 + (cp - 65);
    end if;

    if cp between 97 and 122
       or cp between 48 and 57
       or cp between 12353 and 12438
       or cp between 12449 and 12538
       or cp between 19968 and 40959
       or cp = 12540 then
      v_out := v_out || pg_catalog.chr(cp);
    elsif v_out <> '' and pg_catalog.right(v_out, 1) <> ' ' then
      v_out := v_out || ' ';
    end if;
  end loop;

  return pg_catalog.btrim(v_out);
end;
$$;

create or replace function moderation.char_is_word(p_char text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_char is not null
     and (
       pg_catalog.ascii(p_char) between 48 and 57
       or pg_catalog.ascii(p_char) between 97 and 122
       or pg_catalog.ascii(p_char) between 12353 and 12438
       or pg_catalog.ascii(p_char) between 12449 and 12538
       or pg_catalog.ascii(p_char) between 19968 and 40959
       or pg_catalog.ascii(p_char) = 12540
     );
$$;

create or replace function moderation.contains_term(p_name text, p_term text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_from integer := 1;
  v_at integer;
  v_before text;
  v_after text;
begin
  if p_term is null or p_term = '' or p_name is null or p_name = '' then
    return false;
  end if;

  loop
    v_at := pg_catalog.strpos(pg_catalog.substr(p_name, v_from), p_term);
    exit when v_at = 0;
    v_at := v_from + v_at - 1;

    if v_at = 1 then
      v_before := null;
    else
      v_before := pg_catalog.substr(p_name, v_at - 1, 1);
    end if;

    if v_at + pg_catalog.char_length(p_term) > pg_catalog.char_length(p_name) then
      v_after := null;
    else
      v_after := pg_catalog.substr(p_name, v_at + pg_catalog.char_length(p_term), 1);
    end if;

    if (v_before is null or not moderation.char_is_word(v_before))
       and (v_after is null or not moderation.char_is_word(v_after)) then
      return true;
    end if;

    v_from := v_at + 1;
  end loop;

  return false;
end;
$$;

create or replace function moderation.strip_phrase(p_name text, p_phrase text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_name, '');
  v_from integer := 1;
  v_at integer;
  v_before text;
  v_after text;
begin
  if p_phrase is null or p_phrase = '' then
    return v;
  end if;

  loop
    v_at := pg_catalog.strpos(pg_catalog.substr(v, v_from), p_phrase);
    exit when v_at = 0;
    v_at := v_from + v_at - 1;

    if v_at = 1 then
      v_before := null;
    else
      v_before := pg_catalog.substr(v, v_at - 1, 1);
    end if;

    if v_at + pg_catalog.char_length(p_phrase) > pg_catalog.char_length(v) then
      v_after := null;
    else
      v_after := pg_catalog.substr(v, v_at + pg_catalog.char_length(p_phrase), 1);
    end if;

    if (v_before is null or not moderation.char_is_word(v_before))
       and (v_after is null or not moderation.char_is_word(v_after)) then
      v := pg_catalog.substr(v, 1, greatest(v_at - 1, 0))
        || ' '
        || pg_catalog.substr(v, v_at + pg_catalog.char_length(p_phrase));
      v_from := greatest(v_at, 1);
    else
      v_from := v_at + 1;
    end if;
  end loop;

  return v;
end;
$$;

create or replace function moderation.term_uses_substring(p_term text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_term !~ '[a-z0-9]'
     and pg_catalog.char_length(p_term) >= 2
     and p_term not in (
       'えろ', 'くそ', 'ふぇら', 'まんこ', 'しね', 'なかだし', 'ころす'
     );
$$;

-- 記号がラテンの1文字の代わりに入っているとき（f*ck, f@ck）。
-- 4文字未満には使わない。食品名の誤検知を広げるため。
create or replace function moderation.latin_one_gap(p_spaced text, p_term text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  i integer;
  n integer := pg_catalog.char_length(p_term);
  pattern text;
begin
  if p_term is null or n < 4 or p_spaced is null or p_spaced = '' then
    return false;
  end if;
  if p_term !~ '^[a-z]+$' then
    return false;
  end if;

  for i in 1..n loop
    pattern := pg_catalog.btrim(
      pg_catalog.regexp_replace(
        pg_catalog.substr(p_term, 1, i - 1)
          || ' '
          || pg_catalog.substr(p_term, i + 1),
        ' +',
        ' ',
        'g'
      )
    );
    if pattern <> '' and moderation.contains_term(p_spaced, pattern) then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

-- 短い語は文の先頭か末尾に付いているときだけ追加で見る。
-- 途中の部分一致は、ポークソテー・からしねぎ・ぎょにくソーセージに当たる。
create or replace function moderation.term_is_affixed(p_compact text, p_term text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_compact is not null
     and p_term is not null
     and p_term <> ''
     and (
       p_compact = p_term
       or pg_catalog.left(p_compact, pg_catalog.char_length(p_term)) = p_term
       or pg_catalog.right(p_compact, pg_catalog.char_length(p_term)) = p_term
     )
     and not (p_term = 'まんこ' and p_compact = 'さんまんこ');
$$;

create or replace function moderation.text_is_banned(p_name text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_spaced text := moderation.normalize_food_text(p_name);
  v_compact text;
  v_term text;
  v_norm text;
  v_phrase text;
  v_words text[] := array[
    'fuck', 'fucking', 'motherfucker', 'shit', 'bullshit', 'asshole', 'bitch',
    'bastard', 'cunt', 'dick', 'cock', 'pussy', 'whore', 'slut', 'nigger',
    'nigga', 'faggot', 'retard', 'rape',
    'くそ', 'くそったれ', 'ちくしょう', 'ちんこ', 'ちんぽ', 'まんこ', 'うんこ',
    'きんたま', 'ファック', 'セックス', 'フェラ', '中出し', '死ね', '殺す',
    'しね', 'なかだし', 'ころす',
    'きちがい', '池沼', 'エロ',
    'kuso', 'unko', 'chinko', 'manko', 'ero',
    'くそまずい', 'くそ不味い', 'えろい', 'えろすぎ', 'えろえろ',
    'おまんこ', 'フェラチオ', 'イラマチオ', 'クンニ', 'パイズリ', '顔射',
    'ザーメン', 'オナニー', '素股', '手コキ', '手マン', '肉便器',
    'fellatio', 'cunnilingus'
  ];
  v_phrases text[] := array['cock tail', 'rape seed'];
begin
  if v_spaced = '' then
    return false;
  end if;

  foreach v_phrase in array v_phrases loop
    v_spaced := moderation.strip_phrase(v_spaced, v_phrase);
  end loop;
  v_spaced := pg_catalog.btrim(pg_catalog.regexp_replace(v_spaced, ' +', ' ', 'g'));
  if v_spaced = '' then
    return false;
  end if;
  v_compact := pg_catalog.replace(v_spaced, ' ', '');

  foreach v_term in array v_words loop
    v_norm := pg_catalog.replace(moderation.normalize_food_text(v_term), ' ', '');
    if v_norm = '' then
      continue;
    end if;

    if moderation.term_uses_substring(v_norm) then
      if pg_catalog.strpos(v_compact, v_norm) > 0 then
        return true;
      end if;
    elsif moderation.contains_term(v_spaced, v_norm)
       or moderation.contains_term(v_compact, v_norm) then
      return true;
    elsif v_norm = 'ero' and (
      v_compact = v_norm
      or pg_catalog.left(v_compact, pg_catalog.char_length(v_norm)) = v_norm
    ) then
      -- 末尾の ero は zero / hero / cordero に当たるので見ない。
      return true;
    elsif v_norm in (
      'えろ', 'くそ', 'ふぇら', 'まんこ', 'しね', 'なかだし', 'ころす',
      'kuso', 'unko', 'chinko', 'manko'
    ) and moderation.term_is_affixed(v_compact, v_norm) then
      return true;
    elsif v_norm = 'fuck' and moderation.latin_one_gap(v_spaced, v_norm) then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

create or replace function moderation.reject_banned_public_food_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now_shared boolean;
  v_was_shared boolean;
begin
  v_now_shared :=
    new.visibility in ('public', 'unlisted')
    and new.status = 'active'
    and new.deleted_at is null
    and new.moderation_status in ('none', 'reported', 'under_review');

  if not v_now_shared then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_was_shared := false;
  else
    v_was_shared :=
      old.visibility in ('public', 'unlisted')
      and old.status = 'active'
      and old.deleted_at is null
      and old.moderation_status in ('none', 'reported', 'under_review');
  end if;

  if not v_was_shared then
    if moderation.text_is_banned(new.name)
       or moderation.text_is_banned(new.normalized_name)
       or moderation.text_is_banned(coalesce(new.brand, ''))
       or moderation.text_is_banned(coalesce(new.serving_unit_label, ''))
       or moderation.text_is_banned(coalesce(new.supplementary_weight, ''))
       or moderation.text_is_banned(coalesce(new.barcode, ''))
       or moderation.text_is_banned(coalesce(new.voice_reading, ''))
       or moderation.text_is_banned(coalesce(new.voice_katakana, ''))
       or moderation.text_is_banned(coalesce(new.voice_normalized, '')) then
      raise exception 'moderation banned public food text'
        using errcode = '23514';
    end if;
    return new;
  end if;

  if (new.name is distinct from old.name and moderation.text_is_banned(new.name))
     or (new.normalized_name is distinct from old.normalized_name
         and moderation.text_is_banned(new.normalized_name))
     or (new.brand is distinct from old.brand
         and moderation.text_is_banned(coalesce(new.brand, '')))
     or (new.serving_unit_label is distinct from old.serving_unit_label
         and moderation.text_is_banned(coalesce(new.serving_unit_label, '')))
     or (new.supplementary_weight is distinct from old.supplementary_weight
         and moderation.text_is_banned(coalesce(new.supplementary_weight, '')))
     or (new.barcode is distinct from old.barcode
         and moderation.text_is_banned(coalesce(new.barcode, '')))
     or (new.voice_reading is distinct from old.voice_reading
         and moderation.text_is_banned(coalesce(new.voice_reading, '')))
     or (new.voice_katakana is distinct from old.voice_katakana
         and moderation.text_is_banned(coalesce(new.voice_katakana, '')))
     or (new.voice_normalized is distinct from old.voice_normalized
         and moderation.text_is_banned(coalesce(new.voice_normalized, ''))) then
    raise exception 'moderation banned public food text'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on schema moderation from public, anon, authenticated;
grant usage on schema moderation to anon, authenticated, service_role;

revoke all on function moderation.compose_halfwidth_voiced(text) from public, anon, authenticated;
revoke all on function moderation.normalize_food_text(text) from public, anon, authenticated;
revoke all on function moderation.char_is_word(text) from public, anon, authenticated;
revoke all on function moderation.contains_term(text, text) from public, anon, authenticated;
revoke all on function moderation.strip_phrase(text, text) from public, anon, authenticated;
revoke all on function moderation.term_uses_substring(text) from public, anon, authenticated;
revoke all on function moderation.latin_one_gap(text, text) from public, anon, authenticated;
revoke all on function moderation.term_is_affixed(text, text) from public, anon, authenticated;
revoke all on function moderation.text_is_banned(text) from public, anon, authenticated;
revoke all on function moderation.reject_banned_public_food_text() from public, anon, authenticated;

-- トリガーを動かすには、更新する役割に実行権が要る。中の語リスト関数は渡さない。
grant execute on function moderation.reject_banned_public_food_text()
  to anon, authenticated, service_role;

drop trigger if exists reject_banned_public_food_text on public.saved_foods;
create trigger reject_banned_public_food_text
  before insert or update of
    name,
    normalized_name,
    brand,
    serving_unit_label,
    supplementary_weight,
    barcode,
    voice_reading,
    voice_katakana,
    voice_normalized,
    visibility,
    status,
    deleted_at,
    moderation_status
  on public.saved_foods
  for each row
  when (new.visibility in ('public', 'unlisted'))
  execute function moderation.reject_banned_public_food_text();

comment on function moderation.text_is_banned(text) is
  '公開食品の自由文に禁止語があるか。既存行は更新しない。';
comment on function moderation.reject_banned_public_food_text() is
  '公開または限定公開になる食品と、その自由文の変更を拒否する。非公開と、禁止語を含んだままの既存行の他の列は通す。';
