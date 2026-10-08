// レシピ型を全展開して品質を見る。ネットワークも本番 DB も使わない。
// deno run -A supabase/functions/cook-coach/check_recipes.ts

import { isOil, isSeasoning, round1 } from "./match.ts";
import { assemblyIssues, nameMismatch, totalCookingMinutes } from "./plan.ts";
import { cookRecipes } from "./recipes.ts";
import { expandRecipe, type CookOption, type CookRecipe } from "./select.ts";

const noHeat = /冷奴|冷ややっこ|冷やっこ|和え物|和え|酢の物|おひたし|お浸し/;
const bannedStep = /揚げる|天ぷら|唐揚げ|フライヤー/;

type Row = {
  recipe: CookRecipe;
  chosen: CookOption[];
  name: string;
};

function fill(template: string, recipe: CookRecipe, chosen: CookOption[]): string {
  let text = template;
  recipe.slots.forEach((item, index) => {
    text = text.replaceAll(`{g:${item.key}}`, String(chosen[index].grams));
    text = text.replaceAll(`{${item.key}}`, chosen[index].label);
  });
  return text;
}

function macros(chosen: CookOption[]) {
  const totals = { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 };
  for (const option of chosen) {
    const scale = option.grams / 100;
    totals.kcal += Math.round(option.kcal * scale);
    totals.proteinG += option.proteinG * scale;
    totals.fatG += option.fatG * scale;
    totals.carbG += option.carbG * scale;
  }
  return {
    kcal: totals.kcal,
    proteinG: round1(totals.proteinG),
    fatG: round1(totals.fatG),
    carbG: round1(totals.carbG),
  };
}

function proteinOf(option: CookOption): number {
  return option.proteinG * option.grams / 100;
}

function checkRow(row: Row): string[] {
  const issues: string[] = [];
  const { recipe, chosen, name } = row;
  if (name.includes("{") || name.includes("}")) {
    issues.push("name placeholder");
  }
  if (/鮭/.test(name) && /親子/.test(name)) {
    issues.push("unnatural salmon oyakodon");
  }
  if (nameMismatch(name, chosen.map((option) => ({ name: option.label })))) {
    issues.push("name mismatch");
  }
  const steps = recipe.steps.map((step) => fill(step, recipe, chosen));
  if (steps.some((step) => step.includes("{"))) {
    issues.push("step placeholder");
  }
  if (steps.some((step) => bannedStep.test(step)) || bannedStep.test(name)) {
    issues.push("deep fry");
  }
  if (steps.length < 3 || steps.length > 6) {
    issues.push(`steps ${steps.length}`);
  }
  const minutes = totalCookingMinutes(steps.join("\n"));
  if (minutes < 5 || recipe.minutes < 5 || recipe.minutes > 30) {
    issues.push(`minutes ${minutes}`);
  }
  const craft = assemblyIssues(name, steps, chosen.map((option) => ({ name: option.label, grams: option.grams })));
  if (craft.length > 0) {
    issues.push(craft.join(","));
  }
  for (const option of chosen) {
    if (!/^[0-9]{5}$/.test(option.foodCode)) {
      issues.push(`food code ${option.label}`);
    }
    if (!(option.grams > 0)) {
      issues.push(`grams ${option.label}`);
    }
  }
  const seasonings = chosen.filter((option) => isSeasoning(option.label) && !isOil(option.label) && option.grams >= 1);
  if (!noHeat.test(name) && seasonings.length < 2) {
    issues.push("seasonings");
  }
  const simmer = recipe.method.includes("煮") || steps.some((step) => step.includes("煮"));
  if (simmer) {
    const liquid = steps.join("\n") + chosen.map((option) => option.label).join("");
    if (!/水|だし|顆粒/.test(liquid)) {
      issues.push("simmer liquid");
    }
  }
  const protein = recipe.slots
    .map((item, index) => ({ item, option: chosen[index] }))
    .find((pair) => pair.item.key === "protein" || pair.item.role === "protein");
  const egg = chosen.find((option) => option.role === "egg" || option.label.includes("卵"));
  if (protein && egg && protein.option !== egg) {
    const main = proteinOf(protein.option);
    const side = proteinOf(egg);
    if (main + side > 0 && main / (main + side) < 0.45) {
      issues.push("protein ratio");
    }
  }
  const joined = chosen.map((option) => option.label).join(" ");
  const keywordNeeds: Array<[RegExp, RegExp]> = [
    [/ムニエル/, /小麦粉|薄力粉/],
    [/ムニエル/, /バター/],
    [/バター/, /バター/],
    [/トマト/, /トマト|ケチャップ/],
    [/味噌/, /味噌/],
    [/カレー/, /カレー/],
    [/麻婆/, /豆板醤/],
    [/麻婆/, /片栗粉/],
    [/レモン/, /レモン/],
    [/コンソメ/, /コンソメ/],
    [/エスニック/, /ナンプラー|レモン/],
    [/ナンプラー/, /ナンプラー/],
    [/酢豚/, /酢/],
    [/にんにく|ガーリック/, /にんにく/],
    [/生姜|しょうが/, /しょうが/],
    [/チーズ/, /チーズ/],
  ];
  for (const [claim, need] of keywordNeeds) {
    if (claim.test(name) && !need.test(joined)) {
      issues.push(`keyword ${claim}`);
    }
  }
  if (/かきたま|卵とトマトのスープ/.test(name) && joined.includes("味噌")) {
    issues.push("miso in clear soup");
  }
  if (/和え/.test(name) && !/ゆで|茹|火を通|加熱|焼く/.test(steps.join("\n")) && /じゃがいも|ブロッコリー|かぼちゃ|ごぼう/.test(joined)) {
    issues.push("boiled vegetable missing a cook step");
  }
  const totals = macros(chosen);
  const floor = recipe.category === "副菜" || recipe.category === "汁物" || recipe.category === "軽い品" ? 25 : 80;
  if (totals.kcal < floor || totals.kcal > 1200) {
    issues.push(`kcal ${totals.kcal}`);
  }
  for (const key of recipe.name.matchAll(/\{([a-z0-9_]+)\}/g)) {
    const index = recipe.slots.findIndex((item) => item.key === key[1]);
    if (index < 0 || !name.includes(chosen[index].label)) {
      issues.push(`slot ${key[1]}`);
    }
  }
  return issues;
}

function canonical(recipe: CookRecipe): Row {
  const chosen = recipe.slots.map((item) => item.options[0]);
  return { recipe, chosen, name: fill(recipe.name, recipe, chosen) };
}

function line(row: Row): string {
  const totals = macros(row.chosen);
  const season = row.chosen
    .filter((option) => isSeasoning(option.label) && !isOil(option.label))
    .map((option) => `${option.label}${option.grams}g`)
    .join(" ");
  const foods = row.chosen
    .filter((option) => !isSeasoning(option.label) && !isOil(option.label))
    .map((option) => `${option.label}${option.grams}g`)
    .join("、");
  return [
    row.name,
    row.recipe.genre,
    row.recipe.category,
    `${row.recipe.minutes}分`,
    foods,
    season,
    `${totals.kcal}kcal`,
    `P${totals.proteinG}`,
    `F${totals.fatG}`,
    `C${totals.carbG}`,
  ].join("\t");
}

const recipes = cookRecipes;
const failures: string[] = [];
const names = new Map<string, string>();
const fingerprints = new Map<string, string>();
let patterns = 0;

function fingerprint(row: Row): string {
  const foods = row.chosen
    .map((option) => `${option.foodCode}:${option.grams}`)
    .sort()
    .join("|");
  const totals = macros(row.chosen);
  return `${foods}#${totals.kcal},${totals.proteinG},${totals.fatG},${totals.carbG}`;
}
if (recipes.length !== 100) {
  failures.push(`recipe count ${recipes.length}`);
}
for (const recipe of recipes) {
  const rows = expandRecipe(recipe).map((fillRow) => ({
    recipe,
    chosen: fillRow.chosen,
    name: fill(recipe.name, recipe, fillRow.chosen),
  }));
  patterns += rows.length;
  for (const row of rows) {
    const issues = checkRow(row);
    if (issues.length > 0) {
      failures.push(`${recipe.id} ${row.name}: ${issues.join("; ")}`);
    }
    const previous = names.get(row.name);
    if (previous && previous !== recipe.id) {
      failures.push(`duplicate name ${row.name} (${previous}, ${recipe.id})`);
    }
    names.set(row.name, recipe.id);
    const print = fingerprint(row);
    const same = fingerprints.get(print);
    if (same && same !== recipe.id) {
      failures.push(`duplicate composition ${row.name} (${same}, ${recipe.id})`);
    }
    fingerprints.set(print, recipe.id);
  }
}
if (patterns < 1500) {
  failures.push(`patterns ${patterns} < 1500`);
}

const genres = new Map<string, number>();
const categories = new Map<string, number>();
for (const recipe of recipes) {
  genres.set(recipe.genre, (genres.get(recipe.genre) ?? 0) + 1);
  categories.set(recipe.category, (categories.get(recipe.category) ?? 0) + 1);
}

console.log("recipes\t" + recipes.length);
console.log("patterns\t" + patterns);
console.log("failures\t" + failures.length);
for (const [key, count] of genres) {
  console.log(`genre\t${key}\t${count}`);
}
for (const [key, count] of categories) {
  console.log(`category\t${key}\t${count}`);
}
console.log("--- failures ---");
for (const failure of failures.slice(0, 80)) {
  console.log(failure);
}
console.log("--- dishes ---");
for (const recipe of recipes) {
  console.log(line(canonical(recipe)));
}

if (failures.length > 0 || recipes.length !== 100) {
  Deno.exit(1);
}
