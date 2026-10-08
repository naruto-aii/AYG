// 検証済みレシピを展開し、手持ちと買い足し1〜2品から目標に入る案を選ぶ。
// 分量は基準gの倍率だけ動かす。成分は選んだ食品の成分表から計算する。

import { cookFood, type CookFood, type CookRole } from "./foods.ts";
import {
  allowedMinutes,
  defaultTolerance,
  gapScore,
  gramsAreRealistic,
  isEgg,
  normalizeFoodName,
  round1,
  withinTolerance,
  type Macros,
  type MeasuredDish,
  type MeasuredIngredient,
} from "./match.ts";
import { assemblyIssues, nameMismatch, splitIncompatible, stepIssues, totalCookingMinutes } from "./plan.ts";

export type CookOption = {
  label: string;
  foodCode: string;
  officialName: string;
  grams: number;
  match: string[];
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  staple: boolean;
  role: CookRole;
};

export type CookSlot = {
  key: string;
  role: CookRole;
  options: CookOption[];
};

export type CookRecipe = {
  id: string;
  name: string;
  genre: string;
  category: string;
  method: string;
  minutes: number;
  steps: string[];
  slots: CookSlot[];
};

export type CookPlanInput = {
  ingredients: string[];
  slot: string;
  target: Macros;
  note?: string;
  avoid?: string[];
  recentNames?: string[];
};

export type CookSelection = {
  a: MeasuredDish | null;
  b: MeasuredDish | null;
  onHandHits: number;
  extraHits: number;
  emptyMessage: string;
  omitNote: string;
};

const emptyMessage =
  "手元の食材だけでは作れず、1〜2品買い足しても、この目標に合う家庭料理は見つかりませんでした。";

const bodyScales = [0.8, 0.85, 0.9, 0.95, 1, 1.05, 1.1, 1.15, 1.2];
const stapleScales = [0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5];

export function optionFromFood(id: string, grams: number): CookOption {
  const food = cookFood(id);
  return {
    label: food.label,
    foodCode: food.code,
    officialName: food.officialName,
    grams,
    match: food.match,
    kcal: food.kcal,
    proteinG: food.proteinG,
    fatG: food.fatG,
    carbG: food.carbG,
    staple: food.staple,
    role: food.role,
  };
}

export function slot(key: string, role: CookRole, options: CookOption[]): CookSlot {
  return { key, role, options };
}

export function applyFoodRows(
  recipes: CookRecipe[],
  rows: Map<string, { kcal: number; proteinG: number; fatG: number; carbG: number; officialName?: string }>,
): CookRecipe[] {
  return recipes.map((recipe) => ({
    ...recipe,
    slots: recipe.slots.map((item) => ({
      ...item,
      options: item.options.map((option) => {
        const row = rows.get(option.foodCode);
        if (!row) {
          return option;
        }
        return {
          ...option,
          kcal: row.kcal,
          proteinG: row.proteinG,
          fatG: row.fatG,
          carbG: row.carbG,
          officialName: row.officialName || option.officialName,
        };
      }),
    })),
  }));
}

export function recipeStamp(recipes: CookRecipe[]): string {
  return recipes
    .map((recipe) => `${recipe.id}:${recipe.slots.reduce((sum, item) => sum + item.options.length, 0)}`)
    .join("|");
}

type Fill = {
  recipe: CookRecipe;
  chosen: CookOption[];
  extras: string[];
};

type Ranked = {
  dish: MeasuredDish;
  recipeId: string;
  score: number;
  used: number;
};

export function selectCookPlans(recipes: CookRecipe[], input: CookPlanInput): CookSelection {
  const split = splitIncompatible(input.ingredients);
  const omitNote = split.dropped.length > 0
    ? `${split.dropped.join("、")}は一緒にしないので外しました。`
    : "";
  const listed = split.keep;
  const avoid = input.avoid ?? [];
  const recent = new Set((input.recentNames ?? []).map((name) => name.trim()));
  const note = input.note ?? "";
  const limit = allowedMinutes(note);
  const onHand: Ranked[] = [];
  const extra: Ranked[] = [];
  for (const recipe of recipes) {
    if (recipe.minutes > limit || totalCookingMinutes(recipe.steps.join("\n")) > limit) {
      continue;
    }
    if (input.slot === "snack" && (recipe.category === "丼麺" || recipe.name.includes("丼"))) {
      continue;
    }
    for (const fill of fills(recipe, listed, avoid, "on_hand")) {
      const ranked = rankFill(fill, input.target, listed, recent, note, omitNote);
      if (ranked) {
        onHand.push(ranked);
      }
    }
    for (const fill of fills(recipe, listed, avoid, "extra")) {
      const ranked = rankFill(fill, input.target, listed, recent, note, omitNote);
      if (ranked) {
        extra.push(ranked);
      }
    }
  }
  const a = pick(onHand);
  const b = pick(extra.filter((item) => !a || item.recipeId !== a.recipeId || item.dish.name !== a.dish.name));
  return {
    a: a?.dish ?? null,
    b: b?.dish ?? null,
    onHandHits: onHand.length,
    extraHits: extra.length,
    emptyMessage: a || b ? "" : emptyMessage,
    omitNote,
  };
}

export function expandRecipe(recipe: CookRecipe): Fill[] {
  return cartesian(recipe.slots.map((item) => item.options)).map((chosen) => ({
    recipe,
    chosen,
    extras: [],
  }));
}

function fills(recipe: CookRecipe, listed: string[], avoid: string[], kind: "on_hand" | "extra"): Fill[] {
  const groups = recipe.slots.map((item) => {
    const have: CookOption[] = [];
    const buy: CookOption[] = [];
    for (const option of item.options) {
      if (option.match.some((name) => listedHits(name, avoid)) || listedHits(option.label, avoid)) {
        continue;
      }
      if (option.match.some((name) => listedHits(name, listed)) || listedHits(option.label, listed)) {
        have.push(option);
      } else if (option.staple) {
        have.push(option);
      } else {
        buy.push(option);
      }
    }
    return { slot: item, have, buy };
  });
  if (groups.some((group) => group.have.length === 0 && group.buy.length === 0)) {
    return [];
  }
  const forced = groups.filter((group) => group.have.length === 0);
  if (kind === "on_hand") {
    if (forced.length > 0) {
      return [];
    }
    return anchored(
      recipe,
      cartesian(groups.map((group) => group.have)),
      listed,
      new Set(),
    );
  }
  if (forced.length === 0 || forced.length > 2) {
    return [];
  }
  const forcedKeys = new Set(forced.map((group) => group.slot.key));
  const chosenGroups = groups.map((group) => group.have.length > 0 ? group.have : group.buy);
  return anchored(recipe, cartesian(chosenGroups), listed, forcedKeys);
}

function anchored(
  recipe: CookRecipe,
  rows: CookOption[][],
  listed: string[],
  forcedKeys: Set<string>,
): Fill[] {
  const out: Fill[] = [];
  for (const chosen of rows) {
    const unique = [
      ...new Set(
        chosen
          .filter((_option, index) => forcedKeys.has(recipe.slots[index].key))
          .map((option) => option.label),
      ),
    ];
    if (forcedKeys.size > 0 && (unique.length < 1 || unique.length > 2)) {
      continue;
    }
    if (!usesListed(chosen, listed)) {
      continue;
    }
    out.push({ recipe, chosen, extras: unique });
    if (out.length >= 36) {
      break;
    }
  }
  return out;
}

function cartesian(groups: CookOption[][]): CookOption[][] {
  let rows: CookOption[][] = [[]];
  for (const group of groups) {
    const next: CookOption[][] = [];
    for (const row of rows) {
      for (const option of group) {
        next.push([...row, option]);
        if (next.length > 48) {
          return next;
        }
      }
    }
    rows = next;
  }
  return rows;
}

function usesListed(chosen: CookOption[], listed: string[]): boolean {
  return listed.some((name) =>
    chosen.some((option) => option.match.some((key) => namesMatch(name, key)) || namesMatch(name, option.label))
  );
}

function listedHits(key: string, names: string[]): boolean {
  return names.some((name) => namesMatch(name, key));
}

function namesMatch(left: string, right: string): boolean {
  const a = normalizeFoodName(left);
  const b = normalizeFoodName(right);
  if (!a || !b) {
    return false;
  }
  if (a === b) {
    return true;
  }
  if (a.length < 2 || b.length < 2) {
    return false;
  }
  if (!(a.includes(b) || b.includes(a))) {
    return false;
  }
  return Math.min(a.length, b.length) / Math.max(a.length, b.length) >= 0.5;
}

function rankFill(
  fill: Fill,
  target: Macros,
  listed: string[],
  recent: Set<string>,
  note: string,
  omitNote: string,
): Ranked | null {
  const draft = materialize(fill, 1, 1, target, omitNote, listed);
  if (!draft) {
    return null;
  }
  const issues = [
    ...assemblyIssues(draft.name, draft.steps, draft.ingredients, note),
    ...stepIssues(draft.steps, draft.ingredients, draft.name, note),
  ];
  if (issues.length > 0 || nameMismatch(draft.name, draft.ingredients)) {
    return null;
  }
  let best: Ranked | null = null;
  for (const body of bodyScales) {
    for (const staple of stapleScales) {
      const dish = materialize(fill, body, staple, target, omitNote, listed);
      if (!dish || !dish.within) {
        continue;
      }
      if (dish.ingredients.some((item) => !gramsAreRealistic(item.name, item.grams))) {
        continue;
      }
      const score = gapScore(target, dish.totals) + (recent.has(dish.name) ? 8000 : 0);
      const used = fill.chosen.filter((option) =>
        listed.some((name) => option.match.some((key) => namesMatch(name, key)) || namesMatch(name, option.label))
      ).length;
      if (!best || score < best.score - 1e-6 || (Math.abs(score - best.score) <= 1e-6 && used > best.used)) {
        best = { dish, recipeId: fill.recipe.id, score, used };
      }
    }
  }
  return best;
}

function materialize(
  fill: Fill,
  body: number,
  staple: number,
  target: Macros,
  omitNote: string,
  listed: string[],
): MeasuredDish | null {
  const byKey = new Map<string, { option: CookOption; grams: number }>();
  const ingredients: MeasuredIngredient[] = [];
  for (let index = 0; index < fill.recipe.slots.length; index++) {
    const key = fill.recipe.slots[index].key;
    const option = fill.chosen[index];
    const grams = scaledGrams(option, option.role === "staple" ? staple : body);
    if (grams == null) {
      return null;
    }
    byKey.set(key, { option, grams });
    const macros = macrosAt(option, grams);
    ingredients.push({
      name: option.label,
      grams,
      originalGrams: option.grams,
      kcal: macros.kcal,
      proteinG: macros.proteinG,
      fatG: macros.fatG,
      carbG: macros.carbG,
      source: "db",
      foodCode: option.foodCode,
      officialName: option.officialName,
      extra: fill.extras.includes(option.label),
      assumed: option.staple &&
        !fill.extras.includes(option.label) &&
        !listed.some((name) =>
          option.match.some((key) => namesMatch(name, key)) || namesMatch(name, option.label)
        ),
    });
  }
  const name = fillTemplate(fill.recipe.name, byKey);
  const steps = fill.recipe.steps.map((step) => fillTemplate(step, byKey));
  if (steps.some((step) => step.includes("{"))) {
    return null;
  }
  const totals = {
    kcal: ingredients.reduce((sum, item) => sum + item.kcal, 0),
    proteinG: round1(ingredients.reduce((sum, item) => sum + item.proteinG, 0)),
    fatG: round1(ingredients.reduce((sum, item) => sum + item.fatG, 0)),
    carbG: round1(ingredients.reduce((sum, item) => sum + item.carbG, 0)),
  };
  const gap = {
    kcal: Math.round(target.kcal - totals.kcal),
    proteinG: round1(target.proteinG - totals.proteinG),
    fatG: round1(target.fatG - totals.fatG),
    carbG: round1(target.carbG - totals.carbG),
  };
  const within = withinTolerance(target, totals, defaultTolerance);
  return {
    name,
    steps,
    extras: fill.extras,
    ingredients,
    totals,
    gap,
    within,
    score: gapScore(target, totals),
    issues: [],
    gapReason: "",
    omitNote,
    minutes: fill.recipe.minutes,
  };
}

const cookRoles = new Set(["protein", "veg", "staple", "seasoning", "oil", "egg", "other"]);

export function cookRecipesFromDb(rows: unknown[]): CookRecipe[] {
  if (!Array.isArray(rows)) {
    return [];
  }
  const recipes: CookRecipe[] = [];
  for (const item of rows) {
    if (item == null || typeof item !== "object") {
      continue;
    }
    const row = item as Record<string, unknown>;
    const id = textOf(row.id);
    const name = textOf(row.name_template);
    if (!id || !name) {
      continue;
    }
    const steps = Array.isArray(row.steps)
      ? row.steps.filter((step): step is string => typeof step === "string" && step.length > 0)
      : [];
    const options = Array.isArray(row.cook_recipe_options) ? row.cook_recipe_options : [];
    const grouped = new Map<string, CookOption[]>();
    const roles = new Map<string, CookRole>();
    const sortable = options
      .filter((option): option is Record<string, unknown> => option != null && typeof option === "object")
      .map((option) => option as Record<string, unknown>)
      .sort((left, right) => numberOf(left.sort_order) - numberOf(right.sort_order));
    for (const option of sortable) {
      const key = textOf(option.slot_key);
      const role = textOf(option.role);
      const label = textOf(option.label);
      const foodCode = textOf(option.food_code);
      if (!key || !cookRoles.has(role) || !label || !/^[0-9]{5}$/.test(foodCode)) {
        continue;
      }
      const nutrition = option.official_foods != null && typeof option.official_foods === "object"
        ? option.official_foods as Record<string, unknown>
        : {};
      const match = Array.isArray(option.match_names)
        ? option.match_names.filter((name): name is string => typeof name === "string" && name.length > 0)
        : [label];
      const cooked: CookOption = {
        label,
        foodCode,
        officialName: textOf(nutrition.name) || label,
        grams: numberOf(option.base_grams),
        match,
        kcal: numberOf(nutrition.kcal),
        proteinG: numberOf(nutrition.protein_g),
        fatG: numberOf(nutrition.fat_g),
        carbG: numberOf(nutrition.carb_g),
        staple: option.staple === true,
        role: role as CookRole,
      };
      if (!(cooked.grams > 0)) {
        continue;
      }
      const list = grouped.get(key) ?? [];
      list.push(cooked);
      grouped.set(key, list);
      if (!roles.has(key)) {
        roles.set(key, cooked.role);
      }
    }
    const slots = [...grouped.entries()].map(([key, slotOptions]) => ({
      key,
      role: roles.get(key) ?? slotOptions[0].role,
      options: slotOptions,
    }));
    if (slots.length === 0 || steps.length === 0) {
      continue;
    }
    recipes.push({
      id,
      name,
      genre: textOf(row.genre),
      category: textOf(row.category),
      method: textOf(row.method),
      minutes: numberOf(row.minutes),
      steps,
      slots,
    });
  }
  return recipes;
}

function textOf(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberOf(value: unknown): number {
  const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(number) ? number : 0;
}

function scaledGrams(option: CookOption, scale: number): number | null {
  const minScale = option.role === "staple" ? 0.5 : 0.8;
  const maxScale = option.role === "staple" ? 1.5 : 1.2;
  const raw = option.grams * scale;
  if (raw < option.grams * minScale - 0.01 || raw > option.grams * maxScale + 0.01) {
    return null;
  }
  let grams = Math.round(raw);
  if (isEgg(option.label)) {
    grams = Math.max(50, Math.min(200, Math.round(grams / 50) * 50));
  }
  if (grams < 1 || !gramsAreRealistic(option.label, grams)) {
    return null;
  }
  return grams;
}

function macrosAt(option: CookOption, grams: number): Macros {
  const scale = grams / 100;
  return {
    kcal: Math.round(option.kcal * scale),
    proteinG: round1(option.proteinG * scale),
    fatG: round1(option.fatG * scale),
    carbG: round1(option.carbG * scale),
  };
}

function fillTemplate(
  template: string,
  byKey: Map<string, { option: CookOption; grams: number }>,
): string {
  return template
    .replaceAll(/\{g:([a-z0-9_]+)\}/g, (_all, key: string) => String(byKey.get(key)?.grams ?? `{g:${key}}`))
    .replaceAll(/\{([a-z0-9_]+)\}/g, (_all, key: string) => byKey.get(key)?.option.label ?? `{${key}}`);
}

function pick(items: Ranked[]): Ranked | null {
  let best: Ranked | null = null;
  for (const item of items) {
    if (!best || item.score < best.score - 1e-6 || (Math.abs(item.score - best.score) <= 1e-6 && item.used > best.used)) {
      best = item;
    }
  }
  return best;
}

export function nutritionOf(food: CookFood, grams: number): Macros {
  return macrosAt({
    label: food.label,
    foodCode: food.code,
    officialName: food.officialName,
    grams,
    match: food.match,
    kcal: food.kcal,
    proteinG: food.proteinG,
    fatG: food.fatG,
    carbG: food.carbG,
    staple: food.staple,
    role: food.role,
  }, grams);
}
