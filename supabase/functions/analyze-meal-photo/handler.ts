// 写真をモデルに渡し、結果の JSON だけを返す。写真は保存しない。
// 鍵と単価は環境変数。アプリには置かない。

import { jpegBase64WithinEdge } from "./image.ts";
import {
  checkPhotoCaps,
  estimateCostJpy,
  heavyModelDefault,
  lightModelDefault,
  photoLimitsFromEnv,
  presentText,
  routePhotoModel,
  summarizeUsage,
  tierCallOptions,
  tokenPricesFromEnv,
  tokyoMonthStartUtc,
  type PhotoAiEnv,
  type PhotoLimits,
  type PhotoTier,
  type UsageRow,
} from "./policy.ts";
import {
  createPhotoAiProvider,
  PhotoAiCallError,
  PhotoAiConfigError,
  type FetchLike,
  type PhotoAiProvider,
} from "./provider.ts";
import { jpegBytesFromBase64, parseModelJson, parsePhotoMealEstimate } from "./validate.ts";
import { photoMealMessage, type PhotoMealCode } from "./messages.ts";

export type PhotoEnv = PhotoAiEnv & {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  ANTHROPIC_API_KEY?: string;
  PHOTO_AI_PROVIDER?: string;
  PHOTO_AI_LIGHT_MODEL?: string;
  PHOTO_AI_HEAVY_MODEL?: string;
};

export type UsageInsert = {
  userId: string;
  provider: string;
  model: string;
  tier: PhotoTier;
  inputTokens: number;
  outputTokens: number;
  estimatedCostJpy: number;
  latencyMs: number;
  hadName: boolean;
  hadAmount: boolean;
  hadNote: boolean;
  success: boolean;
  errorCode: string | null;
};

export type AnalyzeDeps = {
  env: PhotoEnv;
  now: () => Date;
  userId: (req: Request) => Promise<string | null>;
  isPlus: (userId: string, now: Date) => Promise<boolean>;
  usageRows: (userId: string, since: Date) => Promise<UsageRow[]>;
  insertUsage: (row: UsageInsert) => Promise<string | null>;
  providerFor: (name: string) => PhotoAiProvider;
  log: (message: string) => void;
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fail(code: PhotoMealCode, status: number, limits?: PhotoLimits): Response {
  return json({
    ok: false,
    code,
    message: photoMealMessage(code, limits),
  }, status);
}

function modelFor(tier: PhotoTier, env: PhotoEnv): string {
  if (tier === "light") {
    return env.PHOTO_AI_LIGHT_MODEL?.trim() || lightModelDefault;
  }
  return env.PHOTO_AI_HEAVY_MODEL?.trim() || heavyModelDefault;
}

function clip(value: unknown, max: number): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, max);
}

export function estimateJson(estimate: {
  dishName: string;
  amount: string;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  confidence: number;
  items: Array<{
    name: string;
    amount: string;
    kcal: number;
    proteinG: number;
    fatG: number;
    carbG: number;
  }>;
}) {
  return {
    dish_name: estimate.dishName,
    amount: estimate.amount,
    kcal: estimate.kcal,
    protein_g: estimate.proteinG,
    fat_g: estimate.fatG,
    carb_g: estimate.carbG,
    confidence: estimate.confidence,
    items: estimate.items.map((item) => ({
      name: item.name,
      amount: item.amount,
      kcal: item.kcal,
      protein_g: item.proteinG,
      fat_g: item.fatG,
      carb_g: item.carbG,
    })),
  };
}

export async function handleAnalyzeMealPhoto(
  req: Request,
  deps: AnalyzeDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return fail("bad_request", 405);
  }
  const userId = await deps.userId(req);
  if (!userId) {
    return fail("unauthenticated", 401);
  }
  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return fail("bad_request", 400);
  }
  if (payload == null || typeof payload !== "object" || Array.isArray(payload)) {
    return fail("bad_request", 400);
  }
  const body = payload as Record<string, unknown>;
  const image = typeof body.image_base64 === "string" ? body.image_base64 : "";
  if (!jpegBytesFromBase64(image)) {
    return fail("invalid_image", 422);
  }
  const dishName = clip(body.dish_name, 80);
  const amount = clip(body.amount, 80);
  const note = clip(body.note, 100);
  const hasName = presentText(dishName);
  const hasAmount = presentText(amount);
  const hasNote = presentText(note);
  const now = deps.now();

  const plus = await deps.isPlus(userId, now);
  if (!plus) {
    return fail("not_plus", 403);
  }

  const limits = photoLimitsFromEnv(deps.env);
  const rows = await deps.usageRows(userId, tokyoMonthStartUtc(now));
  const usage = summarizeUsage(rows, now);
  const cap = checkPhotoCaps(usage, limits);
  if (cap) {
    return fail(cap, 429, limits);
  }
  const route = routePhotoModel({
    hasName,
    hasAmount,
    heavyMonthCount: usage.heavyMonthCount,
    heavyMonthlyLimit: limits.heavyMonthly,
  });
  if (route.kind === "need_details") {
    return fail("need_details", 429);
  }

  const providerName = deps.env.PHOTO_AI_PROVIDER?.trim() || "anthropic";
  let provider: PhotoAiProvider;
  try {
    provider = deps.providerFor(providerName);
  } catch (error) {
    if (error instanceof PhotoAiConfigError) {
      return fail(error.code, 503);
    }
    throw error;
  }
  const apiKey = deps.env.ANTHROPIC_API_KEY ?? "";
  if (provider.id === "anthropic" && !apiKey.trim()) {
    return fail("missing_key", 503);
  }

  const tier = route.tier;
  const model = modelFor(tier, deps.env);
  const options = tierCallOptions(tier, deps.env);
  const imageForModel = await jpegBase64WithinEdge(image, options.imageMaxEdge);
  const started = Date.now();
  const usageFields = {
    hadName: hasName,
    hadAmount: hasAmount,
    hadNote: hasNote,
  };
  try {
    const result = await provider.analyze(
      {
        model,
        tier,
        imageJpegBase64: imageForModel,
        dishName: hasName ? dishName : null,
        amount: hasAmount ? amount : null,
        note: hasNote ? note : null,
        maxTokens: options.maxTokens,
        thinking: options.thinking,
        effort: options.effort,
      },
      apiKey,
    );
    const latencyMs = Math.max(0, Date.now() - started);
    const cost = estimateCostJpy({
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      cacheReadTokens: result.usage.cacheReadTokens,
      cacheWriteTokens: result.usage.cacheWriteTokens,
      prices: tokenPricesFromEnv(tier, deps.env),
    });
    let parsed: ReturnType<typeof parsePhotoMealEstimate> = null;
    try {
      parsed = parsePhotoMealEstimate(parseModelJson(result.text));
    } catch {
      parsed = null;
    }
    const usageId = await deps.insertUsage({
      userId,
      provider: provider.id,
      model,
      tier,
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      estimatedCostJpy: cost,
      latencyMs,
      ...usageFields,
      success: parsed != null,
      errorCode: parsed == null ? "invalid_result" : null,
    });
    if (parsed == null) {
      return fail("invalid_result", 422);
    }
    return json({
      ok: true,
      usage_id: usageId,
      estimate: estimateJson(parsed),
    }, 200);
  } catch (error) {
    const latencyMs = Math.max(0, Date.now() - started);
    if (error instanceof PhotoAiConfigError) {
      return fail(error.code, 503);
    }
    if (error instanceof PhotoAiCallError) {
      await deps.insertUsage({
        userId,
        provider: provider.id,
        model,
        tier,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostJpy: 0,
        latencyMs,
        ...usageFields,
        success: false,
        errorCode: "provider_error",
      });
      deps.log("analyze-meal-photo provider failed");
      return fail("provider_error", 503);
    }
    deps.log("analyze-meal-photo failed");
    return fail("provider_error", 500);
  }
}

type FetchJson = {
  ok: boolean;
  status: number;
  body: unknown;
};

async function authedGet(
  url: string,
  serviceKey: string,
  fetchImpl: FetchLike,
): Promise<FetchJson> {
  const response = await fetchImpl(url, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      Accept: "application/json",
    },
  });
  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return { ok: response.ok, status: response.status, body };
}

export function liveDeps(
  env: PhotoEnv = Deno.env.toObject(),
  fetchImpl: FetchLike = fetch,
): AnalyzeDeps {
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const base = (env.SUPABASE_URL ?? "").replace(/\/$/, "");
  return {
    env,
    now: () => new Date(),
    log: (message) => console.error(message),
    providerFor: (name) => createPhotoAiProvider(name, fetchImpl),
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
      const id = body && typeof body === "object"
        ? (body as { id?: unknown }).id
        : null;
      return typeof id === "string" && id.length > 0 ? id : null;
    },
    async isPlus(userId, now) {
      if (!base || !serviceKey) {
        return false;
      }
      const cutoff = encodeURIComponent(now.toISOString());
      const url =
        `${base}/rest/v1/calonavi_plus_entitlements?user_id=eq.${userId}` +
        `&status=eq.active&expires_at=gt.${cutoff}&select=user_id&limit=1`;
      const result = await authedGet(url, serviceKey, fetchImpl);
      return result.ok && Array.isArray(result.body) && result.body.length > 0;
    },
    async usageRows(userId, since) {
      if (!base || !serviceKey) {
        return [];
      }
      const sinceParam = encodeURIComponent(since.toISOString());
      const photoUrl =
        `${base}/rest/v1/meal_photo_analyses?user_id=eq.${userId}` +
        `&created_at=gte.${sinceParam}&select=created_at,tier,estimated_cost_jpy`;
      const textUrl =
        `${base}/rest/v1/meal_text_lookups?user_id=eq.${userId}` +
        `&created_at=gte.${sinceParam}&select=created_at,estimated_cost_jpy`;
      const [photo, text] = await Promise.all([
        authedGet(photoUrl, serviceKey, fetchImpl),
        authedGet(textUrl, serviceKey, fetchImpl),
      ]);
      return [
        ...usageRowsFromBody(photo.ok ? photo.body : [], true),
        ...usageRowsFromBody(text.ok ? text.body : [], false),
      ];
    },
    async insertUsage(row) {
      if (!base || !serviceKey) {
        return null;
      }
      const response = await fetchImpl(`${base}/rest/v1/meal_photo_analyses`, {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          user_id: row.userId,
          provider: row.provider,
          model: row.model,
          tier: row.tier,
          input_tokens: row.inputTokens,
          output_tokens: row.outputTokens,
          estimated_cost_jpy: row.estimatedCostJpy,
          latency_ms: row.latencyMs,
          had_name: row.hadName,
          had_amount: row.hadAmount,
          had_note: row.hadNote,
          success: row.success,
          error_code: row.errorCode,
          advertising_use: false,
        }),
      });
      if (!response.ok) {
        return null;
      }
      const body = await response.json();
      const first = Array.isArray(body) ? body[0] : body;
      const id = first && typeof first === "object"
        ? (first as { id?: unknown }).id
        : null;
      return typeof id === "string" ? id : null;
    },
  };
}

function usageRowsFromBody(body: unknown, requireTier: boolean): UsageRow[] {
  if (!Array.isArray(body)) {
    return [];
  }
  const rows: UsageRow[] = [];
  for (const item of body) {
    if (item == null || typeof item !== "object") {
      continue;
    }
    const row = item as Record<string, unknown>;
    const tier = row.tier === "heavy"
      ? "heavy"
      : row.tier === "light"
      ? "light"
      : requireTier
      ? null
      : "light";
    const createdAt = typeof row.created_at === "string" ? row.created_at : "";
    const cost = typeof row.estimated_cost_jpy === "number"
      ? row.estimated_cost_jpy
      : Number(row.estimated_cost_jpy);
    if (!tier || !createdAt || !Number.isFinite(cost)) {
      continue;
    }
    rows.push({ createdAt, tier, costJpy: cost });
  }
  return rows;
}
