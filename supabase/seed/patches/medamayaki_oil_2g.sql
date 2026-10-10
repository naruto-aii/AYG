-- 本番の目玉焼きの油を、シード（supabase/seed/cook_recipes.sql）と同じ 2g にする。
-- グラムは cook_recipes ではなく、そのレシピの材料行 cook_recipe_options.base_grams。
-- UPDATE のみ。行の削除や再投入はしない。このファイルは本番へ自動適用しない。

update public.cook_recipe_options
set base_grams = 2
where recipe_id = 'medamayaki'
  and slot_key = 'oil'
  and label = 'サラダ油'
  and food_code = '14006';
