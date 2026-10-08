// 手元の食材を現実的な分量に合わせ、足りなければスーパーの食材を1つか2つ足す。
// 料理名の一覧は持たない。名前と手順は、決まった材料と火加減から組み立てる。

import {
  appendPantryStaples,
  categoryPer100,
  defaultTolerance,
  gramsAreRealistic,
  isEgg,
  isMeatFish,
  isOil,
  isPotato,
  isRice,
  isSeasoning,
  isVeg,
  matchFood,
  nutritionAtGrams,
  optimizeIngredients,
  presentDish,
  realismIssues,
  withGapReason,
  type AiDish,
  type FoodRow,
  type Macros,
  type MeasuredDish,
  type MeasuredIngredient,
} from "./match.ts";

type Closer = { name: string; per100: Macros };

export const gapClosers: Closer[] = [
  { name: "鶏むね肉", per100: { kcal: 108, proteinG: 24, fatG: 1.5, carbG: 0 } },
  { name: "卵", per100: { kcal: 151, proteinG: 12.3, fatG: 10.3, carbG: 0.3 } },
  { name: "木綿豆腐", per100: { kcal: 73, proteinG: 6.6, fatG: 4.2, carbG: 2 } },
  { name: "ごはん", per100: { kcal: 168, proteinG: 2.5, fatG: 0.3, carbG: 37.1 } },
  { name: "じゃがいも", per100: { kcal: 76, proteinG: 1.6, fatG: 0.1, carbG: 17.6 } },
  { name: "キャベツ", per100: { kcal: 23, proteinG: 1.3, fatG: 0.2, carbG: 5.2 } },
  { name: "玉ねぎ", per100: { kcal: 37, proteinG: 1, fatG: 0.1, carbG: 8.8 } },
  { name: "鮭", per100: { kcal: 133, proteinG: 22.3, fatG: 4.1, carbG: 0.1 } },
  { name: "豚こま切れ", per100: { kcal: 221, proteinG: 18.2, fatG: 16, carbG: 0.2 } },
];

export const gapCloserNames = gapClosers.map((item) => item.name);

const sweetWords = ["チョコ", "ケーキ", "クッキー", "アイス", "大福", "あんこ"];
const savoryWords = ["肉", "魚", "鮭", "鶏", "豚", "牛", "納豆", "刺身"];

export function splitIncompatible(names: string[]): { keep: string[]; dropped: string[] } {
  const sweet = names.filter((name) => sweetWords.some((word) => name.includes(word)));
  const savory = names.filter((name) => savoryWords.some((word) => name.includes(word)));
  if (sweet.length === 0 || savory.length === 0) {
    return { keep: names.slice(), dropped: [] };
  }
  return {
    keep: names.filter((name) => !sweet.includes(name)),
    dropped: sweet,
  };
}

export function nameMismatch(name: string, items: { name: string }[]): boolean {
  const claims: Array<{ pattern: RegExp; ok: (rows: { name: string }[]) => boolean }> = [
    { pattern: /カレー/, ok: (rows) => rows.some((item) => item.name.includes("カレー")) },
    { pattern: /丼/, ok: (rows) => rows.some((item) => isRice(item.name)) },
    { pattern: /卵|たまご|オムレツ/, ok: (rows) => rows.some((item) => isEgg(item.name)) },
    { pattern: /豆腐/, ok: (rows) => rows.some((item) => item.name.includes("豆腐")) },
    { pattern: /野菜/, ok: (rows) => rows.some((item) => isVeg(item.name)) },
    { pattern: /鶏/, ok: (rows) => rows.some((item) => item.name.includes("鶏")) },
    { pattern: /豚/, ok: (rows) => rows.some((item) => item.name.includes("豚")) },
    { pattern: /牛/, ok: (rows) => rows.some((item) => item.name.includes("牛")) },
    { pattern: /鮭|さけ|サーモン/, ok: (rows) => rows.some((item) => /鮭|さけ|サーモン/.test(item.name)) },
    { pattern: /魚/, ok: (rows) => rows.some((item) => /魚|鮭|さけ|ぶり|さば|あじ|いわし|まぐろ/.test(item.name)) },
    { pattern: /玉ねぎ|たまねぎ/, ok: (rows) => rows.some((item) => item.name.includes("玉ねぎ") || item.name.includes("たまねぎ")) },
    { pattern: /トマト/, ok: (rows) => rows.some((item) => item.name.includes("トマト")) },
    { pattern: /納豆/, ok: (rows) => rows.some((item) => item.name.includes("納豆")) },
  ];
  return claims.some((claim) => claim.pattern.test(name) && !claim.ok(items));
}

export function stepIssues(
  steps: string[],
  items: { name: string; grams: number }[],
): string[] {
  const issues: string[] = [];
  if (steps.length < 3 || steps.length > 6) {
    issues.push("count");
  }
  const text = steps.join("\n");
  if (!/\d+\s*分/.test(text) && !/\d+\s*秒/.test(text)) {
    issues.push("time");
  }
  if (!/(フライパン|鍋|電子レンジ|炊飯器|焼く|煮る|炒める|蒸す|ゆで|茹で)/.test(text)) {
    issues.push("heat");
  }
  const taste = items.filter((item) => item.grams >= 1 && isSeasoning(item.name) && !isOil(item.name));
  if (taste.length > 0 && !taste.some((item) => text.includes(item.name))) {
    issues.push("seasoning");
  }
  if (steps.length === 0 || steps.every((step) => step.length < 8)) {
    issues.push("trivial");
  }
  return issues;
}

export function needsModelRetry(dishes: MeasuredDish[]): boolean {
  if (dishes.some((dish) =>
    dish.issues.length > 0 ||
    nameMismatch(dish.name, dish.ingredients) ||
    stepIssues(dish.steps, dish.ingredients).length > 0
  )) {
    return true;
  }
  return dishes.length > 0 && dishes.every((dish) => !dish.within);
}

export function composeHomeDish(
  items: MeasuredIngredient[],
  slot: string,
  variant: 0 | 1,
): { name: string; steps: string[] } {
  const used = items.filter((item) => item.grams >= 1);
  const protein = used.find((item) => isMeatFish(item.name));
  const egg = used.find((item) => isEgg(item.name));
  const tofu = used.find((item) => item.name.includes("豆腐"));
  const rice = used.find((item) => isRice(item.name));
  const veg = used.find((item) => isVeg(item.name));
  const oil = used.find((item) => isOil(item.name) && item.grams >= 1);
  const soy = used.find((item) => item.name.includes("しょうゆ") || item.name.includes("醤油"));
  const mirin = used.find((item) => item.name.includes("みりん"));
  const sugar = used.find((item) => item.name.includes("砂糖"));
  const salt = used.find((item) => item.name === "塩" || item.name.includes("食塩"));
  const main = protein ?? egg ?? tofu ?? veg;
  const teriyaki = Boolean((protein || tofu) && soy && mirin);
  const don = Boolean(rice && main);
  let method = "炒め";
  if (variant === 1) {
    method = teriyaki ? "煮びたし" : "煮";
  } else if (teriyaki && don) {
    method = "照り焼き丼";
  } else if (teriyaki) {
    method = "照り焼き";
  } else if (don && (oil || veg)) {
    method = "炒め丼";
  } else if (don) {
    method = "丼";
  } else if (egg && !protein && !tofu) {
    method = "焼き";
  }
  if (slot === "snack" && method.includes("丼")) {
    method = "炒め";
  }
  if (slot === "breakfast" && method === "煮") {
    method = "炒め";
  }
  const onlyDrink = !protein && !egg && !tofu && !veg && !rice &&
    used.some((item) => item.name.includes("牛乳"));
  if (onlyDrink) {
    const milk = used.find((item) => item.name.includes("牛乳"));
    const milkTastes = [soy, mirin, sugar, salt].filter((item): item is MeasuredIngredient =>
      Boolean(item && item.grams >= 1)
    );
    const milkSeason = milkTastes.length > 0
      ? `${milkTastes.map((item) => `${item.name}${item.grams}g`).join("と")}を溶かす`
      : "そのまま飲む";
    return {
      name: "牛乳の温め",
      steps: [
        `牛乳${milk?.grams ?? 150}gをマグカップに注ぐ`,
        "電子レンジで600W・1分温める",
        `${milkSeason}。熱ければ30秒置いてから飲む`,
      ],
    };
  }
  const head = [protein?.name, !protein ? egg?.name : null, tofu?.name, veg?.name]
    .filter((name): name is string => Boolean(name));
  const unique = [...new Set(head)].slice(0, 2);
  const fallback = used.find((item) => item.grams >= 1 && !isSeasoning(item.name) && !isOil(item.name));
  const title = unique.length > 0 ? unique.join("と") : (fallback?.name ?? rice?.name ?? "一品");
  const name = `${title}の${method}`;
  const prep: string[] = [];
  if (protein) {
    prep.push(`${protein.name}${protein.grams}gを一口大に切る`);
  }
  if (egg) {
    prep.push(`卵${egg.grams / 50}個（${egg.grams}g）を溶いておく`);
  }
  if (tofu) {
    prep.push(`${tofu.name}${tofu.grams}gを2cm角に切る`);
  }
  if (veg) {
    prep.push(`${veg.name}${veg.grams}gを食べやすく切る`);
  }
  if (prep.length === 0) {
    prep.push(rice ? `ごはん${rice.grams}gを器に用意する` : "材料を量ってそろえる");
  }
  const heatOil = oil ? `${oil.name}${oil.grams}gを熱し、` : "";
  const mainName = main?.name ?? fallback?.name ?? "材料";
  const cook = onlyDrink
    ? `牛乳${used.find((item) => item.name.includes("牛乳"))?.grams ?? 150}gをマグカップに入れ、電子レンジで600W・1分温める`
    : method === "煮" || method === "煮びたし"
    ? `鍋を中火にし、${heatOil}${mainName}を4分加熱する`
    : `フライパンを中火にし、${heatOil}${mainName}を3分ずつ焼く`;
  const tastes = [soy, mirin, sugar, salt].filter((item): item is MeasuredIngredient =>
    Boolean(item && item.grams >= 1)
  );
  const tasteText = tastes.length > 0
    ? tastes.map((item) => `${item.name}${item.grams}g`).join("と")
    : "塩1g";
  const season = veg
    ? `${veg.name}を加えて2分炒め、${tasteText}を絡めて1分火を通す`
    : `${tasteText}を加えて1分絡め、中まで火を通す`;
  let plate = "器に盛り、すぐ出す";
  if (rice) {
    const when = slot === "breakfast"
      ? "朝食として"
      : slot === "lunch"
      ? "昼食として"
      : slot === "snack"
      ? "軽めに"
      : "夕食として";
    plate = `${when}、ごはん${rice.grams}gを盛ってのせる`;
  } else if (slot === "snack") {
    plate = "小皿に盛り、すぐ出す";
  }
  const steps = [prep.join("。"), cook, season, plate].slice(0, 6);
  return { name, steps };
}

function saltRow(): MeasuredIngredient {
  return {
    name: "塩",
    grams: 1,
    originalGrams: 1,
    kcal: 0,
    proteinG: 0,
    fatG: 0,
    carbG: 0,
    source: "ai",
    foodCode: null,
    officialName: null,
    extra: false,
  };
}

function needsSalt(items: MeasuredIngredient[]): boolean {
  const food = items.some((item) => item.grams >= 1 && !isSeasoning(item.name) && !isOil(item.name));
  const seasoned = items.some((item) => item.grams >= 1 && isSeasoning(item.name));
  return food && !seasoned;
}

export function polishDish(
  dish: MeasuredDish,
  slot: string,
  target: Macros,
  variant: 0 | 1,
): MeasuredDish {
  let items = dish.ingredients.filter((item) => item.grams >= 1 && !rareName(item.name));
  if (needsSalt(items)) {
    if (items.length >= 8) {
      const index = items.findLastIndex((item) =>
        !isMeatFish(item.name) && !isRice(item.name) && !isEgg(item.name) &&
        !isSeasoning(item.name) && !item.name.includes("豆腐")
      );
      if (index >= 0) {
        items = items.filter((_, at) => at !== index);
      }
    }
    if (items.length < 8) {
      items = [...items, saltRow()];
    }
  }
  const saltMissing = items.some((item) => item.name === "塩") &&
    !dish.steps.some((step) => step.includes("塩"));
  const originalBad = dish.name === "家庭の一品" ||
    nameMismatch(dish.name, items) ||
    stepIssues(dish.steps, items).length > 0 ||
    dish.issues.length > 0 ||
    saltMissing;
  const composed = composeHomeDish(items, slot, variant);
  const name = originalBad ? composed.name : dish.name;
  const steps = originalBad ? composed.steps : dish.steps;
  const shell: AiDish = { name, steps, extras: dish.extras, ingredients: [] };
  const next = withGapReason(
    presentDish(shell, items, target, defaultTolerance, ""),
    target,
  );
  return {
    ...next,
    extras: dish.extras.filter((name) => items.some((item) => item.name === name)),
    omitNote: dish.omitNote,
    issues: realismIssues(shell, ""),
  };
}

function rareName(name: string): boolean {
  return realismIssues({
    name: "確認",
    steps: ["フライパンで4分焼く"],
    extras: [],
    ingredients: [{ name, grams: 10, kcal: 1, proteinG: 0, fatG: 0, carbG: 0 }],
  }).includes("rare");
}

function startGrams(name: string): number {
  if (isEgg(name)) {
    return 50;
  }
  if (isRice(name)) {
    return 150;
  }
  if (isMeatFish(name)) {
    return 100;
  }
  if (name.includes("豆腐")) {
    return 150;
  }
  if (isVeg(name)) {
    return 80;
  }
  return 40;
}

export function initialItems(names: string[], foods: FoodRow[]): MeasuredIngredient[] {
  const items: MeasuredIngredient[] = [];
  for (const name of names) {
    if (rareName(name)) {
      continue;
    }
    const grams = startGrams(name);
    const food = matchFood(name, foods);
    const fromDb = food ? nutritionAtGrams(food, grams) : null;
    if (food && fromDb) {
      items.push({
        name,
        grams,
        originalGrams: grams,
        kcal: fromDb.kcal,
        proteinG: fromDb.proteinG,
        fatG: fromDb.fatG,
        carbG: fromDb.carbG,
        source: "db",
        foodCode: food.foodCode,
        officialName: food.displayName || food.name,
        extra: false,
      });
      continue;
    }
    const guess = categoryPer100(name) ?? { kcal: 40, proteinG: 2, fatG: 1, carbG: 6 };
    const scale = grams / 100;
    items.push({
      name,
      grams,
      originalGrams: grams,
      kcal: guess.kcal * scale,
      proteinG: guess.proteinG * scale,
      fatG: guess.fatG * scale,
      carbG: guess.carbG * scale,
      source: "ai",
      foodCode: null,
      officialName: null,
      extra: false,
    });
  }
  return items;
}

function closerItem(name: string, foods: FoodRow[]): MeasuredIngredient {
  const spec = gapClosers.find((item) => item.name === name)!;
  const grams = startGrams(name);
  const food = matchFood(name, foods);
  const fromDb = food ? nutritionAtGrams(food, grams) : null;
  const per = fromDb ?? {
    kcal: spec.per100.kcal * grams / 100,
    proteinG: spec.per100.proteinG * grams / 100,
    fatG: spec.per100.fatG * grams / 100,
    carbG: spec.per100.carbG * grams / 100,
  };
  return {
    name,
    grams,
    originalGrams: grams,
    kcal: per.kcal,
    proteinG: per.proteinG,
    fatG: per.fatG,
    carbG: per.carbG,
    source: food && fromDb ? "db" : "ai",
    foodCode: food?.foodCode ?? null,
    officialName: food ? (food.displayName || food.name) : null,
    extra: true,
  };
}

function already(items: MeasuredIngredient[], name: string): boolean {
  return items.some((item) => item.name === name || item.name.includes(name) || name.includes(item.name));
}

function roleRank(item: MeasuredIngredient): number {
  if (isMeatFish(item.name) || isEgg(item.name) || item.name.includes("豆腐") || item.name.includes("納豆")) {
    return 0;
  }
  if (isRice(item.name)) {
    return 1;
  }
  if (isVeg(item.name)) {
    return 2;
  }
  if (isSeasoning(item.name) || isOil(item.name)) {
    return 5;
  }
  return 3;
}

function trimForRoom(items: MeasuredIngredient[], reserve: number): MeasuredIngredient[] {
  const limit = Math.max(1, 8 - reserve);
  if (items.length <= limit) {
    return items;
  }
  return [...items].sort((a, b) => roleRank(a) - roleRank(b)).slice(0, limit);
}

function cookFrom(
  items: MeasuredIngredient[],
  foods: FoodRow[],
  target: Macros,
  avoid: string[],
  note: string,
  extras: string[],
): MeasuredDish {
  const expanded = appendPantryStaples(trimForRoom(items, 3), foods, avoid);
  const optimized = optimizeIngredients(expanded, target);
  const shell: AiDish = {
    name: "家庭の一品",
    steps: [
      "材料を食べやすく切っておく",
      "フライパンを中火で4分加熱する",
      "塩1gを振って味を整える",
    ],
    extras,
    ingredients: [],
  };
  const dish = withGapReason(presentDish(shell, optimized, target, defaultTolerance, note), target);
  return { ...dish, extras };
}

function hasProtein(dish: MeasuredDish): boolean {
  return dish.ingredients.some((item) =>
    isMeatFish(item.name) || isEgg(item.name) || item.name.includes("豆腐") || item.name.includes("納豆")
  );
}

function hasVeg(dish: MeasuredDish): boolean {
  return dish.ingredients.some((item) => isVeg(item.name));
}

function unrealisticGrams(dish: MeasuredDish): boolean {
  return dish.ingredients.some((item) => !gramsAreRealistic(item.name, item.grams));
}

function rankDish(dish: MeasuredDish, added: string[], target: Macros, differFrom: MeasuredDish | null): number {
  let rank = dish.within ? dish.score : 1e15 + dish.score;
  if (!dish.within) {
    return rank;
  }
  if (unrealisticGrams(dish)) {
    rank += 1e12;
  }
  if (target.kcal >= 400 && !hasVeg(dish)) {
    rank += 6000;
  }
  if (target.kcal >= 300 && !hasProtein(dish)) {
    rank += 6000;
  }
  rank += added.length * 15;
  if (dish.ingredients.filter((item) => isMeatFish(item.name)).length >= 2) {
    rank += 9000;
  }
  if (differFrom && foodKey(dish) === foodKey(differFrom)) {
    rank += 40000;
  }
  return rank;
}

export function foodKey(dish: MeasuredDish): string {
  return dish.ingredients
    .filter((item) => item.grams >= 1 && !isSeasoning(item.name) && !isOil(item.name))
    .map((item) => item.name)
    .sort()
    .join("|");
}

export function closeWithAdditions(
  base: MeasuredIngredient[],
  foods: FoodRow[],
  target: Macros,
  avoid: string[],
  note = "",
  options: { mustAdd?: boolean; differFrom?: MeasuredDish | null } = {},
): MeasuredDish {
  const pool = gapClosers.filter((item) =>
    !avoid.some((word) => item.name.includes(word) || word.includes(item.name)) &&
    !already(base, item.name)
  );
  const combos: string[][] = options.mustAdd ? [] : [[]];
  for (const one of pool) {
    combos.push([one.name]);
  }
  for (let i = 0; i < pool.length; i++) {
    for (let j = i + 1; j < pool.length; j++) {
      combos.push([pool[i].name, pool[j].name]);
    }
  }
  if (combos.length === 0) {
    combos.push([]);
  }
  let best: MeasuredDish | null = null;
  let bestRank = Number.POSITIVE_INFINITY;
  for (const added of combos) {
    const withAdds = [
      ...trimForRoom(base, added.length + 3),
      ...added.map((name) => closerItem(name, foods)),
    ];
    const dish = cookFrom(withAdds, foods, target, avoid, note, added);
    const rank = rankDish(dish, added, target, options.differFrom ?? null);
    if (rank < bestRank) {
      bestRank = rank;
      best = dish;
    }
  }
  return best ?? cookFrom(base, foods, target, avoid, note, []);
}

export function finalizePair(args: {
  onHand: MeasuredDish;
  extra: MeasuredDish;
  foods: FoodRow[];
  target: Macros;
  avoid: string[];
  slot: string;
  note: string;
  userIngredients: string[];
}): { a: MeasuredDish; b: MeasuredDish } {
  const split = splitIncompatible(args.userIngredients.filter((name) => !rareName(name)));
  const droppedRare = args.userIngredients.filter((name) => rareName(name));
  const dropped = [...split.dropped, ...droppedRare];
  const base = initialItems(split.keep, args.foods);
  const fittedA = cookFrom(base, args.foods, args.target, args.avoid, args.note, []);
  const blocked = (dish: MeasuredDish) =>
    dish.ingredients.some((item) => dropped.some((name) => item.name.includes(name) || name.includes(item.name)));
  let a = fittedA;
  if (
    args.onHand.issues.length === 0 && args.onHand.within &&
    args.onHand.name !== "家庭の一品" &&
    !nameMismatch(args.onHand.name, args.onHand.ingredients) && !blocked(args.onHand)
  ) {
    a = args.onHand;
  } else if (args.onHand.issues.length === 0 && !blocked(args.onHand)) {
    a = preferHome(args.onHand, fittedA);
  }
  let b = closeWithAdditions(base, args.foods, args.target, args.avoid, args.note, {
    differFrom: a,
  });
  if (!b.within) {
    b = closeWithAdditions(base, args.foods, args.target, args.avoid, args.note, {
      mustAdd: true,
      differFrom: a,
    });
  }
  if (foodKey(a) === foodKey(b)) {
    const alt = closeWithAdditions(base, args.foods, args.target, args.avoid, args.note, {
      mustAdd: true,
      differFrom: a,
    });
    if (alt.within) {
      b = alt;
    }
  }
  const same = foodKey(a) === foodKey(b);
  a = polishDish(a, args.slot, args.target, 0);
  b = polishDish(b, args.slot, args.target, same ? 1 : 0);
  if (a.name === b.name) {
    const alt = composeHomeDish(b.ingredients, args.slot, 1);
    b = { ...b, name: alt.name, steps: alt.steps };
  }
  const omitNote = dropped.length > 0
    ? `${dropped.join("、")}は、この食事には一緒にしないので入れませんでした。`
    : "";
  if (omitNote) {
    a = { ...a, omitNote };
    b = { ...b, omitNote };
  }
  return { a, b };
}

function preferHome(current: MeasuredDish, next: MeasuredDish): MeasuredDish {
  if (next.within && !current.within) {
    return next;
  }
  if (current.within && !next.within) {
    return current;
  }
  if (unrealisticGrams(current) && !unrealisticGrams(next)) {
    return next;
  }
  return next.score < current.score ? next : current;
}
