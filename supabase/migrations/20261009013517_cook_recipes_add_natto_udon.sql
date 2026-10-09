-- 自炊コーチに家庭料理7品（納豆・うどん）を足して107品にする。
-- 変えるのはレシピ表 cook_recipes / cook_recipe_options だけ。ユーザーの行には触れない。
-- 内容は supabase/seed/cook_recipes.sql（recipes.ts から emit_recipes_sql.ts で生成）の追加分と同じ。
-- 何度流しても同じ結果になるよう、既にある id は飛ばす。

do $$
declare
  present integer;
begin
  select count(*) into present
  from public.official_foods
  where food_code in ('01039', '01064', '04032', '04046', '06061', '06086', '06134', '06153', '06214', '06226', '06233', '06245', '06264', '06267', '06291', '08017', '10381', '11115', '11183', '11220', '12004', '14006', '16025', '17007', '17028', '17045', '17063');
  if present < 27 then
    raise exception 'cook recipes 107: official_foods has % of 27 codes', present;
  end if;

  if exists (select 1 from public.cook_recipes where id in ('kakitama-udon', 'natto-ae', 'natto-fry', 'natto-jiru', 'natto-omelette', 'natto-pasta', 'yaki-udon')) then
    raise notice 'cook recipes 107: already applied';
    return;
  end if;

  insert into public.cook_recipes
    (id, name_template, genre, category, method, minutes, steps)
  values
    ('natto-omelette', '納豆オムレツ', '和', '主菜', '焼', 5, '["卵を溶き、納豆としょうゆ{g:soy}gとこしょう{g:pepper}gを混ぜる。","フライパンを中火にし、{oil}{g:oil}gを熱する。","卵液を流し入れて2分焼く。","半分に折って3分火を通し、器に盛る。"]'::jsonb),
    ('natto-jiru', '納豆と{veg}の味噌汁', '和', '汁物', '煮', 7, '["{veg}を食べやすく切る。","鍋に水を300mlと顆粒だし{g:dashi}gを入れて4分煮立たせる。","{veg}と納豆を入れて3分煮る。","味噌{g:miso}gを溶き入れて火を止める。"]'::jsonb),
    ('natto-ae', '{veg}の納豆和え', '和', '副菜', '和え', 5, '["{veg}を食べやすく切る。","鍋に湯を沸かし、{veg}を2分ゆでて水気をしぼる。","納豆としょうゆ{g:soy}gで和える。","3分置いて味をなじませ、器に盛る。"]'::jsonb),
    ('natto-fry', '{veg}と納豆の炒め', '和', '主菜', '炒', 5, '["{veg}を食べやすく切る。","フライパンを中火にし、{oil}{g:oil}gで{veg}を3分炒める。","納豆を加えて2分炒め、しょうゆ{g:soy}gとみりん{g:mirin}gで味をつける。","火を止めて器に盛る。"]'::jsonb),
    ('natto-pasta', '納豆と{veg}の和風パスタ', '和', '丼麺', '炒', 11, '["鍋に湯を沸かし、スパゲティ{g:rice}gを8分ゆでる。","{veg}を食べやすく切る。","フライパンを中火にし、{oil}{g:oil}gで{veg}を2分炒め、パスタと納豆としょうゆ{g:soy}gとこしょう{g:pepper}gを加えて1分絡める。","器に盛る。"]'::jsonb),
    ('kakitama-udon', '{veg}のかき玉うどん', '和', '丼麺', '煮', 7, '["{veg}を切り、卵を溶く。","鍋に水を350mlと顆粒だし{g:dashi}gを入れて煮立たせ、{veg}を3分煮る。","うどんとしょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分煮る。","溶き卵を回し入れて1分火を通す。"]'::jsonb),
    ('yaki-udon', '{protein}と{veg}の焼きうどん', '和', '丼麺', '炒', 7, '["{protein}と{veg}を食べやすく切る。","フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分炒める。","{veg}を加えて2分炒め、うどんを入れて2分炒める。","しょうゆ{g:soy}gとみりん{g:mirin}gを絡めて器に盛る。"]'::jsonb);

  insert into public.cook_recipe_options
    (recipe_id, slot_key, role, label, food_code, base_grams, sort_order, match_names, staple)
  values
    ('natto-omelette', 'protein', 'protein', '納豆', '04046', 50, 0, array['納豆']::text[], false),
    ('natto-omelette', 'egg', 'egg', '卵', '12004', 50, 100, array['卵','たまご','玉子']::text[], false),
    ('natto-omelette', 'oil', 'oil', 'サラダ油', '14006', 5, 200, array['サラダ油','油']::text[], true),
    ('natto-omelette', 'soy', 'seasoning', 'しょうゆ', '17007', 4, 300, array['しょうゆ','醤油']::text[], true),
    ('natto-omelette', 'pepper', 'seasoning', 'こしょう', '17063', 1, 400, array['こしょう','胡椒','コショウ']::text[], true),
    ('natto-jiru', 'protein', 'protein', '納豆', '04046', 40, 0, array['納豆']::text[], false),
    ('natto-jiru', 'veg', 'veg', 'ねぎ', '06226', 30, 100, array['ねぎ','長ねぎ','ネギ']::text[], false),
    ('natto-jiru', 'veg', 'protein', '木綿豆腐', '04032', 60, 101, array['木綿豆腐','豆腐']::text[], false),
    ('natto-jiru', 'veg', 'veg', '大根', '06134', 50, 102, array['大根','だいこん']::text[], false),
    ('natto-jiru', 'veg', 'veg', '白菜', '06233', 50, 103, array['白菜','はくさい']::text[], false),
    ('natto-jiru', 'veg', 'veg', '小松菜', '06086', 40, 104, array['小松菜','こまつな']::text[], false),
    ('natto-jiru', 'veg', 'veg', 'しめじ', '08017', 40, 105, array['しめじ']::text[], false),
    ('natto-jiru', 'dashi', 'seasoning', '顆粒だし', '17028', 3, 200, array['顆粒だし','だし','和風だし']::text[], true),
    ('natto-jiru', 'miso', 'seasoning', '味噌', '17045', 12, 300, array['味噌','みそ']::text[], true),
    ('natto-ae', 'veg', 'veg', 'ほうれん草', '06267', 70, 0, array['ほうれん草','ほうれんそう']::text[], false),
    ('natto-ae', 'veg', 'veg', '小松菜', '06086', 70, 1, array['小松菜','こまつな']::text[], false),
    ('natto-ae', 'veg', 'veg', 'ブロッコリー', '06264', 70, 2, array['ブロッコリー']::text[], false),
    ('natto-ae', 'veg', 'veg', 'キャベツ', '06061', 70, 3, array['キャベツ']::text[], false),
    ('natto-ae', 'protein', 'protein', '納豆', '04046', 40, 100, array['納豆']::text[], false),
    ('natto-ae', 'soy', 'seasoning', 'しょうゆ', '17007', 4, 200, array['しょうゆ','醤油']::text[], true),
    ('natto-fry', 'protein', 'protein', '納豆', '04046', 60, 0, array['納豆']::text[], false),
    ('natto-fry', 'veg', 'veg', 'キャベツ', '06061', 80, 100, array['キャベツ']::text[], false),
    ('natto-fry', 'veg', 'veg', 'もやし', '06291', 90, 101, array['もやし']::text[], false),
    ('natto-fry', 'veg', 'veg', '小松菜', '06086', 80, 102, array['小松菜','こまつな']::text[], false),
    ('natto-fry', 'veg', 'veg', 'ねぎ', '06226', 50, 103, array['ねぎ','長ねぎ','ネギ']::text[], false),
    ('natto-fry', 'veg', 'veg', 'ピーマン', '06245', 60, 104, array['ピーマン']::text[], false),
    ('natto-fry', 'oil', 'oil', 'サラダ油', '14006', 6, 200, array['サラダ油','油']::text[], true),
    ('natto-fry', 'soy', 'seasoning', 'しょうゆ', '17007', 6, 300, array['しょうゆ','醤油']::text[], true),
    ('natto-fry', 'mirin', 'seasoning', 'みりん', '16025', 6, 400, array['みりん','本みりん']::text[], true),
    ('natto-pasta', 'protein', 'protein', '納豆', '04046', 50, 0, array['納豆']::text[], false),
    ('natto-pasta', 'veg', 'veg', 'ねぎ', '06226', 30, 100, array['ねぎ','長ねぎ','ネギ']::text[], false),
    ('natto-pasta', 'veg', 'veg', 'ほうれん草', '06267', 50, 101, array['ほうれん草','ほうれんそう']::text[], false),
    ('natto-pasta', 'veg', 'veg', 'しめじ', '08017', 50, 102, array['しめじ']::text[], false),
    ('natto-pasta', 'veg', 'veg', '小松菜', '06086', 50, 103, array['小松菜','こまつな']::text[], false),
    ('natto-pasta', 'rice', 'staple', 'スパゲティ', '01064', 200, 200, array['スパゲティ','パスタ']::text[], false),
    ('natto-pasta', 'oil', 'oil', 'サラダ油', '14006', 6, 300, array['サラダ油','油']::text[], true),
    ('natto-pasta', 'soy', 'seasoning', 'しょうゆ', '17007', 8, 400, array['しょうゆ','醤油']::text[], true),
    ('natto-pasta', 'pepper', 'seasoning', 'こしょう', '17063', 1, 500, array['こしょう','胡椒','コショウ']::text[], true),
    ('kakitama-udon', 'egg', 'egg', '卵', '12004', 50, 0, array['卵','たまご','玉子']::text[], false),
    ('kakitama-udon', 'veg', 'veg', 'ねぎ', '06226', 30, 100, array['ねぎ','長ねぎ','ネギ']::text[], false),
    ('kakitama-udon', 'veg', 'veg', 'ほうれん草', '06267', 50, 101, array['ほうれん草','ほうれんそう']::text[], false),
    ('kakitama-udon', 'veg', 'veg', '白菜', '06233', 60, 102, array['白菜','はくさい']::text[], false),
    ('kakitama-udon', 'veg', 'veg', 'しめじ', '08017', 50, 103, array['しめじ']::text[], false),
    ('kakitama-udon', 'rice', 'staple', 'うどん', '01039', 220, 200, array['うどん']::text[], false),
    ('kakitama-udon', 'dashi', 'seasoning', '顆粒だし', '17028', 3, 300, array['顆粒だし','だし','和風だし']::text[], true),
    ('kakitama-udon', 'soy', 'seasoning', 'しょうゆ', '17007', 8, 400, array['しょうゆ','醤油']::text[], true),
    ('kakitama-udon', 'mirin', 'seasoning', 'みりん', '16025', 6, 500, array['みりん','本みりん']::text[], true),
    ('yaki-udon', 'protein', 'protein', '豚こま', '11115', 70, 0, array['豚こま','豚こま切れ','豚コマ','豚肉']::text[], false),
    ('yaki-udon', 'protein', 'protein', '鶏むね肉', '11220', 80, 1, array['鶏むね肉','鶏むね','鶏胸肉','鶏肉']::text[], false),
    ('yaki-udon', 'protein', 'protein', 'ベーコン', '11183', 40, 2, array['ベーコン']::text[], false),
    ('yaki-udon', 'protein', 'protein', 'ちくわ', '10381', 60, 3, array['ちくわ','竹輪']::text[], false),
    ('yaki-udon', 'protein', 'egg', '卵', '12004', 50, 4, array['卵','たまご','玉子']::text[], false),
    ('yaki-udon', 'veg', 'veg', 'キャベツ', '06061', 80, 100, array['キャベツ']::text[], false),
    ('yaki-udon', 'veg', 'veg', '玉ねぎ', '06153', 50, 101, array['玉ねぎ','たまねぎ','タマネギ']::text[], false),
    ('yaki-udon', 'veg', 'veg', 'もやし', '06291', 80, 102, array['もやし']::text[], false),
    ('yaki-udon', 'veg', 'veg', 'ピーマン', '06245', 50, 103, array['ピーマン']::text[], false),
    ('yaki-udon', 'veg', 'veg', 'にんじん', '06214', 40, 104, array['にんじん','人参']::text[], false),
    ('yaki-udon', 'rice', 'staple', 'うどん', '01039', 220, 200, array['うどん']::text[], false),
    ('yaki-udon', 'oil', 'oil', 'サラダ油', '14006', 8, 300, array['サラダ油','油']::text[], true),
    ('yaki-udon', 'soy', 'seasoning', 'しょうゆ', '17007', 10, 400, array['しょうゆ','醤油']::text[], true),
    ('yaki-udon', 'mirin', 'seasoning', 'みりん', '16025', 6, 500, array['みりん','本みりん']::text[], true);
end $$;
