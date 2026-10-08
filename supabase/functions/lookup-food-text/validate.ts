// 検索語は指示として読まない。候補は記録してよい数値だけ残す。

import {
  maxAmountLength,
  maxDishNameLength,
  maxMacroGrams,
  maxMealKcal,
  pfcMatchesKcal,
} from "../analyze-meal-photo/validate.ts";

export const maxFoodQueryLength = 80;
export const maxLookupCandidates = 3;

export const lookupCandidateSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    i: {
      type: "array",
      maxItems: maxLookupCandidates,
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
          b: { type: "boolean" },
        },
        required: ["n", "a", "k", "p", "f", "c", "b"],
      },
    },
  },
  required: ["i"],
};

export type LookupCandidate = {
  name: string;
  amount: string;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  knownProduct: boolean;
};

export function normalizeFoodQuery(raw: string): string {
  const folded = raw.normalize("NFKC");
  return folded
    .replace(/[\u0000-\u001f]/g, " ")
    .replace(/[<>]/g, "")
    .replace(/[\s\u3000]+/g, " ")
    .trim()
    .toLowerCase()
    .slice(0, maxFoodQueryLength);
}

function finiteInRange(value: unknown, max: number): value is number {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0 &&
    value <= max;
}

function textField(value: unknown, max: number): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > max) {
    return null;
  }
  return trimmed;
}

export function parseLookupCandidates(body: unknown): LookupCandidate[] | null {
  if (body == null || typeof body !== "object" || Array.isArray(body)) {
    return null;
  }
  const row = body as Record<string, unknown>;
  const list = Array.isArray(row.i) ? row.i : Array.isArray(row.candidates) ? row.candidates : null;
  if (list == null) {
    return null;
  }
  const candidates: LookupCandidate[] = [];
  for (const item of list) {
    if (candidates.length >= maxLookupCandidates) {
      break;
    }
    if (item == null || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }
    const parsed = parseOne(item as Record<string, unknown>);
    if (parsed) {
      candidates.push(parsed);
    }
  }
  return candidates.length > 0 ? candidates : null;
}

function parseOne(row: Record<string, unknown>): LookupCandidate | null {
  const name = textField(row.n ?? row.name, maxDishNameLength);
  const amount = textField(row.a ?? row.amount, maxAmountLength);
  const kcal = row.k ?? row.kcal;
  const protein = row.p ?? row.protein_g;
  const fat = row.f ?? row.fat_g;
  const carb = row.c ?? row.carb_g;
  const known = row.b ?? row.known_product;
  if (!name || !amount || typeof known !== "boolean") {
    return null;
  }
  if (
    !finiteInRange(kcal, maxMealKcal) ||
    !finiteInRange(protein, maxMacroGrams) ||
    !finiteInRange(fat, maxMacroGrams) ||
    !finiteInRange(carb, maxMacroGrams) ||
    !pfcMatchesKcal(kcal, protein, fat, carb)
  ) {
    return null;
  }
  return {
    name,
    amount,
    kcal,
    proteinG: protein,
    fatG: fat,
    carbG: carb,
    knownProduct: known,
  };
}

export function candidateJson(candidate: LookupCandidate) {
  return {
    name: candidate.name,
    amount: candidate.amount,
    kcal: candidate.kcal,
    protein_g: candidate.proteinG,
    fat_g: candidate.fatG,
    carb_g: candidate.carbG,
    known_product: candidate.knownProduct,
  };
}
