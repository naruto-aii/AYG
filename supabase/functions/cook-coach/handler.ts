// 自炊コーチ。検証済みレシピを毎回 DB から読み、手持ちと買い足しで選ぶ。
// 料理の考案ではモデルを呼ばない。この変更では関数をデプロイせず、本番へ適用しない。

import {
  readNonNegativeInt,
  tokyoDateKey,
  type PhotoAiEnv,
} from "../analyze-meal-photo/policy.ts";
import type { FetchLike, PhotoAiUsage } from "../analyze-meal-photo/provider.ts";
import { checkGate, GateCheckError, gateRowsExist } from "../_shared/gate_check.ts";
import { normalizeFoodName, type FoodRow, type MeasuredDish } from "./match.ts";
import { cookRecipesFromDb, recipeStamp, selectCookPlans, type CookRecipe } from "./select.ts";

export const aiDailyLimitDefault = 15;
const cacheTtlMs = 7 * 24 * 60 * 60 * 1000;

export type CookEnv = PhotoAiEnv & {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  ANTHROPIC_API_KEY?: string;
  PHOTO_AI_PROVIDER?: string;
  PHOTO_AI_LIGHT_MODEL?: string;
  AI_DAILY_LIMIT?: string;
  COOK_AI_MAX_TOKENS?: string;
};

export type CookUsageInsert = {
  userId: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  estimatedCostJpy: number;
  latencyMs: number;
  retried: boolean;
  hadNote: boolean;
  mealSlot: string;
  success: boolean;
  errorCode: string | null;
};

export type CookModelCall = {
  complete(userText: string): Promise<{ text: string; usage: PhotoAiUsage }>;
};

export type CookDeps = {
  env: CookEnv;
  now: () => Date;
  userId: (req: Request) => Promise<string | null>;
  isPlus: (userId: string, now: Date) => Promise<boolean>;
  sleep?: (ms: number) => Promise<void>;
  dailyCount: (userId: string, since: Date) => Promise<number>;
  insertUsage: (row: CookUsageInsert) => Promise<string | null>;
  lookupFoods: (names: string[]) => Promise<FoodRow[]>;
  model: () => CookModelCall;
  loadRecipes: () => Promise<CookRecipe[]>;
  recordZeroHit?: (row: { ingredients: string[]; atTime: string }) => Promise<void>;
  log: (message: string) => void;
  readCache?: (key: string) => Promise<Record<string, unknown> | null>;
  writeCache?: (key: string, body: Record<string, unknown>) => Promise<void>;
};

export function cookCacheMaterial(input: {
  ingredients: string[];
  slot: string;
  targetKcal: number;
  targetProteinG: number;
  targetFatG: number;
  targetCarbG: number;
  note: string;
  avoid: string[];
  stamp?: string;
  recent?: string[];
}): string {
  return JSON.stringify({
    v: 6,
    ingredients: [...input.ingredients].map((item) => item.trim()).filter((item) => item.length > 0).sort(),
    slot: input.slot,
    kcal: Math.round(input.targetKcal / 10) * 10,
    protein: Math.round(input.targetProteinG),
    fat: Math.round(input.targetFatG),
    carb: Math.round(input.targetCarbG),
    note: input.note.trim(),
    avoid: [...input.avoid].map((item) => item.trim()).filter((item) => item.length > 0).sort(),
    stamp: input.stamp ?? "",
    recent: [...(input.recent ?? [])].map((item) => item.trim()).filter((item) => item.length > 0).sort(),
  });
}

export function tokyoClock(now: Date): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const pick = (type: string) => parts.find((part) => part.type === type)?.value ?? "00";
  return `${pick("hour")}:${pick("minute")}:${pick("second")}`;
}

export function zeroHitIngredients(names: string[]): string[] {
  return [...new Set(names.map((name) => normalizeFoodName(name)).filter((name) => name.length > 0))].sort();
}

export async function cookCacheKey(material: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(material));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

const slotLabels: Record<string, string> = {
  breakfast: "朝食",
  lunch: "昼食",
  dinner: "夕食",
  snack: "間食",
};

export function tokyoDayStartUtc(now: Date): Date {
  const [year, month, day] = tokyoDateKey(now).split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day, -9, 0, 0));
}

export function aiDailyLimitFromEnv(env: CookEnv): number {
  return readNonNegativeInt(env.AI_DAILY_LIMIT, aiDailyLimitDefault);
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fail(code: string, message: string, status: number): Response {
  return json({ ok: false, code, message }, status);
}

export async function handleCookCoach(req: Request, deps: CookDeps): Promise<Response> {
  if (req.method !== "POST") {
    return fail("bad_request", "送信できませんでした。もう一度試してください。", 405);
  }
  const userId = await deps.userId(req);
  if (!userId) {
    return fail("unauthenticated", "ログインしてから、もう一度試してください。", 401);
  }
  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return fail("bad_request", "送信できませんでした。もう一度試してください。", 400);
  }
  const input = parseInput(payload);
  if (!input) {
    const blocked = explainRejectedTarget(payload);
    if (blocked) {
      return fail(blocked.code, blocked.message, 422);
    }
    return fail("bad_request", "食材を入れて、もう一度試してください。", 400);
  }
  const now = deps.now();
  // Plus の確認が一時的に失敗したら1回やり直す。それでもだめなら not_plus ではなく一時的なエラーにする。
  const plus = await checkGate(() => deps.isPlus(userId, now), { sleep: deps.sleep, log: deps.log, label: "plus" });
  if (plus === "unavailable") {
    return fail("provider_error", "献立を作れませんでした。しばらくしてからもう一度試してください。", 503);
  }
  if (plus === "no") {
    return fail("not_plus", "こちらはカロナビ+の機能です。", 403);
  }
  // 自炊コーチは外部へ何も送らないので、AIデータの同意は求めない。Plus の確認だけ行う。
  let recipes: CookRecipe[];
  try {
    recipes = await deps.loadRecipes();
  } catch {
    deps.log("cook-coach recipes failed");
    return fail("recipes_unavailable", "献立を作れませんでした。しばらくしてからもう一度試してください。", 503);
  }
  if (!Array.isArray(recipes) || recipes.length === 0) {
    return fail("recipes_unavailable", "献立を作れませんでした。しばらくしてからもう一度試してください。", 503);
  }
  const cacheKey = await cookCacheKey(cookCacheMaterial({
    ...input,
    stamp: recipeStamp(recipes),
    recent: input.recent,
  }));
  if (deps.readCache) {
    try {
      const hit = await deps.readCache(cacheKey);
      if (hit && Array.isArray(hit.patterns) && hit.patterns.length > 0) {
        return json({
          ...hit,
          cached: true,
          usage_id: null,
          retried: false,
          latency_ms: 0,
          input_tokens: 0,
          output_tokens: 0,
          cache_read_tokens: 0,
          cache_write_tokens: 0,
          calls: [],
        }, 200);
      }
    } catch {
      deps.log("cook-coach cache read failed");
    }
  }
  const started = Date.now();
  const selection = selectCookPlans(recipes, {
    ingredients: input.ingredients,
    slot: input.slot,
    target: input.target,
    note: input.note,
    avoid: input.avoid,
    recentNames: input.recent,
  });
  if (selection.a == null && deps.recordZeroHit) {
    try {
      await deps.recordZeroHit({
        ingredients: zeroHitIngredients(input.ingredients),
        atTime: tokyoClock(now),
      });
    } catch {
      deps.log("cook-coach zero hit log failed");
    }
  }
  const patterns = [
    selection.a ? patternJson("on_hand", selection.a) : null,
    selection.b ? patternJson("extra", selection.b) : null,
  ].filter((item) => item != null);
  const latencyMs = Math.max(0, Date.now() - started);
  const stored = {
    ok: true,
    retried: false,
    empty_message: patterns.length === 0 ? selection.emptyMessage : "",
    target: {
      kcal: input.target.kcal,
      protein_g: input.target.proteinG,
      fat_g: input.target.fatG,
      carb_g: input.target.carbG,
      slot: input.slot,
    },
    patterns,
  };
  const usageId: string | null = null;
  if (patterns.length > 0 && deps.writeCache) {
    try {
      await deps.writeCache(cacheKey, stored);
    } catch {
      deps.log("cook-coach cache write failed");
    }
  }
  return json({
    ...stored,
    cached: false,
    usage_id: usageId,
    latency_ms: latencyMs,
    input_tokens: 0,
    output_tokens: 0,
    cache_read_tokens: 0,
    cache_write_tokens: 0,
    calls: [],
  }, 200);
}

type CookInput = {
  ingredients: string[];
  slot: string;
  slotLabel: string;
  target: { kcal: number; proteinG: number; fatG: number; carbG: number };
  targetKcal: number;
  targetProteinG: number;
  targetFatG: number;
  targetCarbG: number;
  note: string;
  avoid: string[];
  recent: string[];
};

function parseInput(payload: unknown): CookInput | null {
  if (payload == null || typeof payload !== "object" || Array.isArray(payload)) {
    return null;
  }
  const body = payload as Record<string, unknown>;
  if (!Array.isArray(body.ingredients)) {
    return null;
  }
  const ingredients = body.ingredients
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item) => item.length > 0 && item.length <= 40)
    .slice(0, 20);
  if (ingredients.length === 0) {
    return null;
  }
  const slot = typeof body.slot === "string" ? body.slot : "";
  const slotLabel = slotLabels[slot];
  if (!slotLabel) {
    return null;
  }
  const targetKcal = clampNumber(body.target_kcal, 0, 1600);
  const targetProteinG = clampNumber(body.target_protein_g, 0, 250);
  const targetFatG = clampNumber(body.target_fat_g, 0, 200);
  const targetCarbG = clampNumber(body.target_carb_g, 0, 400);
  if (targetKcal == null || targetProteinG == null || targetFatG == null || targetCarbG == null) {
    return null;
  }
  if (targetKcal < 50) {
    return null;
  }
  const note = typeof body.note === "string" ? body.note.trim().slice(0, 80) : "";
  const avoid = Array.isArray(body.avoid)
    ? body.avoid
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0 && item.length <= 40)
      .slice(0, 20)
    : [];
  const recent = Array.isArray(body.recent_names)
    ? body.recent_names
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0 && item.length <= 40)
      .slice(0, 12)
    : [];
  return {
    ingredients,
    slot,
    slotLabel,
    target: {
      kcal: targetKcal,
      proteinG: targetProteinG,
      fatG: targetFatG,
      carbG: targetCarbG,
    },
    targetKcal,
    targetProteinG,
    targetFatG,
    targetCarbG,
    note,
    avoid,
    recent,
  };
}

export function explainRejectedTarget(payload: unknown): { code: string; message: string } | null {
  if (payload == null || typeof payload !== "object" || Array.isArray(payload)) {
    return null;
  }
  const body = payload as Record<string, unknown>;
  if (!Array.isArray(body.ingredients) || body.ingredients.length === 0) {
    return null;
  }
  const slot = typeof body.slot === "string" ? body.slot : "";
  if (!slotLabels[slot]) {
    return null;
  }
  const number = typeof body.target_kcal === "number"
    ? body.target_kcal
    : typeof body.target_kcal === "string"
    ? Number(body.target_kcal)
    : NaN;
  if (!Number.isFinite(number)) {
    return null;
  }
  if (number <= 0) {
    return { code: "already_met", message: "今日の目標は、もう足りています。" };
  }
  if (number < 50) {
    return { code: "target_small", message: "この食事の目標が少ないため、献立は作れません。" };
  }
  return null;
}

function clampNumber(value: unknown, min: number, max: number): number | null {
  const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  if (!Number.isFinite(number)) {
    return null;
  }
  return Math.min(max, Math.max(min, number));
}

function patternJson(kind: "on_hand" | "extra", dish: MeasuredDish) {
  return {
    kind,
    name: dish.name,
    minutes: dish.minutes ?? 0,
    steps: dish.steps,
    extras: dish.extras,
    kcal: dish.totals.kcal,
    protein_g: dish.totals.proteinG,
    fat_g: dish.totals.fatG,
    carb_g: dish.totals.carbG,
    gap_kcal: dish.gap.kcal,
    gap_protein_g: dish.gap.proteinG,
    gap_fat_g: dish.gap.fatG,
    gap_carb_g: dish.gap.carbG,
    within_tolerance: dish.within,
    gap_reason: dish.gapReason,
    omit_note: dish.omitNote,
    ingredients: dish.ingredients.map((item) => ({
      name: item.name,
      grams: item.grams,
      kcal: item.kcal,
      protein_g: item.proteinG,
      fat_g: item.fatG,
      carb_g: item.carbG,
      source: item.source,
      food_code: item.foodCode,
      official_name: item.officialName,
      extra: item.extra,
      assumed: item.assumed === true,
    })),
  };
}

type FetchJson = { ok: boolean; status: number; body: unknown; headers: Headers };

async function authedFetch(
  url: string,
  serviceKey: string,
  fetchImpl: FetchLike,
  init?: RequestInit,
): Promise<FetchJson> {
  const headers = new Headers(init?.headers);
  headers.set("apikey", serviceKey);
  headers.set("Authorization", `Bearer ${serviceKey}`);
  headers.set("Accept", "application/json");
  const response = await fetchImpl(url, { ...init, headers });
  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return { ok: response.ok, status: response.status, body, headers: response.headers };
}

function countFromContentRange(headers: Headers): number {
  const range = headers.get("content-range") ?? "";
  const total = range.split("/").pop();
  const count = Number(total);
  return Number.isFinite(count) && count >= 0 ? count : 0;
}

export function liveDeps(
  env: CookEnv = Deno.env.toObject(),
  fetchImpl: FetchLike = fetch,
): CookDeps {
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const base = (env.SUPABASE_URL ?? "").replace(/\/$/, "");
  return {
    env,
    now: () => new Date(),
    log: (message) => console.error(message),
    model: () => ({
      complete: () => Promise.reject(new Error("cook coach does not call a model")),
    }),
    async userId(req) {
      const header = req.headers.get("Authorization") ?? "";
      if (!header.toLowerCase().startsWith("bearer ")) {
        return null;
      }
      const anon = env.SUPABASE_ANON_KEY ?? "";
      if (!base || !anon) {
        return null;
      }
      const response = await fetchImpl(`${base}/auth/v1/user`, {
        headers: { Authorization: header, apikey: anon },
      });
      if (!response.ok) {
        return null;
      }
      const body = await response.json();
      const id = body && typeof body === "object" ? (body as { id?: unknown }).id : null;
      return typeof id === "string" && id.length > 0 ? id : null;
    },
    async isPlus(userId, now) {
      if (!base || !serviceKey) {
        throw new GateCheckError(null, "plus check not configured");
      }
      const cutoff = encodeURIComponent(now.toISOString());
      const url =
        `${base}/rest/v1/calonavi_plus_entitlements?user_id=eq.${userId}` +
        `&status=eq.active&expires_at=gt.${cutoff}&select=user_id&limit=1`;
      const result = await authedFetch(url, serviceKey, fetchImpl);
      return gateRowsExist(result);
    },
    async dailyCount(userId, since) {
      if (!base || !serviceKey) {
        return 0;
      }
      const sinceKey = encodeURIComponent(since.toISOString());
      const photo = await countRows(
        `${base}/rest/v1/meal_photo_analyses?user_id=eq.${userId}&created_at=gte.${sinceKey}&select=id`,
        serviceKey,
        fetchImpl,
      );
      const shared = await countRows(
        `${base}/rest/v1/ai_feature_uses?user_id=eq.${userId}&created_at=gte.${sinceKey}` +
          `&feature=eq.ai_search&select=id`,
        serviceKey,
        fetchImpl,
      );
      return photo + shared;
    },
    async insertUsage(row) {
      if (!base || !serviceKey) {
        return null;
      }
      const result = await authedFetch(`${base}/rest/v1/ai_feature_uses`, serviceKey, fetchImpl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          user_id: row.userId,
          feature: "cook_coach",
          provider: row.provider,
          model: row.model,
          input_tokens: row.inputTokens,
          output_tokens: row.outputTokens,
          cache_read_tokens: row.cacheReadTokens,
          cache_write_tokens: row.cacheWriteTokens,
          estimated_cost_jpy: row.estimatedCostJpy,
          latency_ms: row.latencyMs,
          retried: row.retried,
          had_note: row.hadNote,
          meal_slot: row.mealSlot,
          success: row.success,
          error_code: row.errorCode,
          advertising_use: false,
        }),
      });
      if (!result.ok) {
        return null;
      }
      const first = Array.isArray(result.body) ? result.body[0] : result.body;
      const id = first && typeof first === "object" ? (first as { id?: unknown }).id : null;
      return typeof id === "string" ? id : null;
    },
    async readCache(key) {
      if (!base || !serviceKey) {
        return null;
      }
      const nowKey = encodeURIComponent(new Date().toISOString());
      const result = await authedFetch(
        `${base}/rest/v1/cook_coach_cache?cache_key=eq.${encodeURIComponent(key)}` +
          `&expires_at=gt.${nowKey}&select=response&limit=1`,
        serviceKey,
        fetchImpl,
      );
      if (!result.ok || !Array.isArray(result.body) || result.body.length === 0) {
        return null;
      }
      const row = result.body[0];
      const response = row && typeof row === "object" ? (row as { response?: unknown }).response : null;
      return response != null && typeof response === "object" && !Array.isArray(response)
        ? response as Record<string, unknown>
        : null;
    },
    async writeCache(key, body) {
      if (!base || !serviceKey) {
        return;
      }
      await authedFetch(
        `${base}/rest/v1/cook_coach_cache?on_conflict=cache_key`,
        serviceKey,
        fetchImpl,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Prefer: "resolution=merge-duplicates",
          },
          body: JSON.stringify({
            cache_key: key,
            response: body,
            expires_at: new Date(Date.now() + cacheTtlMs).toISOString(),
          }),
        },
      );
    },
    async loadRecipes() {
      if (!base || !serviceKey) {
        throw new Error("recipes unavailable");
      }
      const select = [
        "id",
        "name_template",
        "genre",
        "category",
        "method",
        "minutes",
        "steps",
        "cook_recipe_options(slot_key,role,label,food_code,base_grams,sort_order,match_names,staple,official_foods(name,kcal,protein_g,fat_g,carb_g))",
      ].join(",");
      const result = await authedFetch(
        `${base}/rest/v1/cook_recipes?select=${encodeURIComponent(select)}&order=id.asc`,
        serviceKey,
        fetchImpl,
      );
      if (!result.ok || !Array.isArray(result.body)) {
        throw new Error("recipes unavailable");
      }
      return cookRecipesFromDb(result.body);
    },
    async recordZeroHit(row) {
      if (!base || !serviceKey || row.ingredients.length === 0) {
        return;
      }
      await authedFetch(`${base}/rest/v1/cook_zero_on_hand`, serviceKey, fetchImpl, {
        method: "POST",
        headers: { "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify({
          ingredients: row.ingredients,
          at_time: row.atTime,
        }),
      });
    },
    async lookupFoods(names) {
      if (!base || !serviceKey || names.length === 0) {
        return [];
      }
      const unique = [...new Set(names.map((name) => name.trim()).filter((name) => name.length > 0))].slice(0, 24);
      const foods: FoodRow[] = [];
      for (const name of unique) {
        const found = await lookupOne(base, serviceKey, fetchImpl, name);
        for (const food of found) {
          if (!foods.some((item) => item.foodCode === food.foodCode)) {
            foods.push(food);
          }
        }
      }
      return foods;
    },
  };
}

async function countRows(url: string, serviceKey: string, fetchImpl: FetchLike): Promise<number> {
  const result = await authedFetch(url, serviceKey, fetchImpl, {
    method: "GET",
    headers: { Prefer: "count=exact", Range: "0-0" },
  });
  if (!result.ok) {
    return 0;
  }
  return countFromContentRange(result.headers);
}

async function lookupOne(
  base: string,
  serviceKey: string,
  fetchImpl: FetchLike,
  name: string,
): Promise<FoodRow[]> {
  const normalized = normalizeFoodName(name);
  if (!normalized) {
    return [];
  }
  const key = encodeURIComponent(normalized);
  const select = "food_code,name,display_name,normalized_name,kcal,protein_g,fat_g,carb_g,base_amount";
  const byName = await authedFetch(
    `${base}/rest/v1/official_foods?normalized_name=eq.${key}&select=${select}&limit=8`,
    serviceKey,
    fetchImpl,
  );
  const rows = rowsFrom(byName.body);
  const alias = await authedFetch(
    `${base}/rest/v1/official_food_aliases?normalized=eq.${key}&select=food_code,normalized,is_candidate&limit=8`,
    serviceKey,
    fetchImpl,
  );
  const aliasRows = Array.isArray(alias.body) ? alias.body : [];
  const codes = aliasRows
    .map((item) => item && typeof item === "object" ? (item as { food_code?: unknown }).food_code : null)
    .filter((code): code is string => typeof code === "string");
  if (codes.length > 0) {
    const listed = codes.map((code) => encodeURIComponent(code)).join(",");
    const linked = await authedFetch(
      `${base}/rest/v1/official_foods?food_code=in.(${listed})&select=${select}&limit=8`,
      serviceKey,
      fetchImpl,
    );
    rows.push(...rowsFrom(linked.body));
  }
  const aliasByCode = new Map<string, FoodRow["aliases"]>();
  for (const item of aliasRows) {
    if (item == null || typeof item !== "object") {
      continue;
    }
    const row = item as { food_code?: unknown; normalized?: unknown; is_candidate?: unknown };
    if (typeof row.food_code !== "string" || typeof row.normalized !== "string") {
      continue;
    }
    const list = aliasByCode.get(row.food_code) ?? [];
    list.push({ normalized: row.normalized, candidate: row.is_candidate === true });
    aliasByCode.set(row.food_code, list);
  }
  return rows.map((food) => ({
    ...food,
    aliases: aliasByCode.get(food.foodCode) ?? food.aliases,
  }));
}

function rowsFrom(body: unknown): FoodRow[] {
  if (!Array.isArray(body)) {
    return [];
  }
  const foods: FoodRow[] = [];
  for (const item of body) {
    if (item == null || typeof item !== "object") {
      continue;
    }
    const row = item as Record<string, unknown>;
    const foodCode = typeof row.food_code === "string" ? row.food_code : "";
    const name = typeof row.name === "string" ? row.name : "";
    if (!foodCode || !name) {
      continue;
    }
    const kcal = numberOrNull(row.kcal);
    foods.push({
      foodCode,
      name,
      displayName: typeof row.display_name === "string" && row.display_name.trim()
        ? row.display_name
        : name,
      normalizedName: typeof row.normalized_name === "string" ? row.normalized_name : "",
      aliases: [],
      kcal,
      proteinG: numberOrNull(row.protein_g),
      fatG: numberOrNull(row.fat_g),
      carbG: numberOrNull(row.carb_g),
      baseAmount: numberOrNull(row.base_amount) ?? 100,
    });
  }
  return foods;
}

function numberOrNull(value: unknown): number | null {
  const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(number) ? number : null;
}
