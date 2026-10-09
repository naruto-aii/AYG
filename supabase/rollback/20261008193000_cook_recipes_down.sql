-- 20261008193000_cook_recipes.sql を戻す。食事の記録は残す。

begin;

drop table if exists public.cook_zero_on_hand;
drop table if exists public.cook_recipe_options;
drop table if exists public.cook_recipes;

commit;
