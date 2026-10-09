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
          h: { type: "string" },
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
  chainName: string | null;
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

const sizeWords = new Set(["大盛", "並盛", "小盛", "特盛", "普通盛", "普通"]);

// 検索語の食品か、量の違いだけを残す。大盛だけの一致では別の料理を通さない。
export function candidateMatchesQuery(query: string, name: string): boolean {
  const normalizedQuery = normalizeFoodQuery(query);
  const normalizedName = normalizeFoodQuery(name);
  if (!normalizedQuery || !normalizedName) {
    return false;
  }
  if (normalizedName.includes(normalizedQuery) || normalizedQuery.includes(normalizedName)) {
    return true;
  }
  const tokens = normalizedQuery
    .split(/[\s()（）・、,./]+/)
    .filter((token) => token.length >= 2);
  const food = tokens.filter((token) => !sizeWords.has(token));
  const required = food.length > 0 ? food : tokens;
  return required.some((token) => normalizedName.includes(token));
}

export function relevantCandidates(
  query: string,
  candidates: LookupCandidate[],
): LookupCandidate[] | null {
  const kept = candidates.filter((candidate) => candidateMatchesQuery(query, candidate.name));
  return kept.length > 0 ? preferPlainFirst(query, kept) : null;
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
  return candidates.length > 0 ? alignCandidatePortions(candidates) : null;
}

const portionPattern =
  /(\d+(?:\.\d+)?)\s*(個入り|本入り|枚入り|袋入り|個入|本入|枚入|袋入|パック|個|本|枚|切れ|袋|箱|缶|玉)/;

export function amountCount(text: string): { count: number; unit: string } | null {
  const matched = text.normalize("NFKC").match(portionPattern);
  if (!matched) {
    return null;
  }
  const count = Number(matched[1]);
  if (!Number.isFinite(count) || count <= 0) {
    return null;
  }
  const unit = matched[2].replace(/入り?$/, "");
  return { count, unit };
}

const countPattern =
  /(\d+(?:\.\d+)?)\s*(個入り|本入り|枚入り|袋入り|個入|本入|枚入|袋入|パック|個|本|枚|切れ|袋|箱|缶|玉)/g;
const gramPattern = /約?\s*(\d+(?:\.\d+)?)\s*(g|グラム|ml)/i;

/// 括弧の中が個数やグラムだけなら、商品名の一部ではない。
function quantityOnly(inner: string): boolean {
  const rest = inner
    .replace(countPattern, "")
    .replace(/約?\s*\d+(?:\.\d+)?\s*(g|グラム|ml)/gi, "")
    .replace(/[約入りずつ分・、,\s]/g, "");
  return rest.length === 0;
}

/// 同じ商品かを見るための名前。店名、個数、量だけの括弧を外す。部位やサイズの言葉は残す。
export function productKey(candidate: LookupCandidate): string {
  let name = normalizeFoodQuery(candidate.name);
  if (candidate.chainName) {
    const chain = normalizeFoodQuery(candidate.chainName);
    if (chain) {
      name = name.replaceAll(chain, "");
    }
  }
  name = name.replace(/\(([^)]*)\)/g, (all, inner: string) => quantityOnly(inner) ? "" : all);
  name = name.replace(countPattern, "");
  return name.replace(/[\s・]/g, "");
}

function gramsPerUnit(candidate: LookupCandidate, count: number): number | null {
  const matched = candidate.amount.normalize("NFKC").match(gramPattern);
  if (!matched) {
    return null;
  }
  const grams = Number(matched[1]);
  return Number.isFinite(grams) && grams > 0 ? grams / count : null;
}

/// 同じ商品で個数だけが違う候補は、最初の候補の 1 単位あたりに合わせる。
/// 名前やサイズが違う候補（ダブル、L、部位違いなど）は、その候補の値のまま残す。
export function alignCandidatePortions(candidates: LookupCandidate[]): LookupCandidate[] {
  if (candidates.length < 2 || !(candidates[0].kcal > 0)) {
    return candidates;
  }
  const first = amountCount(`${candidates[0].name} ${candidates[0].amount}`);
  if (!first) {
    return candidates;
  }
  const firstKey = productKey(candidates[0]);
  const firstGrams = gramsPerUnit(candidates[0], first.count);
  const perUnit = candidates[0].kcal / first.count;
  const aligned = [candidates[0]];
  for (const candidate of candidates.slice(1)) {
    const count = amountCount(`${candidate.name} ${candidate.amount}`);
    if (!count || count.unit !== first.unit || !(candidate.kcal > 0)) {
      aligned.push(candidate);
      continue;
    }
    if (!firstKey || productKey(candidate) !== firstKey) {
      aligned.push(candidate);
      continue;
    }
    const grams = gramsPerUnit(candidate, count.count);
    if (firstGrams != null && grams != null) {
      const gramRatio = grams / firstGrams;
      if (gramRatio < 0.8 || gramRatio > 1.25) {
        aligned.push(candidate);
        continue;
      }
    }
    const expected = perUnit * count.count;
    const ratio = candidate.kcal / expected;
    if (ratio >= 0.75 && ratio <= 1.25) {
      aligned.push(candidate);
      continue;
    }
    const factor = expected / candidate.kcal;
    if (!Number.isFinite(factor) || factor < 0.2 || factor > 5) {
      continue;
    }
    const scaled: LookupCandidate = {
      ...candidate,
      kcal: Math.round(candidate.kcal * factor),
      proteinG: round1(candidate.proteinG * factor),
      fatG: round1(candidate.fatG * factor),
      carbG: round1(candidate.carbG * factor),
    };
    if (!pfcMatchesKcal(scaled.kcal, scaled.proteinG, scaled.fatG, scaled.carbG)) {
      continue;
    }
    aligned.push(scaled);
  }
  return aligned;
}

/// 検索語に部位やサイズの指定がないのに、1つ目だけが部位やサイズ違いなら、
/// 指定のない候補を先にする。数値は書き換えない。
export function preferPlainFirst(query: string, candidates: LookupCandidate[]): LookupCandidate[] {
  if (candidates.length < 2) {
    return candidates;
  }
  const normalizedQuery = normalizeFoodQuery(query);
  const qualifier = (candidate: LookupCandidate): string[] => {
    const out: string[] = [];
    for (const matched of normalizeFoodQuery(candidate.name).matchAll(/\(([^)]*)\)/g)) {
      if (!quantityOnly(matched[1])) {
        out.push(matched[1].trim());
      }
    }
    return out;
  };
  const extra = (candidate: LookupCandidate) =>
    qualifier(candidate).filter((word) => word && !normalizedQuery.includes(word));
  if (extra(candidates[0]).length === 0) {
    return candidates;
  }
  const index = candidates.findIndex((candidate) => extra(candidate).length === 0);
  if (index <= 0) {
    return candidates;
  }
  return [candidates[index], ...candidates.filter((_candidate, i) => i !== index)];
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
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
    chainName: optionalChain(row.h ?? row.chain_name),
  };
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
