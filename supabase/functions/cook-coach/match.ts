// 自炊コーチの突き合わせ、分量の最適化、家庭料理のチェック、再試行の判断。
// モデルもデータベースも呼ばない。

export type Macros = {
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
};

export type FoodAlias = {
  normalized: string;
  candidate: boolean;
};

export type FoodRow = {
  foodCode: string;
  name: string;
  displayName: string;
  normalizedName: string;
  aliases: FoodAlias[];
  kcal: number | null;
  proteinG: number | null;
  fatG: number | null;
  carbG: number | null;
  baseAmount: number;
};

export type AiIngredient = {
  name: string;
  grams: number;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
};

export type AiDish = {
  name: string;
  steps: string[];
  extras: string[];
  ingredients: AiIngredient[];
};

export type MeasuredIngredient = {
  name: string;
  grams: number;
  originalGrams: number;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  source: "db" | "ai";
  foodCode: string | null;
  officialName: string | null;
  extra: boolean;
  assumed?: boolean;
};

export type MeasuredDish = {
  name: string;
  steps: string[];
  extras: string[];
  ingredients: MeasuredIngredient[];
  totals: Macros;
  gap: Macros;
  within: boolean;
  score: number;
  issues: string[];
  gapReason: string;
  omitNote: string;
  minutes?: number;
};

export type Tolerance = {
  kcalRatio: number;
  macroAbs: number;
  macroRatio: number;
};

// kcal は目標の ±10%。P/F/C は ±15% と ±5g の広い方。
export const defaultTolerance: Tolerance = {
  kcalRatio: 0.10,
  macroAbs: 5,
  macroRatio: 0.15,
};

const cookSuffixes = ["ゆで", "茹で", "焼き", "蒸し", "煮", "生"];

export function normalizeFoodName(raw: string): string {
  const composed = composeHalfwidthVoiced(raw);
  let out = "";
  for (const ch of composed) {
    let code = ch.codePointAt(0) ?? 0;
    if (code >= 0xFF01 && code <= 0xFF5E) {
      code -= 0xFEE0;
    } else if (code === 0x3000) {
      code = 0x20;
    } else {
      const mapped = halfwidthKatakana(code);
      if (mapped != null) {
        code = mapped;
      }
    }
    if (code >= 0x30A1 && code <= 0x30F6) {
      code -= 0x60;
    }
    if (code >= 0x41 && code <= 0x5A) {
      code += 0x20;
    }
    if (isLongVowelOrHyphen(code) || isWhitespace(code)) {
      continue;
    }
    out += String.fromCodePoint(code);
  }
  return out;
}

export function stripCookSuffix(normalized: string): string {
  for (const suffix of cookSuffixes) {
    const key = normalizeFoodName(suffix);
    if (normalized.length > key.length + 1 && normalized.endsWith(key)) {
      return normalized.slice(0, -key.length);
    }
  }
  return normalized;
}

export function sumMacros(items: Macros[]): Macros {
  const totals = { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 };
  for (const item of items) {
    totals.kcal += item.kcal;
    totals.proteinG += item.proteinG;
    totals.fatG += item.fatG;
    totals.carbG += item.carbG;
  }
  return totals;
}

export function gapOf(target: Macros, actual: Macros): Macros {
  return {
    kcal: target.kcal - actual.kcal,
    proteinG: target.proteinG - actual.proteinG,
    fatG: target.fatG - actual.fatG,
    carbG: target.carbG - actual.carbG,
  };
}

export function gapScore(target: Macros, actual: Macros): number {
  const gap = gapOf(target, actual);
  const protein = gap.proteinG * 4;
  const fat = gap.fatG * 9;
  const carb = gap.carbG * 4;
  return gap.kcal * gap.kcal + protein * protein + fat * fat + carb * carb;
}

export function withinTolerance(
  target: Macros,
  actual: Macros,
  tolerance: Tolerance = defaultTolerance,
): boolean {
  return closeKcal(actual.kcal, target.kcal, tolerance.kcalRatio) &&
    closeMacro(actual.proteinG, target.proteinG, tolerance) &&
    closeMacro(actual.fatG, target.fatG, tolerance) &&
    closeMacro(actual.carbG, target.carbG, tolerance);
}

function closeKcal(actual: number, target: number, ratio: number): boolean {
  return Math.abs(actual - target) <= Math.abs(target) * ratio + 0.51;
}

function closeMacro(actual: number, target: number, tolerance: Tolerance): boolean {
  const limit = Math.max(tolerance.macroAbs, Math.abs(target) * tolerance.macroRatio);
  return Math.abs(actual - target) <= limit + 0.05;
}

export function matchFood(query: string, foods: FoodRow[]): FoodRow | null {
  const normalized = normalizeFoodName(query);
  if (!normalized || foods.length === 0) {
    return null;
  }
  const stem = stripCookSuffix(normalized);
  let best: FoodRow | null = null;
  let bestScore = 0;
  for (const food of foods) {
    if (food.kcal == null || !(food.baseAmount > 0)) {
      continue;
    }
    const score = matchScore(normalized, stem, food);
    if (score > bestScore) {
      best = food;
      bestScore = score;
    }
  }
  return bestScore >= 60 ? best : null;
}

function matchScore(query: string, stem: string, food: FoodRow): number {
  const names = [food.normalizedName, ...food.aliases.map((alias) => alias.normalized)]
    .filter((name) => name.length > 0);
  const exact = names.some((name) => name === query);
  if (exact) {
    const candidateOnly = food.aliases.some((alias) => alias.normalized === query && alias.candidate) &&
      food.normalizedName !== query &&
      !food.aliases.some((alias) => alias.normalized === query && !alias.candidate);
    return candidateOnly ? 95 : 100;
  }
  if (stem !== query && names.some((name) => name === stem || stripCookSuffix(name) === stem)) {
    return 90;
  }
  let contains = 0;
  for (const name of names) {
    if (name.length < 2 || query.length < 2) {
      continue;
    }
    const hit = name.includes(query) || query.includes(name);
    if (!hit) {
      continue;
    }
    const shorter = Math.min(name.length, query.length);
    const longer = Math.max(name.length, query.length);
    if (shorter / longer < 0.5) {
      continue;
    }
    contains = Math.max(contains, 60 + Math.round((shorter / longer) * 20));
  }
  return contains;
}

export function nutritionAtGrams(food: FoodRow, grams: number): Macros | null {
  if (food.kcal == null || !(food.baseAmount > 0) || !(grams > 0)) {
    return null;
  }
  const scale = grams / food.baseAmount;
  return {
    kcal: food.kcal * scale,
    proteinG: (food.proteinG ?? 0) * scale,
    fatG: (food.fatG ?? 0) * scale,
    carbG: (food.carbG ?? 0) * scale,
  };
}

export function measureIngredients(
  dish: AiDish,
  foods: FoodRow[],
): MeasuredIngredient[] {
  const extras = new Set(dish.extras.map((name) => normalizeFoodName(name)));
  return dish.ingredients.map((item) => {
    const extra = extras.has(normalizeFoodName(item.name));
    const food = matchFood(item.name, foods);
    const fromDb = food ? nutritionAtGrams(food, item.grams) : null;
    if (!food || !fromDb) {
      const guessed = plausibleOrEstimate(item);
      return {
        name: item.name,
        grams: item.grams,
        originalGrams: item.grams,
        kcal: guessed.kcal,
        proteinG: guessed.proteinG,
        fatG: guessed.fatG,
        carbG: guessed.carbG,
        source: "ai",
        foodCode: null,
        officialName: null,
        extra,
      };
    }
    return {
      name: item.name,
      grams: item.grams,
      originalGrams: item.grams,
      kcal: fromDb.kcal,
      proteinG: fromDb.proteinG,
      fatG: fromDb.fatG,
      carbG: fromDb.carbG,
      source: "db",
      foodCode: food.foodCode,
      officialName: food.displayName || food.name,
      extra,
    };
  });
}

export type GramWindow = { min: number; max: number };

export function realisticGramBounds(name: string, suggested: number): GramWindow {
  const optional = !(suggested > 0);
  let min = 20;
  let max = 180;
  if (name.includes("油揚げ") || name.includes("がんも")) {
    min = 20;
    max = 80;
  } else if (isEgg(name)) {
    min = 50;
    max = 200;
  } else if (isSalt(name)) {
    min = 0;
    max = 3;
  } else if (isOil(name)) {
    min = 0;
    max = 15;
  } else if (isSugar(name)) {
    min = 0;
    max = 12;
  } else if (isSeasoning(name)) {
    min = 0;
    max = 18;
  } else if (isRice(name)) {
    min = 100;
    max = 300;
  } else if (isBread(name)) {
    min = 60;
    max = 180;
  } else if (isNoodle(name)) {
    min = 100;
    max = 250;
  } else if (name.includes("オートミール")) {
    min = 30;
    max = 80;
  } else if (name.includes("納豆")) {
    min = 40;
    max = 100;
  } else if (name.includes("豆腐")) {
    min = 100;
    max = 250;
  } else if (isMeatFish(name)) {
    min = 60;
    max = 250;
  } else if (isPotato(name)) {
    min = 50;
    max = 200;
  } else if (isVeg(name)) {
    min = 40;
    max = 200;
  }
  if (optional) {
    min = 0;
  }
  return { min, max: Math.max(min, max) };
}

export function gramsAreRealistic(name: string, grams: number): boolean {
  if (!(grams >= 1)) {
    return true;
  }
  if (isEgg(name)) {
    return grams % 50 === 0 && grams >= 50 && grams <= 200;
  }
  const bounds = realisticGramBounds(name, grams);
  return grams + 1e-6 >= bounds.min && grams <= bounds.max + 1e-6;
}

type PantryStaple = {
  name: string;
  per100: Macros;
};

// 家にある前提。利用者が避けたものだけ外す。パターンAにも入れる。
export const pantryStaples: PantryStaple[] = [
  { name: "サラダ油", per100: { kcal: 921, proteinG: 0, fatG: 100, carbG: 0 } },
  { name: "しょうゆ", per100: { kcal: 71, proteinG: 8, fatG: 0, carbG: 8 } },
  { name: "みりん", per100: { kcal: 241, proteinG: 0.1, fatG: 0, carbG: 43 } },
  { name: "砂糖", per100: { kcal: 386, proteinG: 0, fatG: 0, carbG: 100 } },
  { name: "塩", per100: { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 } },
];

export const pantryStapleNames = pantryStaples.map((item) => item.name);

const maxDishIngredients = 8;

export function appendPantryStaples(
  items: MeasuredIngredient[],
  foods: FoodRow[],
  avoid: string[] = [],
): MeasuredIngredient[] {
  const next = items.slice();
  for (const staple of pantryStaples) {
    if (next.length >= maxDishIngredients) {
      break;
    }
    if (next.some((item) => stapleAlreadyPresent(item.name, staple.name))) {
      continue;
    }
    if (avoid.some((item) => stapleAlreadyPresent(item, staple.name))) {
      continue;
    }
    const food = matchFood(staple.name, foods);
    const per100 = food ? nutritionAtGrams(food, 100) : staple.per100;
    if (!per100) {
      continue;
    }
    next.push({
      name: staple.name,
      grams: 0,
      originalGrams: 0,
      kcal: per100.kcal / 100,
      proteinG: per100.proteinG / 100,
      fatG: per100.fatG / 100,
      carbG: per100.carbG / 100,
      source: food ? "db" : "ai",
      foodCode: food?.foodCode ?? null,
      officialName: food ? (food.displayName || food.name) : null,
      extra: false,
    });
  }
  return next;
}

function stapleAlreadyPresent(name: string, staple: string): boolean {
  if (staple === "サラダ油") {
    if (name.includes("醤油") || name.includes("しょうゆ") || name.includes("油揚げ")) {
      return false;
    }
    return name.includes("油") || name.includes("オイル");
  }
  if (staple === "しょうゆ") {
    return name.includes("しょうゆ") || name.includes("醤油");
  }
  if (staple === "塩") {
    return name === "塩" || name.includes("食塩");
  }
  return name.includes(staple);
}

type Rates = { kcal: number; proteinG: number; fatG: number; carbG: number };

export function optimizeIngredients(
  items: MeasuredIngredient[],
  target: Macros,
): MeasuredIngredient[] {
  if (items.length === 0) {
    return items;
  }
  const bounds = items.map((item) => realisticGramBounds(item.name, item.originalGrams));
  const rates = items.map(ratesOf);
  const names = items.map((item) => item.name);
  const suggested = items.map((item, index) =>
    clamp(item.grams, bounds[index].min, bounds[index].max)
  );
  const fromSuggested = descend(suggested, names, rates, bounds, target);
  const fromKcal = descend(kcalStart(suggested, rates, bounds, target), names, rates, bounds, target);
  const chosen = gapScore(target, totalsAt(fromSuggested, rates)) <=
      gapScore(target, totalsAt(fromKcal, rates))
    ? fromSuggested
    : fromKcal;
  return items.map((item, index) => applyGrams(item, rates[index], chosen[index]));
}

export function scaleIngredients(
  items: MeasuredIngredient[],
  target: Macros,
): MeasuredIngredient[] {
  return optimizeIngredients(items, target);
}

const rareIngredients = [
  "トリュフ",
  "フォアグラ",
  "キャビア",
  "ふぐ",
  "河豚",
  "フグ",
  "松茸",
  "まつたけ",
  "伊勢海老",
  "伊勢えび",
  "アワビ",
  "あわび",
  "うに",
  "雲丹",
  "サフラン",
  "ツバメの巣",
  "分子調理",
];

const techniqueNeedles = [
  "揚げる",
  "天ぷら",
  "てんぷら",
  "唐揚",
  "から揚",
  "素揚",
  "とんかつ",
  "トンカツ",
  "カツレツ",
  "カツ",
  "フライ",
  "真空調理",
  "低温調理",
  "スービッド",
  "sous-vide",
  "sous vide",
  "コンフィ",
  "フライヤー",
  "揚げ物",
  "揚げ",
];

export function techniqueHits(text: string): boolean {
  const scrubbed = text
    .toLowerCase()
    .replaceAll("フライパン", "")
    .replaceAll("カツオ", "")
    .replaceAll("かつお", "")
    .replaceAll("油揚げ", "")
    .replaceAll("あぶらあげ", "")
    .replaceAll("がんもどき", "")
    .replaceAll("がんも", "");
  return techniqueNeedles.some((word) => scrubbed.includes(word.toLowerCase()));
}

export function cookingMinutes(text: string): number {
  let max = 0;
  for (const match of text.matchAll(/(\d+)\s*時間/g)) {
    max = Math.max(max, Number(match[1]) * 60);
  }
  for (const match of text.matchAll(/(\d+)\s*分/g)) {
    max = Math.max(max, Number(match[1]));
  }
  return max;
}

export function allowedMinutes(note: string): number {
  const asked = cookingMinutes(note);
  return asked > 0 ? asked : 30;
}

export function realismIssues(dish: AiDish, note = ""): string[] {
  const issues: string[] = [];
  if (dish.ingredients.length > 8) {
    issues.push("too_many");
  }
  const steps = `${dish.name}\n${dish.steps.join("\n")}`;
  if (techniqueHits(steps) || dish.ingredients.some((item) => techniqueHits(item.name))) {
    issues.push("technique");
  }
  if (dish.ingredients.some((item) => rareIngredients.some((word) => item.name.includes(word)))) {
    issues.push("rare");
  }
  if (cookingMinutes(steps) > allowedMinutes(note)) {
    issues.push("time");
  }
  return issues;
}

export function presentDish(
  dish: AiDish,
  ingredients: MeasuredIngredient[],
  target: Macros,
  tolerance: Tolerance = defaultTolerance,
  note = "",
): MeasuredDish {
  const shown = ingredients
    .map(presentIngredient)
    .filter((item) => item.grams >= 1);
  const totals = {
    kcal: shown.reduce((sum, item) => sum + item.kcal, 0),
    proteinG: round1(shown.reduce((sum, item) => sum + item.proteinG, 0)),
    fatG: round1(shown.reduce((sum, item) => sum + item.fatG, 0)),
    carbG: round1(shown.reduce((sum, item) => sum + item.carbG, 0)),
  };
  const gap = {
    kcal: Math.round(target.kcal - totals.kcal),
    proteinG: round1(target.proteinG - totals.proteinG),
    fatG: round1(target.fatG - totals.fatG),
    carbG: round1(target.carbG - totals.carbG),
  };
  return {
    name: dish.name,
    steps: dish.steps,
    extras: dish.extras,
    ingredients: shown,
    totals,
    gap,
    within: withinTolerance(target, totals, tolerance),
    score: gapScore(target, totals),
    issues: realismIssues(dish, note),
    gapReason: "",
    omitNote: "",
  };
}

export function withGapReason(dish: MeasuredDish, target: Macros): MeasuredDish {
  return {
    ...dish,
    gapReason: dish.within ? "" : explainGap(target, dish),
  };
}

export function explainGap(target: Macros, dish: MeasuredDish): string {
  const gap = dish.gap;
  const parts: string[] = [];
  if (!closeKcal(dish.totals.kcal, target.kcal, defaultTolerance.kcalRatio)) {
    parts.push(
      gap.kcal > 0
        ? `エネルギーは${dish.totals.kcal}kcalで、目標より${gap.kcal}kcal少ない`
        : `エネルギーは${dish.totals.kcal}kcalで、目標より${Math.abs(gap.kcal)}kcal多い`,
    );
  }
  const macros: Array<[string, number, string]> = [
    ["たんぱく質", gap.proteinG, "P"],
    ["脂質", gap.fatG, "F"],
    ["炭水化物", gap.carbG, "C"],
  ];
  const actual = [dish.totals.proteinG, dish.totals.fatG, dish.totals.carbG];
  const wanted = [target.proteinG, target.fatG, target.carbG];
  for (let i = 0; i < macros.length; i++) {
    if (closeMacro(actual[i], wanted[i], defaultTolerance)) {
      continue;
    }
    const delta = macros[i][1];
    const label = macros[i][0];
    parts.push(
      delta > 0
        ? `${label}は${actual[i]}gで、目標より${Math.abs(delta)}g少ない`
        : `${label}は${actual[i]}gで、目標より${Math.abs(delta)}g多い`,
    );
  }
  const rice = dish.ingredients.find((item) => isRice(item.name));
  if (rice && rice.grams <= 100 && gap.carbG < 0) {
    parts.push("ごはんは100gより少なくできない");
  }
  if (rice && rice.grams >= 300 && gap.kcal > 0) {
    parts.push("ごはんは300gまで");
  }
  const meat = dish.ingredients.find((item) => isMeatFish(item.name));
  if (meat && meat.grams >= 250 && gap.proteinG > 0) {
    parts.push("肉や魚は250gまでなので、たんぱく質をこれ以上増やせない");
  }
  if (!meat && gap.proteinG > 5 && !dish.ingredients.some((item) => isEgg(item.name) || item.name.includes("豆腐"))) {
    parts.push("手元の食材だけではたんぱく質が足りない");
  }
  const oil = dish.ingredients.find((item) => isOil(item.name));
  if (oil && oil.grams >= 15 && gap.fatG > 0) {
    parts.push("油は15gまで");
  }
  if (parts.length === 0) {
    parts.push("この食材の現実的な分量では目標にちょうど届かない");
  }
  return `${parts.join("。")}。`;
}

export function bestMeasured(
  dish: AiDish,
  foods: FoodRow[],
  target: Macros,
  tolerance: Tolerance = defaultTolerance,
  note = "",
  avoid: string[] = [],
): MeasuredDish {
  const measured = snapEggs(measureIngredients(dish, foods));
  const unscaled = withGapReason(presentDish(dish, measured, target, tolerance, note), target);
  if (unscaled.within && unscaled.issues.length === 0) {
    return unscaled;
  }
  const expanded = appendPantryStaples(measured, foods, avoid);
  const scaled = withGapReason(
    presentDish(dish, optimizeIngredients(expanded, target), target, tolerance, note),
    target,
  );
  return preferDish(unscaled, scaled);
}

export function preferDish(current: MeasuredDish, next: MeasuredDish | null): MeasuredDish {
  if (!next) {
    return current;
  }
  const currentHome = current.issues.length === 0;
  const nextHome = next.issues.length === 0;
  if (nextHome && !currentHome) {
    return next;
  }
  if (currentHome && !nextHome) {
    return current;
  }
  if (next.within && !current.within) {
    return next;
  }
  if (current.within && !next.within) {
    return current;
  }
  return next.score < current.score ? next : current;
}

export function shouldRetry(dishes: MeasuredDish[]): boolean {
  return dishes.some((dish) => dish.issues.length > 0 || !dish.within);
}

function ratesOf(item: MeasuredIngredient): Rates {
  const grams = item.grams > 0 ? item.grams : 1;
  return {
    kcal: item.kcal / grams,
    proteinG: item.proteinG / grams,
    fatG: item.fatG / grams,
    carbG: item.carbG / grams,
  };
}

function totalsAt(grams: number[], rates: Rates[]): Macros {
  const totals = { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 };
  for (let i = 0; i < grams.length; i++) {
    totals.kcal += rates[i].kcal * grams[i];
    totals.proteinG += rates[i].proteinG * grams[i];
    totals.fatG += rates[i].fatG * grams[i];
    totals.carbG += rates[i].carbG * grams[i];
  }
  return totals;
}

function applyGrams(item: MeasuredIngredient, rates: Rates, grams: number): MeasuredIngredient {
  return {
    ...item,
    grams,
    kcal: rates.kcal * grams,
    proteinG: rates.proteinG * grams,
    fatG: rates.fatG * grams,
    carbG: rates.carbG * grams,
  };
}

function weights(target: Macros): [number, number, number, number] {
  return [
    1 / Math.max(1, Math.abs(target.kcal) * 0.10),
    1 / Math.max(5, Math.abs(target.proteinG) * 0.15),
    1 / Math.max(5, Math.abs(target.fatG) * 0.15),
    1 / Math.max(5, Math.abs(target.carbG) * 0.15),
  ];
}

function vector(rates: Rates): [number, number, number, number] {
  return [rates.kcal, rates.proteinG, rates.fatG, rates.carbG];
}

function goal(target: Macros): [number, number, number, number] {
  return [target.kcal, target.proteinG, target.fatG, target.carbG];
}

function fitOne(
  index: number,
  grams: number[],
  rates: Rates[],
  bounds: GramWindow[],
  target: Macros,
): number {
  const current = grams[index];
  const base = totalsAt(grams, rates);
  const rate = vector(rates[index]);
  const want = goal(target);
  const w = weights(target);
  const have = [base.kcal, base.proteinG, base.fatG, base.carbG];
  let num = 0;
  let den = 0;
  for (let d = 0; d < 4; d++) {
    const without = have[d] - rate[d] * current;
    const ww = w[d] * w[d];
    num += ww * rate[d] * (want[d] - without);
    den += ww * rate[d] * rate[d];
  }
  if (den <= 1e-12) {
    return current;
  }
  return clamp(num / den, bounds[index].min, bounds[index].max);
}

function descend(
  start: number[],
  names: string[],
  rates: Rates[],
  bounds: GramWindow[],
  target: Macros,
): number[] {
  const grams = start.slice();
  for (let pass = 0; pass < 8; pass++) {
    for (let i = 0; i < grams.length; i++) {
      grams[i] = fitOne(i, grams, rates, bounds, target);
    }
  }
  for (let i = 0; i < grams.length; i++) {
    grams[i] = choosePortion(i, names[i] ?? "", grams, rates, bounds, target);
  }
  for (let pass = 0; pass < 4; pass++) {
    let moved = false;
    for (let i = 0; i < grams.length; i++) {
      const next = choosePortion(i, names[i] ?? "", grams, rates, bounds, target);
      if (next !== grams[i]) {
        grams[i] = next;
        moved = true;
      }
    }
    if (!moved) {
      break;
    }
  }
  return grams;
}

function choosePortion(
  index: number,
  name: string,
  grams: number[],
  rates: Rates[],
  bounds: GramWindow[],
  target: Macros,
): number {
  const exact = fitOne(index, grams, rates, bounds, target);
  const choices = portionChoices(name, exact, bounds[index]);
  let best = grams[index];
  let bestScore = Number.POSITIVE_INFINITY;
  for (const choice of choices) {
    grams[index] = choice;
    const score = gapScore(target, totalsAt(grams, rates));
    if (score < bestScore) {
      bestScore = score;
      best = choice;
    }
  }
  grams[index] = best;
  return best;
}

function portionChoices(name: string, exact: number, bounds: GramWindow): number[] {
  const atFloor = exact <= bounds.min + 1e-6;
  if (isEgg(name)) {
    const choices = [50, 100, 150, 200].filter((grams) => grams >= bounds.min && grams <= bounds.max);
    if (atFloor || bounds.min === 0) {
      choices.unshift(0);
    }
    return choices.length > 0 ? choices : [0];
  }
  const snapped = clampInt(Math.round(exact), bounds.min, bounds.max);
  const choices = new Set<number>([snapped]);
  if (bounds.min === 0 || (atFloor && bounds.min > 0)) {
    choices.add(0);
  }
  for (const delta of [-2, -1, 1, 2]) {
    const next = snapped + delta;
    if (next >= bounds.min && next <= bounds.max) {
      choices.add(next);
    }
  }
  return [...choices];
}

function kcalStart(
  grams: number[],
  rates: Rates[],
  bounds: GramWindow[],
  target: Macros,
): number[] {
  const now = totalsAt(grams, rates).kcal;
  if (!(now > 0) || !(target.kcal > 0)) {
    return grams.slice();
  }
  const ratio = target.kcal / now;
  return grams.map((gram, index) => clamp(gram * ratio, bounds[index].min, bounds[index].max));
}

export function isEgg(name: string): boolean {
  return name.includes("卵") || name.includes("たまご");
}

function isSalt(name: string): boolean {
  if (name.includes("塩鮭") || name.includes("塩さけ")) {
    return false;
  }
  return name === "塩" || name.includes("食塩");
}

export function isOil(name: string): boolean {
  if (name.includes("油揚げ") || name.includes("醤油") || name.includes("しょうゆ")) {
    return false;
  }
  return name.includes("油") || name.includes("オイル") || name.includes("バター") || name.includes("ラード");
}

function isSugar(name: string): boolean {
  return name.includes("砂糖");
}

export function isSeasoning(name: string): boolean {
  const words = ["塩", "しょうゆ", "醤油", "砂糖", "酒", "みりん", "酢", "味噌", "みそ", "こしょう", "胡椒", "だし", "ソース", "ケチャップ", "マヨ"];
  return words.some((word) => name.includes(word));
}

export function isRice(name: string): boolean {
  if (name.includes("米酢") || name.includes("米粉")) {
    return false;
  }
  const words = ["ごはん", "ご飯", "米飯", "白米", "お米", "米"];
  return words.some((word) => name.includes(word));
}

function isBread(name: string): boolean {
  if (name.includes("パン粉")) {
    return false;
  }
  return name.includes("パン");
}

function isNoodle(name: string): boolean {
  const words = ["麺", "うどん", "そば", "パスタ", "そうめん", "ラーメン"];
  return words.some((word) => name.includes(word));
}

export function isMeatFish(name: string): boolean {
  if (isEgg(name) || name.includes("豆腐") || name.includes("納豆") || name.includes("チーズ") || name.includes("牛乳")) {
    return false;
  }
  const words = ["肉", "鶏", "豚", "牛", "鮭", "さけ", "魚", "ひき", "ささみ", "ぶり", "さば", "あじ", "いわし", "たら", "まぐろ", "ツナ", "えび", "いか", "サーモン"];
  return words.some((word) => name.includes(word));
}

export function isPotato(name: string): boolean {
  return name.includes("じゃがいも") || name.includes("ジャガイモ") || name.includes("ポテト");
}

export function isVeg(name: string): boolean {
  if (isPotato(name)) {
    return true;
  }
  const words = ["キャベツ", "玉ねぎ", "たまねぎ", "にんじん", "人参", "トマト", "ねぎ", "もやし", "ほうれん草", "ブロッコリー", "白菜", "ピーマン", "なす", "きゅうり", "レタス", "大根", "きのこ", "しいたけ", "小松菜", "豆苗"];
  return words.some((word) => name.includes(word));
}

function snapEggs(items: MeasuredIngredient[]): MeasuredIngredient[] {
  return items.map((item) => {
    if (!isEgg(item.name) || item.grams < 1) {
      return item;
    }
    const snapped = Math.max(50, Math.min(200, Math.round(item.grams / 50) * 50));
    if (snapped === item.grams || !(item.grams > 0)) {
      return item;
    }
    const scale = snapped / item.grams;
    return {
      ...item,
      grams: snapped,
      originalGrams: snapped,
      kcal: item.kcal * scale,
      proteinG: item.proteinG * scale,
      fatG: item.fatG * scale,
      carbG: item.carbG * scale,
    };
  });
}

export function categoryPer100(name: string): Macros | null {
  if (isEgg(name)) {
    return { kcal: 151, proteinG: 12.3, fatG: 10.3, carbG: 0.3 };
  }
  if (isOil(name)) {
    return { kcal: 921, proteinG: 0, fatG: 100, carbG: 0 };
  }
  if (isRice(name)) {
    return { kcal: 168, proteinG: 2.5, fatG: 0.3, carbG: 37.1 };
  }
  if (isPotato(name)) {
    return { kcal: 76, proteinG: 1.6, fatG: 0.1, carbG: 17.6 };
  }
  if (name.includes("豆腐")) {
    return { kcal: 73, proteinG: 6.6, fatG: 4.2, carbG: 2 };
  }
  if (name.includes("納豆")) {
    return { kcal: 190, proteinG: 16.5, fatG: 10, carbG: 12 };
  }
  if (name.includes("豚") || name.includes("ひき") || name.includes("合いびき")) {
    return { kcal: 221, proteinG: 18.2, fatG: 16, carbG: 0.2 };
  }
  if (name.includes("鮭") || name.includes("さけ") || name.includes("サーモン") || name.includes("魚")) {
    return { kcal: 133, proteinG: 22.3, fatG: 4.1, carbG: 0.1 };
  }
  if (isMeatFish(name)) {
    return { kcal: 108, proteinG: 24, fatG: 1.5, carbG: 0 };
  }
  if (isVeg(name)) {
    return { kcal: 30, proteinG: 1.5, fatG: 0.2, carbG: 6 };
  }
  if (name.includes("牛乳")) {
    return { kcal: 67, proteinG: 3.3, fatG: 3.8, carbG: 4.8 };
  }
  return null;
}

function plausibleOrEstimate(item: AiIngredient): Macros {
  const guess = categoryPer100(item.name);
  if (!guess || !(item.grams > 0)) {
    return item;
  }
  const per100 = item.kcal / item.grams * 100;
  if (per100 >= guess.kcal * 0.45 && per100 <= guess.kcal * 2.2) {
    return item;
  }
  const scale = item.grams / 100;
  return {
    kcal: guess.kcal * scale,
    proteinG: guess.proteinG * scale,
    fatG: guess.fatG * scale,
    carbG: guess.carbG * scale,
  };
}

function presentIngredient(item: MeasuredIngredient): MeasuredIngredient {
  return {
    ...item,
    kcal: Math.round(item.kcal),
    proteinG: round1(item.proteinG),
    fatG: round1(item.fatG),
    carbG: round1(item.carbG),
  };
}

function roundMacros(value: Macros): Macros {
  return {
    kcal: Math.round(value.kcal),
    proteinG: round1(value.proteinG),
    fatG: round1(value.fatG),
    carbG: round1(value.carbG),
  };
}

export function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function clampInt(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

const dakutenBase = "ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ";
const dakutenTo = "ガギグゲゴザジズゼゾダヂヅデドバビブベボ";
const handakutenBase = "ﾊﾋﾌﾍﾎ";
const handakutenTo = "パピプペポ";
const halfFrom = "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ";
const halfTo = "ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン";

function composeHalfwidthVoiced(text: string): string {
  let out = "";
  const chars = Array.from(text);
  for (let i = 0; i < chars.length; i++) {
    const next = chars[i + 1] ?? "";
    if (next === "ﾞ") {
      const at = dakutenBase.indexOf(chars[i]);
      if (at >= 0) {
        out += Array.from(dakutenTo)[at];
        i += 1;
        continue;
      }
    }
    if (next === "ﾟ") {
      const at = handakutenBase.indexOf(chars[i]);
      if (at >= 0) {
        out += Array.from(handakutenTo)[at];
        i += 1;
        continue;
      }
    }
    out += chars[i];
  }
  return out;
}

function halfwidthKatakana(code: number): number | null {
  if (code < 0xFF66 || code > 0xFF9D) {
    return null;
  }
  const ch = String.fromCodePoint(code);
  const at = Array.from(halfFrom).indexOf(ch);
  if (at < 0) {
    return null;
  }
  return Array.from(halfTo)[at].codePointAt(0) ?? null;
}

function isLongVowelOrHyphen(code: number): boolean {
  return code === 0x30FC || code === 0x002D || code === 0x2010 ||
    code === 0x2011 || code === 0x2013 || code === 0x2014 || code === 0x2212;
}

function isWhitespace(code: number): boolean {
  return code === 9 || code === 10 || code === 11 || code === 12 || code === 13 ||
    code === 32 || code === 133 || code === 160 || code === 5760 ||
    (code >= 8192 && code <= 8202) || code === 8232 || code === 8233 ||
    code === 8239 || code === 8287 || code === 12288 || code === 65279;
}
