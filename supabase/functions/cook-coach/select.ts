// 検証済みレシピを展開し、手持ちと買い足し1〜2品から目標に入る案を選ぶ。
// 分量は基準gの倍率だけ動かす。成分は選んだ食品の成分表から計算する。

import { refineMeal } from "./refine.ts";
import { cookFood, cookFoods, type CookFood, type CookRole } from "./foods.ts";
import {
  allowedMinutes,
  defaultTolerance,
  explainGap,
  gapScore,
  gramsAreRealistic,
  isEgg,
  isMeatFish,
  isRice,
  normalizeFoodName,
  round1,
  withinTolerance,
  type Macros,
  type MeasuredDish,
  type MeasuredIngredient,
} from "./match.ts";
import { assemblyIssues, nameMismatch, plainStarchSeasoningIssue, splitIncompatible, totalCookingMinutes } from "./plan.ts";

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

const unusableFood = /トリュフ|チョコ|チョコレート/;

export function selectCookPlans(recipes: CookRecipe[], input: CookPlanInput): CookSelection {
  const split = splitIncompatible(input.ingredients);
  const dropped = [...split.dropped];
  const listed = split.keep.filter((name) => {
    if (unusableFood.test(name)) {
      dropped.push(name);
      return false;
    }
    return true;
  });
  const omitNote = dropped.length > 0 ? `${dropped.join("、")}は食事には使わないので外しました。` : "";
  const avoid = input.avoid ?? [];
  const recent = new Set((input.recentNames ?? []).map((name) => name.trim()));
  const note = input.note ?? "";
  const limit = allowedMinutes(note);
  // 本番は id 順で読み込むので、ここでも id 順にして結果を同じにする。
  const ordered = [...recipes].sort((left, right) => left.id < right.id ? -1 : left.id > right.id ? 1 : 0);
  const run = (names: string[], noteText: string) => {
    const onHand = composeMeals(ordered, names, avoid, input.target, limit, input.slot, note, noteText, recent, "on_hand");
    const extra = composeMeals(ordered, names, avoid, input.target, limit, input.slot, note, noteText, recent, "extra");
    const a = pick(onHand);
    const b = pick(extra.filter((item) => !a || item.dish.name !== a.dish.name));
    return { a, b, onHandHits: onHand.length, extraHits: extra.length };
  };
  let found = listed.length > 0 ? run(listed, omitNote) : null;
  if (!found || (!found.a && !found.b)) {
    // 0件にはしない。使えなかった食材を1つずつ外し、それでも無ければ家にある卵・ごはん・キャベツで作る。
    // 外した食材は omitNote で必ず伝える。
    const tries: Array<{ names: string[]; skipped: string[] }> = [];
    if (listed.length > 1) {
      for (const name of listed) {
        tries.push({ names: listed.filter((item) => item !== name), skipped: [name] });
      }
    }
    for (const pantry of [["卵", "ごはん"], ["卵"], ["キャベツ", "卵"], ["ごはん"], ["豆腐"]]) {
      tries.push({ names: pantry, skipped: listed });
    }
    for (const attempt of tries) {
      const usable = attempt.names.filter((name) => !avoid.some((item) => namesMatch(item, name)));
      if (usable.length === 0) {
        continue;
      }
      const skippedNote = attempt.skipped.length > 0
        ? `${attempt.skipped.join("、")}は、この量の目標に合う家庭料理が作れなかったため使っていません。`
        : "";
      const noteText = [omitNote, skippedNote].filter((text) => text.length > 0).join("");
      const next = run(usable, noteText);
      if (next.a || next.b) {
        found = next;
        break;
      }
    }
  }
  const a = found?.a ?? null;
  const b = found?.b ?? null;
  return {
    a: a?.dish ?? null,
    b: b?.dish ?? null,
    onHandHits: found?.onHandHits ?? 0,
    extraHits: found?.extraHits ?? 0,
    emptyMessage: a || b ? "" : emptyMessage,
    omitNote: (a ?? b)?.dish.omitNote ?? omitNote,
  };
}

function composeMeals(
  recipes: CookRecipe[],
  listed: string[],
  avoid: string[],
  target: Macros,
  limit: number,
  slotName: string,
  note: string,
  omitNote: string,
  recent: Set<string>,
  kind: "on_hand" | "extra",
): Ranked[] {
  const groups = collect(recipes, listed, avoid, limit, slotName, target, omitNote, kind);
  let mains = groups.mains;
  if (mains.length === 0) {
    mains = kind === "extra" ? groups.extraSides : [...groups.sides, ...groups.soups];
  }
  const found: Ranked[] = [];
  const consider = (parts: MeasuredDish[], recipeId: string) => {
    const minutes = parts.reduce((sum, part) => sum + (part.minutes ?? 0), 0);
    const steps = parts.reduce((sum, part) => sum + part.steps.length, 0);
    if (minutes > limit || steps > 18 || steps < 3) {
      return;
    }
    // 主材料・主食・油の量を目標の kcal と PFC に寄せてから判定する。
    const meal = refineMeal(combineMeal(parts, target, omitNote), target);
    if (!kcalOk(meal.totals.kcal, target.kcal)) {
      return;
    }
    if (kind === "on_hand" && meal.extras.length > 0) {
      return;
    }
    if (kind === "extra" && (meal.extras.length < 1 || meal.extras.length > 2)) {
      return;
    }
    if (slotName === "snack" && meal.name.includes("丼")) {
      return;
    }
    if (totalCookingMinutes(meal.steps.join("\n")) > limit) {
      return;
    }
    if (!proteinRule(meal, listed)) {
      return;
    }
    if (seasoningOverCap(meal.ingredients)) {
      return;
    }
    if (nameMismatch(meal.name, meal.ingredients)) {
      return;
    }
    if (plainStarchSeasoningIssue(meal.name, meal.steps, meal.ingredients)) {
      return;
    }
    const craft = assemblyIssues(
      meal.name,
      meal.steps,
      meal.ingredients.map((item) => ({ name: item.name, grams: item.grams })),
      note,
    );
    if (craft.length > 0) {
      return;
    }
    const hardMiss = missedHard(meal, listed);
    const within = meal.within ? 0 : 1;
    const used = usedCount(meal, listed);
    // P/F/C が目標の ±15% に入る案を先にし、近さは kcal ±10% と P/F/C ±15% を1として測る。
    const norm = normalizedGap(target, meal.totals);
    const strict = strictWithin(target, meal.totals) ? 0 : 1;
    // 同じくらい近い案では、入力した食材を多く使う方を先にする。
    const band = Math.floor(norm / 1.5);
    const score = hardMiss * 1e12 + strict * 1e10 + within * 1e9 + band * 1e6 - used * 1000 + norm +
      (recent.has(meal.name) ? 0.5 : 0);
    found.push({ dish: meal, recipeId, score, used: used - hardMiss * 100 });
    if (found.length > 500) {
      found.sort((left, right) => left.score - right.score);
      found.length = 100;
    }
  };
  const visit = (bases: MeasuredDish[][], recipeId: string) => {
    for (const base of bases) {
      if (hasStarch(base) || avoidRice(avoid)) {
        consider(base, recipeId);
        continue;
      }
      consider(base, recipeId);
      const kcal = base.reduce((sum, part) => sum + part.totals.kcal, 0);
      for (const grams of riceFit(kcal, target.kcal)) {
        consider([...base, riceDish(grams, listed)], recipeId);
      }
    }
  };
  for (const main of mains) {
    visit(basesOf(main.parts, groups.sides, groups.soups), main.recipeId);
  }
  // ごはんをよそうだけの案は料理ではないので出さない。ごはんは料理に添えるときだけ使う。
  if (
    kind === "on_hand" &&
    listedHits("牛乳", listed) &&
    !listedHits("牛乳", avoid) &&
    !listedHits("バター", avoid)
  ) {
    for (const grams of [120, 150, 180]) {
      consider([milkSoup(grams, listed)], "milk-potage");
    }
  }
  if (kind === "extra") {
    // 買い足しの主菜に、買い足しの副菜を1品添える（買うのは合わせて2品まで）。
    for (const main of mains) {
      for (const side of groups.extraSides) {
        if (overlaps(main.parts, side.parts)) {
          continue;
        }
        visit([[...main.parts, ...side.parts]], main.recipeId);
      }
    }
    for (const main of groups.onHandMains) {
      for (const side of groups.extraSides) {
        visit([[...main.parts, ...side.parts]], side.recipeId);
      }
    }
  }
  return found;
}

function normalizedGap(target: Macros, actual: Macros): number {
  const k = (actual.kcal - target.kcal) / Math.max(1, target.kcal * 0.1);
  const p = (actual.proteinG - target.proteinG) / Math.max(1, target.proteinG * 0.15);
  const f = (actual.fatG - target.fatG) / Math.max(1, target.fatG * 0.15);
  const c = (actual.carbG - target.carbG) / Math.max(1, target.carbG * 0.15);
  return k * k + p * p + f * f + c * c;
}

function strictWithin(target: Macros, actual: Macros): boolean {
  const ok = (a: number, t: number) => Math.abs(a - t) <= Math.abs(t) * 0.15 + 0.05;
  return kcalOk(actual.kcal, target.kcal) && ok(actual.proteinG, target.proteinG) &&
    ok(actual.fatG, target.fatG) && ok(actual.carbG, target.carbG);
}

function overlaps(have: MeasuredDish[], extra: MeasuredDish[]): boolean {
  return extra.some((part) => have.some((item) => item.name === part.name));
}

function basesOf(main: MeasuredDish[], sides: Array<{ parts: MeasuredDish[] }>, soups: Array<{ parts: MeasuredDish[] }>): MeasuredDish[][] {
  const out: MeasuredDish[][] = [main];
  for (const side of sides) {
    if (overlaps(main, side.parts)) {
      continue;
    }
    out.push([...main, ...side.parts]);
  }
  for (const soup of soups) {
    if (overlaps(main, soup.parts)) {
      continue;
    }
    out.push([...main, ...soup.parts]);
  }
  for (const side of sides) {
    if (overlaps(main, side.parts)) {
      continue;
    }
    for (const soup of soups) {
      if (overlaps(main, soup.parts) || overlaps(side.parts, soup.parts)) {
        continue;
      }
      out.push([...main, ...side.parts, ...soup.parts]);
    }
  }
  return out;
}

function hasStarch(parts: MeasuredDish[]): boolean {
  return parts.some((part) =>
    part.ingredients.some((item) => isRice(item.name) || /うどん|そば|パスタ|スパゲティ|食パン|中華麺|麺/.test(item.name))
  );
}

function avoidRice(avoid: string[]): boolean {
  return avoid.some((name) => namesMatch(name, "ごはん") || namesMatch(name, "ご飯"));
}

function riceFit(otherKcal: number, targetKcal: number): number[] {
  // 大きい目標では 400g を上限に、主食で届く分だけ足す（残りは分量の調整で寄せる）。
  const ideal = Math.min(400, Math.round((targetKcal - otherKcal) / 1.56));
  const out: number[] = [];
  for (const grams of [ideal - 30, ideal, ideal + 30]) {
    if (grams >= 50 && grams <= 400 && !out.includes(grams)) {
      out.push(grams);
    }
  }
  return out;
}

function collect(
  recipes: CookRecipe[],
  listed: string[],
  avoid: string[],
  limit: number,
  slotName: string,
  target: Macros,
  omitNote: string,
  kind: "on_hand" | "extra",
) {
  const mains: Array<{ recipeId: string; parts: MeasuredDish[] }> = [];
  const onHandMains: Array<{ recipeId: string; parts: MeasuredDish[] }> = [];
  const sides: Array<{ recipeId: string; parts: MeasuredDish[] }> = [];
  const extraSides: Array<{ recipeId: string; parts: MeasuredDish[] }> = [];
  const soups: Array<{ recipeId: string; parts: MeasuredDish[] }> = [];
  for (const recipe of recipes) {
    if (recipe.minutes > limit) {
      continue;
    }
    if (slotName === "snack" && (recipe.category === "丼麺" || recipe.name.includes("丼"))) {
      continue;
    }
    const role = recipe.category === "汁物" ? "soup" : recipe.category === "副菜" || recipe.category === "軽い品" ? "side" : "main";
    const modes: Array<"on_hand" | "extra"> = [];
    if (kind === "on_hand" || role !== "main") {
      modes.push("on_hand");
    }
    if (kind === "extra" && (role === "main" || role === "side")) {
      modes.push("extra");
    }
    for (const mode of modes) {
      const rows = fills(recipe, listed, avoid, mode).slice(0, 4);
      for (const fill of rows) {
        for (const dish of scaledDishes(fill, target, omitNote, listed)) {
          const pack = { recipeId: recipe.id, parts: [dish] };
          if (role === "soup" && mode === "on_hand") {
            soups.push(pack);
          } else if (role === "side" && mode === "on_hand") {
            sides.push(pack);
          } else if (role === "side" && mode === "extra") {
            extraSides.push(pack);
          } else if (role === "main" && mode === "on_hand") {
            onHandMains.push(pack);
            if (kind === "on_hand") {
              mains.push(pack);
            }
          } else if (role === "main" && mode === "extra") {
            mains.push(pack);
          }
        }
      }
    }
  }
  return {
    mains: diversify(mains, listed, target, kind === "extra" ? 40 : 16, 2),
    onHandMains: diversify(onHandMains, listed, target, 10, 2),
    sides: diversify(sides, listed, null, 4, 1),
    extraSides: diversify(extraSides, listed, null, 4, 1),
    soups: diversify(soups, listed, null, 4, 2),
  };
}

function diversify(
  packs: Array<{ recipeId: string; parts: MeasuredDish[] }>,
  listed: string[],
  target: Macros | null,
  max: number,
  perRecipe: number,
) {
  // 主菜は、使う食材の数が同じなら、ごはんで kcal を埋めたときに目標へ近い品を残す（id 順で落とさない）。
  const keyed = packs.map((pack) => ({
    pack,
    used: usedCount(pack.parts[0], listed),
    fit: target ? riceFilledGap(pack.parts[0], target) : 0,
  }));
  const order = (left: typeof keyed[number], right: typeof keyed[number]) => right.used - left.used || left.fit - right.fit;
  const groups = new Map<string, typeof keyed>();
  for (const item of keyed) {
    const list = groups.get(item.pack.recipeId) ?? [];
    list.push(item);
    groups.set(item.pack.recipeId, list);
  }
  const out: typeof keyed = [];
  for (const list of groups.values()) {
    list.sort(order);
    out.push(...list.slice(0, perRecipe));
  }
  out.sort(order);
  return out.slice(0, max).map((item) => item.pack);
}

function riceFilledGap(dish: MeasuredDish, target: Macros): number {
  const rice = cookFood("rice");
  const grams = hasStarch([dish]) ? 0 : Math.max(0, (target.kcal - dish.totals.kcal) / rice.kcal * 100);
  return gapScore(target, {
    kcal: dish.totals.kcal + rice.kcal * grams / 100,
    proteinG: dish.totals.proteinG + rice.proteinG * grams / 100,
    fatG: dish.totals.fatG + rice.fatG * grams / 100,
    carbG: dish.totals.carbG + rice.carbG * grams / 100,
  });
}

function scaledDishes(fill: Fill, target: Macros, omitNote: string, listed: string[]): MeasuredDish[] {
  const hasEgg = fill.chosen.some((option) => isEgg(option.label));
  const hasStaple = fill.chosen.some((option) => option.role === "staple");
  // 鶏むね肉のような脂の少ない肉は、140g のままだとごはんで kcal を埋めたときにたんぱく質が多すぎる。
  // 小さめの量も作り、PFC がいちばん近い量を必ず候補に残す。
  const bodies = hasEgg ? [0.5, 1, 2] : [0.7, 0.85, 1, 1.45];
  const staples = hasStaple ? [0.55, 1, 1.35] : [1];
  // 油はレシピの分量のまま。kcal は主材料とごはんで合わせる。
  const oilScales = [1];
  const aim = hasStaple ? target.kcal : Math.max(80, target.kcal * 0.48);
  const dishes: MeasuredDish[] = [];
  for (const body of bodies) {
    for (const staple of staples) {
      for (const oilScale of oilScales) {
        const dish = materialize(fill, body, staple, target, omitNote, listed, oilScale);
        if (dish) {
          dishes.push(dish);
        }
      }
    }
  }
  if (dishes.length === 0) {
    return [];
  }
  const closest = (aimKcal: number) =>
    dishes.reduce((best, dish) =>
      Math.abs(dish.totals.kcal - aimKcal) < Math.abs(best.totals.kcal - aimKcal) ? dish : best
    );
  const bestFit = dishes.reduce((best, dish) =>
    riceFilledGap(dish, target) < riceFilledGap(best, target) ? dish : best
  );
  const chosen = [closest(aim), closest(target.kcal), bestFit];
  return chosen.filter((dish, index) => chosen.findIndex((item) => item === dish) === index);
}

function riceDish(grams: number, listed: string[]): MeasuredDish {
  const food = optionFromFood("rice", grams);
  const macros = macrosAt(food, grams);
  const assumed = !listed.some((name) => namesMatch(name, "ごはん") || namesMatch(name, "ご飯"));
  return {
    name: "ごはんの温め",
    steps: [
      `ごはん${grams}gを茶碗によそう（冷やご飯なら電子レンジで温める）。`,
    ],
    extras: [],
    ingredients: [
      {
        name: food.label,
        grams,
        originalGrams: grams,
        kcal: macros.kcal,
        proteinG: macros.proteinG,
        fatG: macros.fatG,
        carbG: macros.carbG,
        source: "db",
        foodCode: food.foodCode,
        officialName: food.officialName,
        extra: false,
        assumed,
      },
    ],
    totals: {
      kcal: macros.kcal,
      proteinG: macros.proteinG,
      fatG: macros.fatG,
      carbG: macros.carbG,
    },
    gap: { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 },
    within: false,
    score: 0,
    issues: [],
    gapReason: "",
    omitNote: "",
    minutes: 2,
  };
}

function milkSoup(grams: number, listed: string[]): MeasuredDish {
  const parts: Array<{ id: string; grams: number }> = [
    { id: "milk", grams },
    { id: "butter", grams: 6 },
    { id: "consomme", grams: 4 },
    { id: "salt", grams: 1 },
    { id: "pepper", grams: 1 },
  ];
  const ingredients = parts.map((part) => {
    const food = optionFromFood(part.id, part.grams);
    const macros = macrosAt(food, part.grams);
    const listedHere = listed.some((name) =>
      food.match.some((key) => namesMatch(name, key)) || namesMatch(name, food.label)
    );
    return {
      name: food.label,
      grams: part.grams,
      originalGrams: part.grams,
      kcal: macros.kcal,
      proteinG: macros.proteinG,
      fatG: macros.fatG,
      carbG: macros.carbG,
      source: "db" as const,
      foodCode: food.foodCode,
      officialName: food.officialName,
      extra: false,
      assumed: food.staple && !listedHere,
    };
  });
  const totals = {
    kcal: ingredients.reduce((sum, item) => sum + item.kcal, 0),
    proteinG: round1(ingredients.reduce((sum, item) => sum + item.proteinG, 0)),
    fatG: round1(ingredients.reduce((sum, item) => sum + item.fatG, 0)),
    carbG: round1(ingredients.reduce((sum, item) => sum + item.carbG, 0)),
  };
  return {
    name: "クリームスープ",
    steps: [
      `鍋に牛乳${grams}gと水を150mlとコンソメ4gを入れて中火にする。`,
      "バター6gを加えて4分煮る。",
      "塩1gとこしょう1gを加えて1分煮て火を止める。",
    ],
    extras: [],
    ingredients,
    totals,
    gap: { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 },
    within: false,
    score: 0,
    issues: [],
    gapReason: "",
    omitNote: "",
    minutes: 5,
  };
}

function combineMeal(parts: MeasuredDish[], target: Macros, omitNote: string): MeasuredDish {
  const starch = parts.some((part, index) =>
    index < parts.length - 1 && part.ingredients.some((item) => isRice(item.name) || /うどん|そば|パスタ|スパゲティ|食パン|中華麺|麺/.test(item.name))
  );
  const usable = starch ? parts.filter((part) => part.name !== "ごはんの温め") : parts;
  const ingredients = usable.flatMap((part) => part.ingredients);
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
  const dish: MeasuredDish = {
    name: usable.map((part) => part.name).join("、"),
    steps: usable.flatMap((part) => part.steps),
    extras: [...new Set(usable.flatMap((part) => part.extras))],
    ingredients,
    totals,
    gap,
    within,
    score: gapScore(target, totals),
    issues: [],
    gapReason: "",
    omitNote,
    minutes: usable.reduce((sum, part) => sum + (part.minutes ?? 0), 0),
  };
  dish.gapReason = within ? "" : explainGap(target, dish);
  return dish;
}

function kcalOk(actual: number, target: number): boolean {
  return Math.abs(actual - target) <= Math.abs(target) * defaultTolerance.kcalRatio + 0.51;
}

function proteinRule(meal: MeasuredDish, listed: string[]): boolean {
  const listedProtein = listed.filter((name) => isListedProtein(name));
  if (listedProtein.length === 0) {
    return usesListed(meal.ingredients.map((item) => ({
      label: item.name,
      match: [item.name],
    } as CookOption)), listed);
  }
  return meal.ingredients.some((item) =>
    listedProtein.some((name) => namesMatch(item.name, name))
  ) && meal.ingredients.every((item) => {
    // 買い足し案で買う1〜2品は、手持ちに無くてよい。
    if (!isProteinItem(item.name) || item.assumed || item.extra) {
      return true;
    }
    return listedProtein.some((name) => namesMatch(item.name, name));
  });
}

function missedHard(meal: MeasuredDish, listed: string[]): number {
  const wanted = listed.filter((name) => isListedProtein(name) || isRice(name) || /うどん|そば|パスタ|パン|麺/.test(name));
  return wanted.filter((name) => !meal.ingredients.some((item) => namesMatch(item.name, name))).length;
}

function isListedProtein(name: string): boolean {
  return isProteinItem(name);
}

function isProteinItem(name: string): boolean {
  return isMeatFish(name) || isEgg(name) || name.includes("豆腐") || name.includes("納豆");
}

function usedCount(meal: MeasuredDish, listed: string[]): number {
  return listed.filter((name) => meal.ingredients.some((item) => namesMatch(item.name, name))).length;
}

export function expandRecipe(recipe: CookRecipe): Fill[] {
  return cartesian(recipe.slots.map((item) => item.options), 400).map((chosen) => ({
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
    const listedRice = listed.some((name) => namesMatch(name, "ごはん") || namesMatch(name, "ご飯"));
    const hasRice = chosen.some((option) => isRice(option.label));
    if (!usesListed(chosen, listed) && !chosen.every((option) => option.staple) && !(listedRice && !hasRice)) {
      continue;
    }
    out.push({ recipe, chosen, extras: unique });
    if (out.length >= 36) {
      break;
    }
  }
  return out;
}

function cartesian(groups: CookOption[][], max = 48): CookOption[][] {
  let rows: CookOption[][] = [[]];
  for (const group of groups) {
    const next: CookOption[][] = [];
    let stop = false;
    for (const row of rows) {
      for (const option of group) {
        next.push([...row, option]);
        if (next.length >= max) {
          stop = true;
          break;
        }
      }
      if (stop) {
        break;
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

// 食材名は部分一致させない（「玉ねぎ」で「ねぎ」が手持ちにならないように）。
// 成分表の別名と、この同義語の表で同じ食品にまとめ、正規化した名前の完全一致で比べる。
const extraSynonyms: Record<string, string[]> = {
  rice: ["白ごはん", "白ご飯", "ライス", "米"],
  onion: ["玉葱", "新玉ねぎ", "新たまねぎ"],
  negi: ["長ネギ", "白ねぎ", "白ネギ", "根深ねぎ"],
  carrot: ["ニンジン"],
  tomato: ["ミニトマト", "プチトマト"],
  chicken: ["鶏ムネ", "鶏ムネ肉", "むね肉", "胸肉"],
  pork: ["豚小間", "豚こま肉"],
  beef: ["牛小間", "牛こま切れ"],
  egg: ["生卵", "鶏卵"],
  tofu: ["もめん豆腐", "木綿"],
  kinu: ["きぬ豆腐", "絹ごし"],
  salmon: ["生鮭", "生さけ", "秋鮭"],
  cabbage: ["きゃべつ"],
  spinach: ["ほうれんそう"],
  shiitake: ["生しいたけ"],
  consomme: ["コンソメキューブ"],
};

const canonicalByName: Map<string, string> = (() => {
  const map = new Map<string, string>();
  for (const food of cookFoods) {
    for (const name of [food.label, ...food.match, ...(extraSynonyms[food.id] ?? [])]) {
      const key = normalizeFoodName(name);
      if (key && !map.has(key)) {
        map.set(key, food.id);
      }
    }
  }
  return map;
})();

/// 入力名や候補名を、同じ食品なら同じ値になる鍵にする。表に無い名前は正規化した名前のまま。
export function canonicalFood(name: string): string {
  const key = normalizeFoodName(name);
  if (!key) {
    return "";
  }
  const id = canonicalByName.get(key);
  return id ? `food:${id}` : `name:${key}`;
}

export function namesMatch(left: string, right: string): boolean {
  const a = canonicalFood(left);
  const b = canonicalFood(right);
  return a !== "" && a === b;
}

// 1食の中で、だしの素などの合計が家庭の量を超えないようにする（g）。
const mealSeasoningCaps: Array<{ name: string; max: number }> = [
  { name: "顆粒だし", max: 6 },
  { name: "コンソメ", max: 6 },
];

export function seasoningOverCap(ingredients: Array<{ name: string; grams: number }>): boolean {
  return mealSeasoningCaps.some((cap) =>
    ingredients.filter((item) => item.name === cap.name).reduce((sum, item) => sum + item.grams, 0) > cap.max
  );
}

function materialize(
  fill: Fill,
  body: number,
  staple: number,
  target: Macros,
  omitNote: string,
  listed: string[],
  oilScale = 1,
): MeasuredDish | null {
  const byKey = new Map<string, { option: CookOption; grams: number }>();
  const ingredients: MeasuredIngredient[] = [];
  for (let index = 0; index < fill.recipe.slots.length; index++) {
    const key = fill.recipe.slots[index].key;
    const option = fill.chosen[index];
    const roleScale = option.role === "staple"
      ? staple
      : option.role === "oil"
      ? oilScale
      : option.role === "seasoning"
      ? 1
      : body;
    const grams = scaledGrams(option, roleScale);
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
  const raw = option.grams * scale;
  if (isEgg(option.label)) {
    if (raw < option.grams * 0.45 || raw > option.grams * 2.05) {
      return null;
    }
    const choices = [50, 100, 150, 200];
    let grams = choices[0];
    for (const choice of choices) {
      if (Math.abs(choice - raw) < Math.abs(grams - raw)) {
        grams = choice;
      }
    }
    return gramsAreRealistic(option.label, grams) ? grams : null;
  }
  const minScale = option.role === "staple" ? 0.4 : option.role === "oil" ? 0.5 : option.role === "seasoning" ? 1 : 0.7;
  const maxScale = option.role === "staple"
    ? 1.55
    : option.role === "oil" || option.role === "seasoning"
    ? 1
    : option.role === "protein"
    ? 1.85
    : option.role === "veg"
    ? 1.45
    : 1.25;
  if (raw < option.grams * minScale - 0.01 || raw > option.grams * maxScale + 0.01) {
    return null;
  }
  const grams = Math.round(raw);
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
