-- Readings, colloquial aliases, and typo fallback for the food search
-- the app and Siri both use.
--
-- 20261006120000_siri_official_food_search.sql stays as it is: it grants
-- anon execute on search_official_foods and adds とりむね / むね肉 / 胸肉.
-- This migration renames that function to search_official_foods_strict and
-- puts a wrapper back on the original name. Queries that already match
-- keep the strict ranking and skip the typo scan, so existing results and
-- the common path stay the same. Siri sends the same RPC after filler
-- removal. Public foods use search_public_foods, which the in-app public
-- search calls too. It is not a Siri-only entry point.
--
-- Do not apply this file to production from the agent. The operator applies it.

begin;

-- ---------------------------------------------------------------------------
-- Spoken columns
-- ---------------------------------------------------------------------------

alter table public.official_foods
  add column if not exists spoken_name text,
  add column if not exists spoken_reading text,
  add column if not exists spoken_katakana text,
  add column if not exists spoken_normalized text;

comment on column public.official_foods.spoken_name is
  '括弧や状態を除いた口語名。検索の別名にも入る。';
comment on column public.official_foods.spoken_reading is
  'spoken_name を検索キーにしたひらがな。';
comment on column public.official_foods.spoken_katakana is
  'spoken_reading のカタカナ。';
comment on column public.official_foods.spoken_normalized is
  'normalize_food_search_text(spoken_name)。';

alter table public.saved_foods
  add column if not exists voice_reading text,
  add column if not exists voice_katakana text,
  add column if not exists voice_normalized text;

comment on column public.saved_foods.voice_normalized is
  '公開食品の検索キー。保存時に名前から作る。';

create or replace function public.hiragana_to_katakana(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_text, '');
  n integer := pg_catalog.char_length(v);
  i integer;
  ch text;
  cp integer;
  out text := '';
begin
  for i in 1..n loop
    ch := pg_catalog.substr(v, i, 1);
    cp := pg_catalog.ascii(ch);
    if cp between 12353 and 12438 then
      ch := pg_catalog.chr(cp + 96);
    end if;
    out := out || ch;
  end loop;
  return out;
end;
$$;

revoke all on function public.hiragana_to_katakana(text) from public, anon, authenticated;

-- Drop brackets and state words, then join the remaining tokens.
create or replace function public.official_food_spoken_name(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_text, '');
  token text;
  kept text := '';
begin
  v := pg_catalog.regexp_replace(v, '＜[^＞]*＞', ' ', 'g');
  v := pg_catalog.regexp_replace(v, '［[^］]*］', ' ', 'g');
  v := pg_catalog.regexp_replace(v, '（[^）]*）', ' ', 'g');
  v := pg_catalog.regexp_replace(v, '\([^)]*\)', ' ', 'g');
  v := pg_catalog.regexp_replace(v, '[　[:space:]]+', ' ', 'g');
  v := pg_catalog.btrim(v);
  for token in
    select pg_catalog.btrim(part)
    from pg_catalog.regexp_split_to_table(v, ' ') as part
  loop
    if token = '' then
      continue;
    end if;
    if token in (
      '生', 'なま', 'ゆで', '茹で', '焼き', '焼', '乾', '乾燥', '水煮',
      '皮なし', '皮つき', '果実', '葉', '根', '塊茎', '塊根', '普通',
      '生鮮', '缶詰', '通年平均', '副品目', '主品目'
    ) then
      continue;
    end if;
    if pg_catalog.char_length(token) < 2 then
      continue;
    end if;
    kept := kept || token;
  end loop;
  return kept;
end;
$$;

revoke all on function public.official_food_spoken_name(text) from public, anon, authenticated;

create or replace function public.official_foods_fill_spoken()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.spoken_name := public.official_food_spoken_name(
    coalesce(nullif(pg_catalog.btrim(new.display_name), ''), new.name)
  );
  new.spoken_normalized := public.normalize_food_search_text(new.spoken_name);
  new.spoken_reading := new.spoken_normalized;
  new.spoken_katakana := public.hiragana_to_katakana(new.spoken_normalized);
  return new;
end;
$$;

revoke all on function public.official_foods_fill_spoken() from public, anon, authenticated;

drop trigger if exists official_foods_fill_spoken on public.official_foods;
create trigger official_foods_fill_spoken
  before insert or update of name, display_name, reading
  on public.official_foods
  for each row
  execute function public.official_foods_fill_spoken();

update public.official_foods
set display_name = display_name;

create or replace function public.saved_foods_fill_voice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.voice_normalized := public.normalize_food_search_text(new.name);
  new.voice_reading := new.voice_normalized;
  new.voice_katakana := public.hiragana_to_katakana(new.voice_normalized);
  return new;
end;
$$;

revoke all on function public.saved_foods_fill_voice() from public, anon, authenticated;
grant execute on function public.saved_foods_fill_voice() to authenticated;

drop trigger if exists saved_foods_fill_voice on public.saved_foods;
create trigger saved_foods_fill_voice
  before insert or update of name
  on public.saved_foods
  for each row
  execute function public.saved_foods_fill_voice();

update public.saved_foods
set name = name
where voice_normalized is null;

-- ---------------------------------------------------------------------------
-- Aliases: manual dictionary, then colloquial names from the official label
-- ---------------------------------------------------------------------------

insert into public.official_food_aliases (
  food_code, alias, reading, normalized, is_candidate, candidate_rank,
  note, source, is_group, priority
)
select
  spoken.food_code,
  spoken.alias,
  spoken.reading,
  public.normalize_food_search_text(spoken.alias),
  spoken.is_candidate,
  spoken.candidate_rank,
  spoken.note,
  spoken.source,
  false,
  case when spoken.is_candidate then 40 else 10 end
from (
  values
  ('01088', 'ごはん', 'ごはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', 'ご飯', 'ごはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '白ご飯', 'しろごはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '白ごはん', 'しろごはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '白米', 'はくまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', 'ライス', 'らいす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', 'めし', 'めし', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '飯', 'めし', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '米飯', 'べいはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01088', '精白米', 'せいはくまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01085', '玄米', 'げんまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01085', '玄米ご飯', 'げんまいごはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01155', '発芽玄米', 'はつがげんまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01154', 'もち米', 'もちごめ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01154', 'おこわ', 'おこわ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01089', '雑穀米', 'ざっこくまい', true, 1, '近似（はいが精米）。単一の食品には決めない。要確認', 'karonavi_spoken_seed_v1'),
  ('01089', '胚芽米', 'はいがまい', false, null, 'はいが精米', 'karonavi_spoken_seed_v1'),
  ('01111', 'おにぎり', 'おにぎり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01111', 'おむすび', 'おむすび', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01112', '焼きおにぎり', 'やきおにぎり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18057', 'チャーハン', 'ちゃーはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18057', '炒飯', 'ちゃーはん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18057', '焼き飯', 'やきめし', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01026', 'パン', 'ぱん', false, null, '食パンを代表値に', 'karonavi_spoken_seed_v1'),
  ('01026', '食パン', 'しょくぱん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01026', 'トースト', 'とーすと', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01034', 'ロールパン', 'ろーるぱん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01034', 'バターロール', 'ばたーろーる', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01209', 'クロワッサン', 'くろわっさん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01039', 'うどん', 'うどん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01039', '饂飩', 'うどん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01039', 'ゆでうどん', 'ゆでうどん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01128', 'そば', 'そば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01128', '蕎麦', 'そば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01128', '日本そば', 'にほんそば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01048', 'ラーメン', 'らーめん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01048', 'らーめん', 'らーめん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01048', '中華そば', 'ちゅうかそば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01048', '中華麺', 'ちゅうかめん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01198', 'インスタントラーメン', 'いんすたんとらーめん', false, null, '調理後全体（添付調味料含む）', 'karonavi_spoken_seed_v1'),
  ('01198', 'カップ麺', 'かっぷめん', true, 2, '袋麺の調理後全体。カップめんと並べて候補にする。要確認', 'karonavi_spoken_seed_v1'),
  ('01198', '即席麺', 'そくせきめん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01064', 'パスタ', 'ぱすた', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01064', 'スパゲッティ', 'すぱげってぃ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01064', 'スパゲティ', 'すぱげてぃ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01064', 'マカロニ', 'まかろに', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01004', 'オートミール', 'おーとみーる', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('01137', 'コーンフレーク', 'こーんふれーく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', '卵', 'たまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', 'たまご', 'たまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', '玉子', 'たまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', 'タマゴ', 'たまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', '生卵', 'なまたまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12004', '鶏卵', 'けいらん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12005', 'ゆで卵', 'ゆでたまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12005', 'ゆでたまご', 'ゆでたまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('12005', '茹で卵', 'ゆでたまご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11220', '鶏むね', 'とりむね', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11220', '鶏胸肉', 'とりむねにく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11220', '鶏むね肉', 'とりむねにく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11220', 'むね肉', 'むねにく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11220', 'サラダチキン', 'さらだちきん', true, 1, '市販品は味付けあり。生むね肉は候補の一つ。要確認', 'karonavi_spoken_seed_v1'),
  ('11227', 'ささみ', 'ささみ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11227', 'ササミ', 'ささみ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11230', '鶏ひき肉', 'とりひきにく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18054', '唐揚げ', 'からあげ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18054', 'から揚げ', 'からあげ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18054', 'からあげ', 'からあげ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11123', '豚ロース', 'ぶたろーす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11129', '豚バラ', 'ぶたばら', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11129', '豚ばら肉', 'ぶたばらにく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11074', '牛バラ', 'ぎゅうばら', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11176', 'ハム', 'はむ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11176', 'ロースハム', 'ろーすはむ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11183', 'ベーコン', 'べーこん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11186', 'ウインナー', 'ういんなー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11186', 'ウィンナー', 'うぃんなー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('11186', 'ソーセージ', 'そーせーじ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10134', '鮭', 'さけ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10134', 'さけ', 'さけ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10134', 'サーモン', 'さーもん', true, 2, 'しろさけ。たいせいようさけ（養殖）と並べて候補にする。要確認', 'karonavi_spoken_seed_v1'),
  ('10134', 'しゃけ', 'しゃけ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10253', 'まぐろ', 'まぐろ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10253', 'マグロ', 'まぐろ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10253', '鮪', 'まぐろ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10154', 'さば', 'さば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10154', 'サバ', 'さば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10154', '鯖', 'さば', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10003', 'あじ', 'あじ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10003', '鯵', 'あじ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10241', 'ぶり', 'ぶり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('10241', '鰤', 'ぶり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('13003', '牛乳', 'ぎゅうにゅう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('13003', 'ミルク', 'みるく', false, null, '普通牛乳', 'karonavi_spoken_seed_v1'),
  ('13025', 'ヨーグルト', 'よーぐると', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('13025', 'プレーンヨーグルト', 'ぷれーんよーぐると', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('13040', 'チーズ', 'ちーず', false, null, 'プロセスチーズを代表値に', 'karonavi_spoken_seed_v1'),
  ('13040', 'プロセスチーズ', 'ぷろせすちーず', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('14017', 'バター', 'ばたー', false, null, '有塩バター', 'karonavi_spoken_seed_v1'),
  ('04046', '納豆', 'なっとう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04046', 'なっとう', 'なっとう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04032', '豆腐', 'とうふ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04032', 'とうふ', 'とうふ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04032', '木綿豆腐', 'もめんどうふ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04033', '絹豆腐', 'きぬどうふ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04033', '絹ごし豆腐', 'きぬごしどうふ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04040', '油揚げ', 'あぶらあげ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('04052', '豆乳', 'とうにゅう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17045', '味噌', 'みそ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17045', 'みそ', 'みそ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17007', '醤油', 'しょうゆ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17007', 'しょうゆ', 'しょうゆ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17012', '塩', 'しお', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('03003', '砂糖', 'さとう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17042', 'マヨネーズ', 'まよねーず', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('17042', 'マヨ', 'まよ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('14001', 'オリーブオイル', 'おりーぶおいる', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06061', 'キャベツ', 'きゃべつ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06312', 'レタス', 'れたす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06182', 'トマト', 'とまと', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06065', 'きゅうり', 'きゅうり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06065', '胡瓜', 'きゅうり', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06153', '玉ねぎ', 'たまねぎ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06153', 'たまねぎ', 'たまねぎ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06153', 'タマネギ', 'たまねぎ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06214', '人参', 'にんじん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06214', 'にんじん', 'にんじん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06214', 'ニンジン', 'にんじん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('02017', 'じゃがいも', 'じゃがいも', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('02017', 'ジャガイモ', 'じゃがいも', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('02017', '馬鈴薯', 'ばれいしょ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('02006', 'さつまいも', 'さつまいも', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('02006', 'サツマイモ', 'さつまいも', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06267', 'ほうれん草', 'ほうれんそう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06263', 'ブロッコリー', 'ぶろっこりー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06291', 'もやし', 'もやし', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06134', '大根', 'だいこん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06191', 'なす', 'なす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06191', '茄子', 'なす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06048', 'かぼちゃ', 'かぼちゃ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06048', '南瓜', 'かぼちゃ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06226', '長ねぎ', 'ながねぎ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('06226', 'ねぎ', 'ねぎ', false, null, '根深ねぎ（白ねぎ）', 'karonavi_spoken_seed_v1'),
  ('08016', 'しめじ', 'しめじ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('08028', 'まいたけ', 'まいたけ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07107', 'バナナ', 'ばなな', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07148', 'りんご', 'りんご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07148', 'リンゴ', 'りんご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07148', '林檎', 'りんご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07027', 'みかん', 'みかん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07027', 'ミカン', 'みかん', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07012', 'いちご', 'いちご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07012', '苺', 'いちご', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07116', 'ぶどう', 'ぶどう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07116', '葡萄', 'ぶどう', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07054', 'キウイ', 'きうい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('07006', 'アボカド', 'あぼかど', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18002', '餃子', 'ぎょうざ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18002', 'ぎょうざ', 'ぎょうざ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18002', 'ギョーザ', 'ぎょーざ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18012', '焼売', 'しゅうまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18012', 'シュウマイ', 'しゅうまい', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18018', 'コロッケ', 'ころっけ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18050', 'ハンバーグ', 'はんばーぐ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18001', 'カレー', 'かれー', true, 1, 'ルウ部分のみ。ごはんは別候補。要確認', 'karonavi_spoken_seed_v1'),
  ('18001', 'カレーライスのルー', 'かれーらいすのるー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18001', 'ビーフカレー', 'びーふかれー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18040', 'チキンカレー', 'ちきんかれー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18041', 'ポークカレー', 'ぽーくかれー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18053', 'お好み焼き', 'おこのみやき', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18031', '牛丼の具', 'ぎゅうどんのぐ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('18031', '牛丼', 'ぎゅうどん', true, 1, '牛丼そのものは未収載。牛飯の具。ごはんは別候補。要確認', 'karonavi_spoken_seed_v1'),
  ('15103', 'ポテチ', 'ぽてち', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('15103', 'ポテトチップス', 'ぽてとちっぷす', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('15023', '大福', 'だいふく', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('16006', 'ビール', 'びーる', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('16001', '日本酒', 'にほんしゅ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('16045', 'コーヒー', 'こーひー', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('16037', '緑茶', 'りょくちゃ', false, null, '口語・別名', 'karonavi_spoken_seed_v1'),
  ('16037', 'お茶', 'おちゃ', false, null, 'せん茶浸出液を代表値に', 'karonavi_spoken_seed_v1'),
  ('01085', '雑穀米', 'ざっこくまい', true, 2, '近似（玄米）。単一の食品には決めない。要確認', 'karonavi_spoken_seed_v1'),
  ('01200', 'カップ麺', 'かっぷめん', true, 1, 'カップめんの調理後全体。袋麺と並べて候補にする。要確認', 'karonavi_spoken_seed_v1'),
  ('11288', 'サラダチキン', 'さらだちきん', true, 2, '加熱したむね肉。味付けの市販品は未収載。要確認', 'karonavi_spoken_seed_v1'),
  ('10144', 'サーモン', 'さーもん', true, 1, 'たいせいようさけ（養殖）。しろさけと候補を並べる。要確認', 'karonavi_spoken_seed_v1'),
  ('01088', '牛丼', 'ぎゅうどん', true, 2, 'ごはん分。牛丼そのものは未収載。要確認', 'karonavi_spoken_seed_v1'),
  ('01088', 'カレー', 'かれー', true, 2, 'ごはん分。ルウとごはんを別々の候補にする。要確認', 'karonavi_spoken_seed_v1'),
  ('11227', '鶏ささみ', 'とりささみ', false, null, '口語。生のささみを代表にする', 'spoken_manual_v1'),
  ('11227', 'とりささみ', 'とりささみ', false, null, '口語。生のささみを代表にする', 'spoken_manual_v1'),
  ('11227', 'さささみ', 'さささみ', false, null, '言い間違い。生のささみを代表にする', 'spoken_manual_v1'),
  ('01088', '白飯', 'しろめし', false, null, '口語。炊飯した精白米', 'spoken_manual_v1'),
  ('01088', '白いご飯', 'しろいごはん', false, null, '口語。炊飯した精白米', 'spoken_manual_v1'),
  ('01088', 'ごっはん', 'ごっはん', false, null, '言い間違い。炊飯した精白米', 'spoken_manual_v1'),
  ('11220', 'サラチキ', 'さらちき', true, 1, 'サラダチキンの略。生のむね肉を候補にする', 'spoken_manual_v1'),
  ('11288', 'サラチキ', 'さらちき', true, 2, 'サラダチキンの略。焼いたむね肉を候補にする', 'spoken_manual_v1'),
  ('11227', 'さざみ', 'さざみ', false, null, '誤認識。生のささみを代表にする', 'spoken_manual_v1'),
  ('11227', 'ささみい', 'ささみい', false, null, '言い間違い。生のささみを代表にする', 'spoken_manual_v1'),
  ('12004', 'たまこ', 'たまこ', false, null, '言い間違い。生卵を代表にする', 'spoken_manual_v1'),
  ('07107', 'ばななな', 'ばななな', false, null, '言い間違い', 'spoken_manual_v1'),
  ('13003', 'ぎゅうにゅ', 'ぎゅうにゅ', false, null, '言い間違い。普通牛乳', 'spoken_manual_v1'),
  ('04046', 'なっと', 'なっと', false, null, '言い間違い。糸引き納豆', 'spoken_manual_v1'),
  ('01088', 'ごはんん', 'ごはんん', false, null, '言い間違い。炊飯した精白米', 'spoken_manual_v1')
) as spoken(food_code, alias, reading, is_candidate, candidate_rank, note, source)
where exists (
  select 1
  from public.official_foods as food
  where food.food_code = spoken.food_code
)
on conflict (food_code, normalized) do nothing;

insert into public.official_food_aliases (
  food_code, alias, reading, normalized, is_candidate, candidate_rank,
  note, source, is_group, priority
)
select
  food.food_code,
  food.spoken_name,
  food.spoken_reading,
  food.spoken_normalized,
  true,
  900,
  '正式名から作った口語名',
  'spoken_generated_v1',
  false,
  180
from public.official_foods as food
where food.spoken_normalized is not null
  and pg_catalog.char_length(food.spoken_normalized) >= 3
on conflict (food_code, normalized) do nothing;

insert into public.official_food_aliases (
  food_code, alias, reading, normalized, is_candidate, candidate_rank,
  note, source, is_group, priority
)
select
  food.food_code,
  match.kana,
  public.normalize_food_search_text(match.kana),
  public.normalize_food_search_text(match.kana),
  true,
  800,
  '正式名から取り出した読み',
  'spoken_generated_v1',
  false,
  160
from public.official_foods as food
cross join lateral (
  select (pg_catalog.regexp_matches(
    coalesce(food.spoken_name, ''),
    '[ぁ-ゖァ-ヺー]{3,}',
    'g'
  ))[1] as kana
) as match
where pg_catalog.char_length(public.normalize_food_search_text(match.kana)) >= 3
on conflict (food_code, normalized) do nothing;

-- ---------------------------------------------------------------------------
-- Typo distance. Used only when the strict search returns nothing.
-- ---------------------------------------------------------------------------

create or replace function public.food_search_edit_distance(p_left text, p_right text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  left_text text := coalesce(p_left, '');
  right_text text := coalesce(p_right, '');
  left_len integer := pg_catalog.char_length(left_text);
  right_len integer := pg_catalog.char_length(right_text);
  prev integer[];
  curr integer[];
  i integer;
  j integer;
  cost integer;
  del integer;
  ins integer;
  rep integer;
begin
  if left_len > 16
     or right_len > 16
     or pg_catalog.abs(left_len - right_len) > 2 then
    return 99;
  end if;
  prev := pg_catalog.array_fill(0, array[right_len + 1]);
  for j in 0..right_len loop
    prev[j + 1] := j;
  end loop;
  for i in 1..left_len loop
    curr := pg_catalog.array_fill(0, array[right_len + 1]);
    curr[1] := i;
    for j in 1..right_len loop
      if pg_catalog.substr(left_text, i, 1) = pg_catalog.substr(right_text, j, 1) then
        cost := 0;
      else
        cost := 1;
      end if;
      del := prev[j + 1] + 1;
      ins := curr[j] + 1;
      rep := prev[j] + cost;
      curr[j + 1] := pg_catalog.least(del, ins, rep);
    end loop;
    prev := curr;
  end loop;
  return prev[right_len + 1];
end;
$$;

revoke all on function public.food_search_edit_distance(text, text)
  from public, anon, authenticated;

create or replace function public.search_official_foods_fuzzy(
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
security definer
set search_path = ''
as $$
declare
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_query text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_limit integer := pg_catalog.least(pg_catalog.greatest(coalesce(p_limit, 30), 0), 100);
begin
  if pg_catalog.char_length(v_query) < 3
     or pg_catalog.char_length(v_query) > 16
     or v_limit = 0 then
    return;
  end if;

  return query
  with scored as (
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
      false as is_candidate,
      public.food_search_edit_distance(f.normalized_name, v_query) as edit_distance
    from public.official_foods f
    where pg_catalog.char_length(f.normalized_name)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(f.normalized_name, v_query) between 1 and 2
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
      null::text,
      null::text,
      false,
      public.food_search_edit_distance(f.spoken_normalized, v_query)
    from public.official_foods f
    where f.spoken_normalized is not null
      and pg_catalog.char_length(f.spoken_normalized)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(f.spoken_normalized, v_query) between 1 and 2
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
      true,
      public.food_search_edit_distance(a.normalized, v_query)
    from public.official_food_aliases a
    join public.official_foods f on f.food_code = a.food_code
    where pg_catalog.char_length(a.normalized)
          between pg_catalog.char_length(v_query) - 2
              and pg_catalog.char_length(v_query) + 2
      and public.food_search_edit_distance(a.normalized, v_query) between 1 and 2
  ),
  best as (
    select distinct on (scored.food_code)
      scored.*
    from scored
    order by scored.food_code, scored.edit_distance, scored.matched_alias
  ),
  close as (
    select best.*
    from best
    where best.edit_distance = 1
       or (
         best.edit_distance = 2
         and pg_catalog.char_length(v_query) >= 5
         and not exists (
           select 1 from best as nearer where nearer.edit_distance = 1
         )
       )
  )
  select
    close.food_code,
    close.food_group,
    close.index_no,
    close.name,
    close.display_name,
    close.reading,
    close.base_amount,
    close.unit_type,
    close.refuse_pct,
    close.kcal,
    close.protein_g,
    close.fat_g,
    close.carb_g,
    close.fiber_g,
    close.salt_eq_g,
    close.matched_alias,
    close.matched_alias_reading,
    3,
    true,
    close.edit_distance
  from close
  order by close.edit_distance, close.food_code
  limit v_limit;
end;
$$;

revoke all on function public.search_official_foods_fuzzy(text, integer)
  from public, anon, authenticated;

-- Keep the existing strict body, including its anon grant, under a new name.
alter function public.search_official_foods(text, integer)
  rename to search_official_foods_strict;

revoke all on function public.search_official_foods_strict(text, integer)
  from public, anon, authenticated;

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
security definer
set search_path = ''
as $$
begin
  return query
  select *
  from public.search_official_foods_strict(p_query, p_limit);
  if found then
    return;
  end if;
  return query
  select *
  from public.search_official_foods_fuzzy(p_query, p_limit);
end;
$$;

revoke all on function public.search_official_foods(text, integer)
  from public, anon, authenticated;
grant execute on function public.search_official_foods(text, integer) to anon;
grant execute on function public.search_official_foods(text, integer) to authenticated;

comment on function public.search_official_foods(text, integer) is
  'In-app and Siri food-composition search. Strict matches keep the previous order. Typos run only when nothing matched.';

-- ---------------------------------------------------------------------------
-- Public foods. Same tiers. Blocked creators stay out.
-- ---------------------------------------------------------------------------

create or replace function public.search_public_foods(
  p_query text,
  p_limit integer default 50
)
returns table (
  user_id uuid,
  food_id text,
  visibility text,
  status text,
  moderation_status text,
  name text,
  normalized_name text,
  base_amount numeric,
  unit_type text,
  serving_unit_label text,
  kcal_per_base double precision,
  protein_per_base double precision,
  fat_per_base double precision,
  carb_per_base double precision,
  source_type text,
  barcode text,
  brand text,
  supplementary_weight text,
  official_food_code text,
  official_food_name text,
  source_attribution text,
  copied_from_food_id text,
  copied_from_owner_user_id uuid,
  use_count integer,
  last_used_at timestamptz,
  report_count integer,
  version integer,
  created_at timestamptz,
  updated_at timestamptz,
  deleted_at timestamptz,
  match_rank integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_raw text := pg_catalog.left(coalesce(p_query, ''), 64);
  v_name text := pg_catalog.lower(
    pg_catalog.regexp_replace(pg_catalog.btrim(v_raw), '[[:space:]]+', ' ', 'g')
  );
  v_voice text := pg_catalog.left(public.normalize_food_search_text(v_raw), 64);
  v_barcode text := pg_catalog.btrim(v_raw);
  v_limit integer := pg_catalog.least(pg_catalog.greatest(coalesce(p_limit, 50), 0), 100);
  v_pattern text;
  v_prefix text;
  v_voice_pattern text;
  v_voice_prefix text;
begin
  if auth.uid() is null or v_limit = 0 then
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
      sf.user_id,
      sf.food_id,
      sf.visibility,
      sf.status,
      sf.moderation_status,
      sf.name,
      sf.normalized_name,
      sf.base_amount,
      sf.unit_type,
      sf.serving_unit_label,
      sf.kcal_per_base,
      sf.protein_per_base,
      sf.fat_per_base,
      sf.carb_per_base,
      sf.source_type,
      sf.barcode,
      sf.brand,
      sf.supplementary_weight,
      sf.official_food_code,
      sf.official_food_name,
      sf.source_attribution,
      sf.copied_from_food_id,
      sf.copied_from_owner_user_id,
      sf.use_count,
      sf.last_used_at,
      sf.report_count,
      sf.version,
      sf.created_at,
      sf.updated_at,
      sf.deleted_at,
      case
        when sf.normalized_name = %L or sf.barcode = %L then 0
        when sf.normalized_name ilike %L escape '\' then 1
        else 2
      end as match_rank
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and public.is_saved_food_visible_to_viewer(sf.user_id)
      and (
        sf.normalized_name = %L
        or sf.normalized_name ilike %L escape '\'
        or (%L <> '' and sf.barcode = %L)
      )
    order by 31, sf.updated_at desc nulls last, sf.food_id
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
      sf.user_id, sf.food_id, sf.visibility, sf.status, sf.moderation_status,
      sf.name, sf.normalized_name, sf.base_amount, sf.unit_type,
      sf.serving_unit_label, sf.kcal_per_base, sf.protein_per_base,
      sf.fat_per_base, sf.carb_per_base, sf.source_type, sf.barcode,
      sf.brand, sf.supplementary_weight, sf.official_food_code,
      sf.official_food_name, sf.source_attribution, sf.copied_from_food_id,
      sf.copied_from_owner_user_id, sf.use_count, sf.last_used_at,
      sf.report_count, sf.version, sf.created_at, sf.updated_at, sf.deleted_at,
      case
        when sf.voice_normalized = %L then 0
        when sf.voice_normalized like %L escape '\' then 1
        else 2
      end
    from public.saved_foods sf
    where public.is_saved_food_publicly_visible(
            sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
          )
      and public.is_saved_food_visible_to_viewer(sf.user_id)
      and sf.voice_normalized like %L escape '\'
    order by 31, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
    limit %s
    $sql$,
    v_voice, v_voice_prefix, v_voice_pattern, v_limit
  );
  if found then
    return;
  end if;

  if pg_catalog.char_length(v_voice) < 3 or pg_catalog.char_length(v_voice) > 16 then
    return;
  end if;

  return query
  select
    sf.user_id, sf.food_id, sf.visibility, sf.status, sf.moderation_status,
    sf.name, sf.normalized_name, sf.base_amount, sf.unit_type,
    sf.serving_unit_label, sf.kcal_per_base, sf.protein_per_base,
    sf.fat_per_base, sf.carb_per_base, sf.source_type, sf.barcode,
    sf.brand, sf.supplementary_weight, sf.official_food_code,
    sf.official_food_name, sf.source_attribution, sf.copied_from_food_id,
    sf.copied_from_owner_user_id, sf.use_count, sf.last_used_at,
    sf.report_count, sf.version, sf.created_at, sf.updated_at, sf.deleted_at,
    2 + public.food_search_edit_distance(sf.voice_normalized, v_voice)
  from public.saved_foods sf
  where public.is_saved_food_publicly_visible(
          sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
        )
    and public.is_saved_food_visible_to_viewer(sf.user_id)
    and sf.voice_normalized is not null
    and pg_catalog.char_length(sf.voice_normalized)
        between pg_catalog.char_length(v_voice) - 2
            and pg_catalog.char_length(v_voice) + 2
    and public.food_search_edit_distance(sf.voice_normalized, v_voice) = 1
  order by 31, sf.use_count desc, sf.updated_at desc nulls last, sf.food_id
  limit v_limit;
end;
$$;

revoke all on function public.search_public_foods(text, integer)
  from public, anon, authenticated;
grant execute on function public.search_public_foods(text, integer) to authenticated;

comment on function public.search_public_foods(text, integer) is
  'In-app and Siri public-food search. Name matches keep the previous set. Readings and typos run only when the name did not match. Blocked creators are excluded.';

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
    raise exception 'gin_trgm_ops is missing';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'official_foods_spoken_normalized_trgm_idx'
  ) then
    execute format(
      'create index official_foods_spoken_normalized_trgm_idx on public.official_foods using gin (spoken_normalized %I.gin_trgm_ops)',
      opschema
    );
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'saved_foods_voice_normalized_trgm_idx'
  ) then
    execute format(
      'create index saved_foods_voice_normalized_trgm_idx on public.saved_foods using gin (voice_normalized %I.gin_trgm_ops) where visibility = ''public'' and status = ''active'' and deleted_at is null',
      opschema
    );
  end if;
end
$$;

commit;
