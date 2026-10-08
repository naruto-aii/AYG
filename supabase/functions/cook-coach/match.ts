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
      return {
        name: item.name,
        grams: item.grams,
        originalGrams: item.grams,
        kcal: item.kcal,
        proteinG: item.proteinG,
        fatG: item.fatG,
        carbG: item.carbG,
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
  const base = Math.max(1, Math.round(suggested));
  let absMin = 20;
  let absMax = 180;
  let low = 0.4;
  let high = 2;
  if (name.includes("油揚げ") || name.includes("がんも")) {
    absMin = 10;
    absMax = 80;
    low = 0.5;
    high = 1.8;
  } else if (name.includes("卵") || name.includes("たまご")) {
    absMin = 50;
    absMax = 150;
    low = 0.5;
    high = 2;
  } else if (isOil(name)) {
    absMin = 1;
    absMax = 15;
    low = 0.3;
    high = 3;
  } else if (isProtein(name)) {
    absMin = 30;
    absMax = 220;
    low = 0.45;
    high = 2.2;
  } else if (isSeasoning(name)) {
    absMin = 1;
    absMax = 20;
    low = 0.4;
    high = 2;
  } else if (isStaple(name)) {
    absMin = 40;
    absMax = 250;
    low = 0.35;
    high = 1.8;
  }
  let min = Math.max(absMin, Math.round(base * low));
  let max = Math.min(absMax, Math.round(base * high));
  if (min > max) {
    min = absMin;
    max = absMax;
  }
  min = Math.max(1, min);
  max = Math.max(min, max);
  return { min, max };
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
  const suggested = items.map((item, index) =>
    clamp(item.grams, bounds[index].min, bounds[index].max)
  );
  const fromSuggested = descend(suggested, rates, bounds, target);
  const fromKcal = descend(kcalStart(suggested, rates, bounds, target), rates, bounds, target);
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
  const shown = ingredients.map(presentIngredient);
  const totals = roundMacros(sumMacros(shown));
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
  };
}

export function bestMeasured(
  dish: AiDish,
  foods: FoodRow[],
  target: Macros,
  tolerance: Tolerance = defaultTolerance,
  note = "",
): MeasuredDish {
  const measured = measureIngredients(dish, foods);
  const unscaled = presentDish(dish, measured, target, tolerance, note);
  if (unscaled.within && unscaled.issues.length === 0) {
    return unscaled;
  }
  const scaled = presentDish(dish, optimizeIngredients(measured, target), target, tolerance, note);
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
    const exact = fitOne(i, grams, rates, bounds, target);
    const candidates = [Math.floor(exact), Math.round(exact), Math.ceil(exact)];
    let best = clampInt(Math.round(exact), bounds[i].min, bounds[i].max);
    let bestScore = Number.POSITIVE_INFINITY;
    for (const candidate of candidates) {
      const next = clampInt(candidate, bounds[i].min, bounds[i].max);
      grams[i] = next;
      const score = gapScore(target, totalsAt(grams, rates));
      if (score < bestScore) {
        bestScore = score;
        best = next;
      }
    }
    grams[i] = best;
  }
  for (let pass = 0; pass < 4; pass++) {
    let moved = false;
    for (let i = 0; i < grams.length; i++) {
      const exact = fitOne(i, grams, rates, bounds, target);
      const next = clampInt(Math.round(exact), bounds[i].min, bounds[i].max);
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

function isOil(name: string): boolean {
  if (name.includes("油揚げ")) {
    return false;
  }
  return name.includes("油") || name.includes("オイル") || name.includes("バター") || name.includes("ラード");
}

function isSeasoning(name: string): boolean {
  const words = ["塩", "しょうゆ", "醤油", "砂糖", "酒", "みりん", "酢", "味噌", "みそ", "こしょう", "胡椒", "だし", "ソース", "ケチャップ", "マヨ"];
  return words.some((word) => name.includes(word));
}

function isStaple(name: string): boolean {
  const words = ["ごはん", "ご飯", "米飯", "白米", "米", "パン", "麺", "うどん", "そば", "パスタ", "オートミール"];
  return words.some((word) => name.includes(word));
}

function isProtein(name: string): boolean {
  const words = ["肉", "鶏", "豚", "牛", "鮭", "さけ", "魚", "ひき肉", "ささみ", "豆腐", "納豆", "チーズ"];
  return words.some((word) => name.includes(word));
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
