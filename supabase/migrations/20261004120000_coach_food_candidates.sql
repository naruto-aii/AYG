-- 今日のコーチが食事案に使う食品。
-- 画面の名前と提案単位だけを入れる。kcal と PFC は official_foods を読む。
-- official_foods の行も数値も変えない。
-- 候補表が空の環境でも流せるよう、official_foods への外部キーは付けない。

begin;

create table if not exists public.coach_food_candidates (
  food_code text primary key check (food_code ~ '^[0-9]{5}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  unit_label text not null check (char_length(unit_label) between 1 and 20),
  unit_grams integer not null check (unit_grams > 0),
  contents_note text check (
    contents_note is null or char_length(contents_note) between 1 and 40
  ),
  sort_order integer not null check (sort_order > 0),
  unique (sort_order)
);

comment on table public.coach_food_candidates is
  '今日のコーチの食事候補。画面の名前と提案単位。栄養値は official_foods を参照し、この表には写さない。';
comment on column public.coach_food_candidates.display_name is
  '画面に出す名前。成分表の正式名称ではない。';
comment on column public.coach_food_candidates.unit_label is
  '提案単位の呼び方。茶わん1杯、1個、100g。';
comment on column public.coach_food_candidates.unit_grams is
  '提案単位のグラム。案の量はこの倍数だけ。';
comment on column public.coach_food_candidates.contents_note is
  '具なしおにぎりが米だけであることなど、画面に添える短い注記。';

alter table public.coach_food_candidates enable row level security;

drop policy if exists coach_food_candidates_select_authenticated
  on public.coach_food_candidates;
create policy coach_food_candidates_select_authenticated
  on public.coach_food_candidates
  for select
  to authenticated
  using (true);

revoke all on table public.coach_food_candidates from public, anon, authenticated;
grant select on table public.coach_food_candidates to authenticated;

insert into public.coach_food_candidates (
  food_code, display_name, unit_label, unit_grams, contents_note, sort_order
) values
  ('01088', '白米（めし）', '茶わん1杯', 150, null, 1),
  ('01085', '玄米（めし）', '茶わん1杯', 150, null, 2),
  ('01111', '具なしおにぎり', '1個', 100, '中身は米だけ', 3),
  ('01004', 'オートミール', '30g', 30, null, 4),
  ('01026', '食パン（6枚切り）', '1枚', 60, null, 5),
  ('01039', 'うどん（ゆで）', '1玉', 250, null, 6),
  ('01128', 'そば（ゆで）', '1人前', 200, null, 7),
  ('01044', 'そうめん（ゆで）', '1人前', 200, null, 8),
  ('01048', '中華めん（ゆで）', '1玉', 200, null, 9),
  ('01064', 'スパゲッティ（ゆで）', '1人前', 200, null, 10),
  ('02008', 'さつまいも（焼き）', '中1本', 150, null, 11),
  ('02018', 'じゃがいも（蒸し）', '中1個', 150, null, 12),
  ('12005', 'ゆで卵', '1個', 50, null, 13),
  ('04032', '木綿豆腐', '半丁', 150, null, 14),
  ('04033', '絹ごし豆腐', '半丁', 150, null, 15),
  ('04046', '納豆', '1パック', 50, null, 16),
  ('11288', '鶏むね（皮なし・焼き）', '100g', 100, null, 17),
  ('11225', '鶏もも（皮なし・焼き）', '100g', 100, null, 18),
  ('11229', '鶏ささみ（ゆで）', '100g', 100, null, 19),
  ('11132', '豚もも（脂なし・焼き）', '100g', 100, null, 20),
  ('11278', '豚ヒレ（赤肉・焼き）', '100g', 100, null, 21),
  ('11270', '牛もも（脂なし・焼き）', '100g', 100, null, 22),
  ('11291', '鶏ひき肉（焼き）', '100g', 100, null, 23),
  ('10260', 'ツナ水煮（ライト）', '1罐', 70, null, 24),
  ('10136', 'さけ（焼き）', '100g', 100, null, 25),
  ('10206', 'たら（焼き）', '100g', 100, null, 26),
  ('10005', 'あじ（焼き）', '100g', 100, null, 27),
  ('04053', '調製豆乳', 'コップ1杯', 200, null, 28),
  ('13003', '牛乳', 'コップ1杯', 200, null, 29),
  ('13005', '低脂肪牛乳', 'コップ1杯', 200, null, 30),
  ('13025', 'ヨーグルト（無糖）', '100g', 100, null, 31),
  ('13053', 'ヨーグルト（低脂肪・無糖）', '100g', 100, null, 32),
  ('13040', 'プロセスチーズ', '1切れ', 20, null, 33),
  ('13033', 'カテージチーズ', '100g', 100, null, 34)
on conflict (food_code) do update set
  display_name = excluded.display_name,
  unit_label = excluded.unit_label,
  unit_grams = excluded.unit_grams,
  contents_note = excluded.contents_note,
  sort_order = excluded.sort_order;

commit;
