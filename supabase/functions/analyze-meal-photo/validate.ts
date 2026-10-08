// モデルの JSON を、記録してよい数値だけに絞る。

export const maxMealKcal = 10_000;
export const maxMacroGrams = 1_000;
export const maxDishNameLength = 80;
export const maxAmountLength = 40;
export const maxItemCount = 12;
export const pfcAbsoluteToleranceKcal = 50;
export const pfcRelativeTolerance = 0.2;

export type PhotoMealItem = {
  name: string;
  amount: string;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
};

export type PhotoMealEstimate = {
  dishName: string;
  amount: string;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  confidence: number;
  chainName: string | null;
  items: PhotoMealItem[];
};

export function derivedPfcKcal(
  proteinG: number,
  fatG: number,
  carbG: number,
): number {
  return proteinG * 4 + fatG * 9 + carbG * 4;
}

export function pfcMatchesKcal(
  kcal: number,
  proteinG: number,
  fatG: number,
  carbG: number,
): boolean {
  const derived = derivedPfcKcal(proteinG, fatG, carbG);
  const diff = Math.abs(kcal - derived);
  const scale = Math.max(kcal, derived);
  return diff <= Math.max(pfcAbsoluteToleranceKcal, pfcRelativeTolerance * scale);
}

function finiteInRange(value: unknown, max: number): value is number {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0 &&
    value <= max;
}

function nutritionOf(row: Record<string, unknown>): {
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
} | null {
  if (
    !finiteInRange(row.kcal, maxMealKcal) ||
    !finiteInRange(row.protein_g, maxMacroGrams) ||
    !finiteInRange(row.fat_g, maxMacroGrams) ||
    !finiteInRange(row.carb_g, maxMacroGrams)
  ) {
    return null;
  }
  if (!pfcMatchesKcal(row.kcal, row.protein_g, row.fat_g, row.carb_g)) {
    return null;
  }
  return {
    kcal: row.kcal,
    proteinG: row.protein_g,
    fatG: row.fat_g,
    carbG: row.carb_g,
  };
}

function textField(value: unknown, max: number, allowEmpty: boolean): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed.length > max) {
    return null;
  }
  if (!allowEmpty && trimmed.length === 0) {
    return null;
  }
  return trimmed;
}

const shortToLong: Record<string, string> = {
  n: "dish_name",
  a: "amount",
  k: "kcal",
  p: "protein_g",
  f: "fat_g",
  c: "carb_g",
  u: "confidence",
  i: "items",
  h: "chain_name",
};

const shortItemToLong: Record<string, string> = {
  n: "name",
  a: "amount",
  k: "kcal",
  p: "protein_g",
  f: "fat_g",
  c: "carb_g",
};

function copyMissing(target: Record<string, unknown>, map: Record<string, string>) {
  for (const [short, long] of Object.entries(map)) {
    if (target[long] == null && target[short] != null) {
      target[long] = target[short];
    }
  }
}

export function expandMealJson(raw: unknown): unknown {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    return raw;
  }
  const out: Record<string, unknown> = { ...(raw as Record<string, unknown>) };
  copyMissing(out, shortToLong);
  if (Array.isArray(out.items)) {
    out.items = out.items.map((item) => {
      if (item == null || typeof item !== "object" || Array.isArray(item)) {
        return item;
      }
      const part: Record<string, unknown> = { ...(item as Record<string, unknown>) };
      copyMissing(part, shortItemToLong);
      return part;
    });
  }
  return out;
}

export function parsePhotoMealEstimate(raw: unknown): PhotoMealEstimate | null {
  const expanded = expandMealJson(raw);
  if (expanded == null || typeof expanded !== "object" || Array.isArray(expanded)) {
    return null;
  }
  const row = expanded as Record<string, unknown>;
  const dishName = textField(row.dish_name, maxDishNameLength, false);
  const amount = textField(row.amount, maxAmountLength, true);
  const nutrition = nutritionOf(row);
  if (dishName == null || amount == null || nutrition == null) {
    return null;
  }
  if (!finiteInRange(row.confidence, 1)) {
    return null;
  }
  if (!Array.isArray(row.items) || row.items.length > maxItemCount) {
    return null;
  }
  const items: PhotoMealItem[] = [];
  for (const item of row.items) {
    if (item == null || typeof item !== "object" || Array.isArray(item)) {
      return null;
    }
    const part = item as Record<string, unknown>;
    const name = textField(part.name, maxDishNameLength, false);
    const itemAmount = textField(part.amount, maxAmountLength, true);
    const itemNutrition = nutritionOf(part);
    if (name == null || itemAmount == null || itemNutrition == null) {
      return null;
    }
    items.push({
      name,
      amount: itemAmount,
      kcal: itemNutrition.kcal,
      proteinG: itemNutrition.proteinG,
      fatG: itemNutrition.fatG,
      carbG: itemNutrition.carbG,
    });
  }
  const aligned = alignMealItems(items, nutrition);
  return {
    dishName,
    amount,
    kcal: nutrition.kcal,
    proteinG: nutrition.proteinG,
    fatG: nutrition.fatG,
    carbG: nutrition.carbG,
    confidence: row.confidence,
    chainName: optionalChain(row.chain_name),
    items: aligned,
  };
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

/// 品目の kcal・P・F・C を、全体の値に比例させて合計を一致させる。
/// 比例が PFC の許容を外すときは、kcal の倍率だけを使い、各品の PFC 比は保つ。
export function alignMealItems(
  items: PhotoMealItem[],
  total: { kcal: number; proteinG: number; fatG: number; carbG: number },
): PhotoMealItem[] {
  if (items.length === 0 || !(items.reduce((sum, item) => sum + item.kcal, 0) > 0)) {
    return items;
  }
  const independent = scaleItems(items, {
    kcal: ratio(items.reduce((sum, item) => sum + item.kcal, 0), total.kcal),
    proteinG: ratio(items.reduce((sum, item) => sum + item.proteinG, 0), total.proteinG),
    fatG: ratio(items.reduce((sum, item) => sum + item.fatG, 0), total.fatG),
    carbG: ratio(items.reduce((sum, item) => sum + item.carbG, 0), total.carbG),
  }, total);
  if (independent.every((item) => pfcMatchesKcal(item.kcal, item.proteinG, item.fatG, item.carbG))) {
    return independent;
  }
  const kcalRatio = ratio(items.reduce((sum, item) => sum + item.kcal, 0), total.kcal);
  return scaleItems(items, {
    kcal: kcalRatio,
    proteinG: kcalRatio,
    fatG: kcalRatio,
    carbG: kcalRatio,
  }, total);
}

function ratio(sum: number, target: number): number {
  if (!(sum > 0) || !Number.isFinite(target) || target < 0) {
    return 1;
  }
  return target / sum;
}

function scaleItems(
  items: PhotoMealItem[],
  scales: { kcal: number; proteinG: number; fatG: number; carbG: number },
  total: { kcal: number; proteinG: number; fatG: number; carbG: number },
): PhotoMealItem[] {
  const scaled = items.map((item) => ({
    ...item,
    kcal: item.kcal * scales.kcal,
    proteinG: item.proteinG * scales.proteinG,
    fatG: item.fatG * scales.fatG,
    carbG: item.carbG * scales.carbG,
  }));
  const kcal = distribute(scaled.map((item) => item.kcal), total.kcal, 1);
  const protein = distribute(scaled.map((item) => item.proteinG), total.proteinG, 1);
  const fat = distribute(scaled.map((item) => item.fatG), total.fatG, 1);
  const carb = distribute(scaled.map((item) => item.carbG), total.carbG, 1);
  return scaled.map((item, index) => ({
    ...item,
    kcal: kcal[index],
    proteinG: protein[index],
    fatG: fat[index],
    carbG: carb[index],
  }));
}

function distribute(values: number[], target: number, decimals: number): number[] {
  if (values.length === 0 || values.every((value) => !(value > 0))) {
    return values.map(() => 0);
  }
  const factor = 10 ** decimals;
  const targetUnits = Math.round(target * factor);
  const exact = values.map((value) => Math.max(0, value) * factor);
  const floors = exact.map((value) => Math.floor(value + 1e-9));
  let remainder = targetUnits - floors.reduce((sum, value) => sum + value, 0);
  const order = exact
    .map((value, index) => ({ index, frac: value - Math.floor(value + 1e-9) }))
    .sort((a, b) => b.frac - a.frac || a.index - b.index);
  if (remainder > 0) {
    for (let step = 0; step < order.length && remainder > 0; step++) {
      floors[order[step].index] += 1;
      remainder -= 1;
    }
    let cursor = 0;
    while (remainder > 0 && order.length > 0) {
      floors[order[cursor % order.length].index] += 1;
      remainder -= 1;
      cursor += 1;
    }
  } else if (remainder < 0) {
    const reverse = [...order].reverse();
    for (let step = 0; step < reverse.length && remainder < 0; step++) {
      if (floors[reverse[step].index] > 0) {
        floors[reverse[step].index] -= 1;
        remainder += 1;
      }
    }
  }
  return floors.map((value) => round1(value / factor));
}

function optionalChain(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > maxDishNameLength) {
    return null;
  }
  return trimmed;
}

export function parseModelJson(text: string): unknown {
  const trimmed = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  return JSON.parse(trimmed);
}

export const mealEstimateSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    n: { type: "string" },
    a: { type: "string" },
    k: { type: "number" },
    p: { type: "number" },
    f: { type: "number" },
    c: { type: "number" },
    u: { type: "number" },
    h: { type: "string" },
    i: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          n: { type: "string" },
          a: { type: "string" },
          k: { type: "number" },
          p: { type: "number" },
          f: { type: "number" },
          c: { type: "number" },
        },
        required: ["n", "a", "k", "p", "f", "c"],
      },
    },
  },
  required: ["n", "a", "k", "p", "f", "c", "u", "i"],
} as const;

const maxBase64Chars = 2_000_000;
const maxJpegBytes = 1_500_000;

export function jpegBytesFromBase64(raw: string): Uint8Array | null {
  const cleaned = raw.replace(/\s/g, "");
  if (
    cleaned.length === 0 ||
    cleaned.length > maxBase64Chars ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(cleaned)
  ) {
    return null;
  }
  let binary: string;
  try {
    binary = atob(cleaned);
  } catch {
    return null;
  }
  if (binary.length < 3 || binary.length > maxJpegBytes) {
    return null;
  }
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    return null;
  }
  return bytes;
}
