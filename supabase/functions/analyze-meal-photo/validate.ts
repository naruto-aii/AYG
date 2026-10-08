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

export function parsePhotoMealEstimate(raw: unknown): PhotoMealEstimate | null {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    return null;
  }
  const row = raw as Record<string, unknown>;
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
  return {
    dishName,
    amount,
    kcal: nutrition.kcal,
    proteinG: nutrition.proteinG,
    fatG: nutrition.fatG,
    carbG: nutrition.carbG,
    confidence: row.confidence,
    items,
  };
}

export function parseModelJson(text: string): unknown {
  const trimmed = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  return JSON.parse(trimmed);
}

export const mealEstimateSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    dish_name: { type: "string" },
    amount: { type: "string" },
    kcal: { type: "number" },
    protein_g: { type: "number" },
    fat_g: { type: "number" },
    carb_g: { type: "number" },
    confidence: { type: "number" },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          amount: { type: "string" },
          kcal: { type: "number" },
          protein_g: { type: "number" },
          fat_g: { type: "number" },
          carb_g: { type: "number" },
        },
        required: ["name", "amount", "kcal", "protein_g", "fat_g", "carb_g"],
      },
    },
  },
  required: [
    "dish_name",
    "amount",
    "kcal",
    "protein_g",
    "fat_g",
    "carb_g",
    "confidence",
    "items",
  ],
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
