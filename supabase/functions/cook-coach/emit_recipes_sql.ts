// レシピ型から seed SQL を出す。本番には適用しない。
// deno run -A supabase/functions/cook-coach/emit_recipes_sql.ts > supabase/seed/cook_recipes.sql

import { cookRecipes } from "./recipes.ts";

function q(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

function array(values: string[]): string {
  return `array[${values.map(q).join(",")}]::text[]`;
}

const codes = new Set<string>();
for (const recipe of cookRecipes) {
  for (const slot of recipe.slots) {
    for (const option of slot.options) {
      codes.add(option.foodCode);
    }
  }
}
const listed = [...codes].sort();
const recipeRows = cookRecipes.map((recipe) =>
  `(${q(recipe.id)}, ${q(recipe.name)}, ${q(recipe.genre)}, ${q(recipe.category)}, ${q(recipe.method)}, ${recipe.minutes}, ${q(JSON.stringify(recipe.steps))}::jsonb)`
);
const optionRows: string[] = [];
for (const recipe of cookRecipes) {
  recipe.slots.forEach((slot, slotIndex) => {
    slot.options.forEach((option, optionIndex) => {
      optionRows.push(
        `(${q(recipe.id)}, ${q(slot.key)}, ${q(option.role)}, ${q(option.label)}, ${q(option.foodCode)}, ${option.grams}, ${slotIndex * 100 + optionIndex}, ${array(option.match)}, ${option.staple})`,
      );
    });
  });
}

console.log(`-- 家庭料理の型と入れ替え候補。official_foods が揃っているときだけ入れる。
-- アプリには埋め込まない。足すときは recipes.ts を編集し、この SQL を出し直す。
-- 本番には適用しない。

do $$
declare
  present integer;
begin
  select count(*) into present
  from public.official_foods
  where food_code in (${listed.map(q).join(", ")});
  if present < ${listed.length} then
    raise notice 'cook recipes skipped: official_foods has % of ${listed.length} codes', present;
    return;
  end if;

  delete from public.cook_recipes;

  insert into public.cook_recipes
    (id, name_template, genre, category, method, minutes, steps)
  values
    ${recipeRows.join(",\n    ")};

  insert into public.cook_recipe_options
    (recipe_id, slot_key, role, label, food_code, base_grams, sort_order, match_names, staple)
  values
    ${optionRows.join(",\n    ")};
end $$;
`);
