// 検索語だけを軽いモデルへ渡す。食品データベースへは書き込まない。
// 鍵と単価は環境変数。アプリには置かない。

import {
  collectIds,
  insertFoodCollections,
  type FoodCollectionRow,
} from "../ai-food-collection.ts";
import { hasAiDataConsent } from "../_shared/ai_data_consent.ts";
import {
  cookCoachUsageQuery,
  estimateCostJpy,
  lightModelDefault,
  tokenPricesFromEnv,
  tokyoMonthStartUtc,
  type UsageRow,
} from "../analyze-meal-photo/policy.ts";
import { parseModelJson } from "../analyze-meal-photo/validate.ts";
import {
  textLookupMessage,
  type TextLookupCode,
} from "./messages.ts";
import {
  lookupUsageFromRows,
  textLookupLimitsFromEnv,
  type LookupUsage,
  type TextLookupEnv,
  type TextLookupLimits,
} from "./policy.ts";
import {
  callLookupModel,
  LookupCallError,
  type FetchLike,
  type LookupCallUsage,
} from "./provider.ts";
import {
  candidateJson,
  normalizeFoodQuery,
  parseLookupCandidates,
  relevantCandidates,
  type LookupCandidate,
} from "./validate.ts";

export type TextEnv = TextLookupEnv & {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  ANTHROPIC_API_KEY?: string;
  PHOTO_AI_PROVIDER?: string;
  PHOTO_AI_LIGHT_MODEL?: string;
};

export type CacheRow = {
  model: string;
  expiresAt: string;
  candidates: LookupCandidate[];
};

export type UsageInsert = {
  userId: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCostJpy: number;
  latencyMs: number;
  cacheHit: boolean;
  success: boolean;
  errorCode: string | null;
};

export type LookupDeps = {
  env: TextEnv;
  now: () => Date;
  userId: (req: Request) => Promise<string | null>;
  isPlus: (userId: string, now: Date) => Promise<boolean>;
  hasConsent?: (userId: string) => Promise<boolean>;
  usage: (userId: string, since: Date, now: Date) => Promise<LookupUsage>;
  readCache: (userId: string, queryKey: string) => Promise<CacheRow | null>;
  writeCache: (userId: string, queryKey: string, row: CacheRow) => Promise<void>;
  insertUsage: (row: UsageInsert) => Promise<string | null>;
  insertCollections?: (rows: FoodCollectionRow[]) => Promise<Array<string | null>>;
  complete: (args: {
    model: string;
    maxTokens: number;
    query: string;
    apiKey: string;
  }) => Promise<{ text: string; usage: LookupCallUsage }>;
  log: (message: string) => void;
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fail(
  code: TextLookupCode,
  status: number,
  limits?: TextLookupLimits,
): Response {
  return json({
    ok: false,
    code,
    message: textLookupMessage(code, limits),
  }, status);
}

function freshCache(row: CacheRow, model: string, now: Date): boolean {
  if (row.model !== model || row.candidates.length === 0) {
    return false;
  }
  const expires = new Date(row.expiresAt);
  return !Number.isNaN(expires.getTime()) && expires.getTime() > now.getTime();
}

export async function handleLookupFoodText(
  req: Request,
  deps: LookupDeps,
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
  const raw = (payload as Record<string, unknown>).query;
  const query = typeof raw === "string" ? normalizeFoodQuery(raw) : "";
  if (!query) {
    return fail("bad_request", 400);
  }

  const plus = await deps.isPlus(userId, deps.now());
  if (!plus) {
    return fail("not_plus", 403);
  }
  if (deps.hasConsent && !(await deps.hasConsent(userId))) {
    return fail("consent_required", 403);
  }

  const providerName = deps.env.PHOTO_AI_PROVIDER?.trim() || "anthropic";
  if (providerName !== "anthropic") {
    return fail("provider_unwired", 503);
  }
  const apiKey = deps.env.ANTHROPIC_API_KEY ?? "";
  if (!apiKey.trim()) {
    return fail("missing_key", 503);
  }

  const limits = textLookupLimitsFromEnv(deps.env);
  const now = deps.now();
  const usage = await deps.usage(userId, tokyoMonthStartUtc(now), now);
  if (usage.dayCount >= limits.daily) {
    return fail("daily_cap", 429, limits);
  }
  if (limits.monthly != null && usage.monthCount >= limits.monthly) {
    return fail("monthly_cap", 429, limits);
  }

  const model = deps.env.PHOTO_AI_LIGHT_MODEL?.trim() || lightModelDefault;
  const cached = await deps.readCache(userId, query);
  const cachedRelevant = cached && freshCache(cached, model, now)
    ? relevantCandidates(query, cached.candidates)
    : null;
  if (cached && cachedRelevant) {
    const usageId = await deps.insertUsage({
      userId,
      provider: "anthropic",
      model,
      inputTokens: 0,
      outputTokens: 0,
      estimatedCostJpy: 0,
      latencyMs: 0,
      cacheHit: true,
      success: true,
      errorCode: null,
    });
    const ids = await collectIds(
      deps.insertCollections,
      cachedRelevant.map((candidate) => collectionRow(userId, model, candidate)),
    );
    return json({
      ok: true,
      usage_id: usageId,
      cache_hit: true,
      candidates: withCollectionIds(cachedRelevant, ids),
    }, 200);
  }

  if (limits.spendJpy != null && usage.monthSpendJpy >= limits.spendJpy) {
    return fail("spend_cap", 429, limits);
  }

  const started = Date.now();
  try {
    const result = await deps.complete({
      model,
      maxTokens: limits.maxTokens,
      query,
      apiKey,
    });
    const latencyMs = Math.max(0, Date.now() - started);
    const cost = estimateCostJpy({
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      cacheReadTokens: result.usage.cacheReadTokens,
      cacheWriteTokens: result.usage.cacheWriteTokens,
      prices: tokenPricesFromEnv("light", deps.env),
    });
    let candidates: LookupCandidate[] | null = null;
    try {
      const parsed = parseLookupCandidates(parseModelJson(result.text));
      candidates = parsed ? relevantCandidates(query, parsed) : null;
    } catch {
      candidates = null;
    }
    const usageId = await deps.insertUsage({
      userId,
      provider: "anthropic",
      model,
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      estimatedCostJpy: cost,
      latencyMs,
      cacheHit: false,
      success: candidates != null,
      errorCode: candidates == null ? "invalid_result" : null,
    });
    if (!candidates) {
      return fail("invalid_result", 422);
    }
    const expires = new Date(now.getTime() + limits.cacheTtlHours * 60 * 60 * 1000);
    await deps.writeCache(userId, query, {
      model,
      expiresAt: expires.toISOString(),
      candidates,
    });
    const ids = await collectIds(
      deps.insertCollections,
      candidates.map((candidate) => collectionRow(userId, model, candidate)),
    );
    return json({
      ok: true,
      usage_id: usageId,
      cache_hit: false,
      candidates: withCollectionIds(candidates, ids),
    }, 200);
  } catch (error) {
    const latencyMs = Math.max(0, Date.now() - started);
    if (error instanceof LookupCallError) {
      await deps.insertUsage({
        userId,
        provider: "anthropic",
        model,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostJpy: 0,
        latencyMs,
        cacheHit: false,
        success: false,
        errorCode: "provider_error",
      });
      deps.log("lookup-food-text provider failed");
      return fail("provider_error", 503);
    }
    deps.log("lookup-food-text failed");
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

function costRows(body: unknown): UsageRow[] {
  if (!Array.isArray(body)) {
    return [];
  }
  const rows: UsageRow[] = [];
  for (const item of body) {
    if (item == null || typeof item !== "object") {
      continue;
    }
    const row = item as Record<string, unknown>;
    const createdAt = typeof row.created_at === "string" ? row.created_at : "";
    const cost = typeof row.estimated_cost_jpy === "number"
      ? row.estimated_cost_jpy
      : Number(row.estimated_cost_jpy);
    if (!createdAt || !Number.isFinite(cost)) {
      continue;
    }
    const tier = row.tier === "heavy" ? "heavy" : "light";
    rows.push({ createdAt, tier, costJpy: cost });
  }
  return rows;
}

function collectionRow(
  userId: string,
  model: string,
  candidate: LookupCandidate,
): FoodCollectionRow {
  return {
    userId,
    sourcePath: "ai_search",
    normalizedName: normalizeFoodQuery(candidate.name),
    chainName: candidate.chainName,
    amount: candidate.amount,
    kcal: candidate.kcal,
    proteinG: candidate.proteinG,
    fatG: candidate.fatG,
    carbG: candidate.carbG,
    model,
  };
}

function withCollectionIds(
  candidates: LookupCandidate[],
  ids: Array<string | null>,
) {
  return candidates.map((candidate, index) => ({
    ...candidateJson(candidate),
    collection_id: ids[index],
  }));
}

function candidatesFromCache(body: unknown): LookupCandidate[] | null {
  return parseLookupCandidates(
    body != null && typeof body === "object"
      ? { candidates: (body as { candidates?: unknown }).candidates }
      : null,
  );
}

export function liveDeps(
  env: TextEnv = Deno.env.toObject(),
  fetchImpl: FetchLike = fetch,
): LookupDeps {
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const base = (env.SUPABASE_URL ?? "").replace(/\/$/, "");
  return {
    env,
    now: () => new Date(),
    log: (message) => console.error(message),
    complete: (args) => callLookupModel({ ...args, fetchImpl }),
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
    hasConsent(userId) {
      return hasAiDataConsent({ base, serviceKey, userId, fetchImpl });
    },
    async usage(userId, since, now) {
      if (!base || !serviceKey) {
        return { dayCount: 0, monthCount: 0, monthSpendJpy: 0 };
      }
      const sinceParam = encodeURIComponent(since.toISOString());
      const textUrl =
        `${base}/rest/v1/meal_text_lookups?user_id=eq.${userId}` +
        `&created_at=gte.${sinceParam}&select=created_at,estimated_cost_jpy`;
      const photoUrl =
        `${base}/rest/v1/meal_photo_analyses?user_id=eq.${userId}` +
        `&created_at=gte.${sinceParam}&select=created_at,tier,estimated_cost_jpy`;
      const cookUrl =
        `${base}/rest/v1/ai_feature_uses?${cookCoachUsageQuery(userId, since.toISOString())}`;
      const [text, photo, cook] = await Promise.all([
        authedGet(textUrl, serviceKey, fetchImpl),
        authedGet(photoUrl, serviceKey, fetchImpl),
        authedGet(cookUrl, serviceKey, fetchImpl),
      ]);
      return lookupUsageFromRows({
        textRows: text.ok ? costRows(text.body) : [],
        photoRows: photo.ok ? costRows(photo.body) : [],
        cookRows: cook.ok ? costRows(cook.body) : [],
        now,
      });
    },
    async readCache(userId, queryKey) {
      if (!base || !serviceKey) {
        return null;
      }
      const url =
        `${base}/rest/v1/ai_food_estimate_cache?user_id=eq.${encodeURIComponent(userId)}` +
        `&query_key=eq.${encodeURIComponent(queryKey)}` +
        `&select=model,expires_at,candidates&limit=1`;
      const result = await authedGet(url, serviceKey, fetchImpl);
      if (!result.ok || !Array.isArray(result.body) || result.body.length === 0) {
        return null;
      }
      const row = result.body[0];
      if (row == null || typeof row !== "object") {
        return null;
      }
      const record = row as Record<string, unknown>;
      const candidates = candidatesFromCache(record);
      const model = typeof record.model === "string" ? record.model : "";
      const expiresAt = typeof record.expires_at === "string" ? record.expires_at : "";
      if (!candidates || !model || !expiresAt) {
        return null;
      }
      return { model, expiresAt, candidates };
    },
    async writeCache(userId, queryKey, row) {
      if (!base || !serviceKey) {
        return;
      }
      await fetchImpl(
        `${base}/rest/v1/ai_food_estimate_cache?on_conflict=user_id,query_key`,
        {
          method: "POST",
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
            Prefer: "resolution=merge-duplicates",
          },
          body: JSON.stringify({
            user_id: userId,
            query_key: queryKey,
            model: row.model,
            expires_at: row.expiresAt,
            candidates: row.candidates.map(candidateJson),
          }),
        },
      );
    },
    insertCollections(rows) {
      return insertFoodCollections(base, serviceKey, fetchImpl, rows);
    },
    async insertUsage(row) {
      if (!base || !serviceKey) {
        return null;
      }
      const response = await fetchImpl(`${base}/rest/v1/meal_text_lookups`, {
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
          input_tokens: row.inputTokens,
          output_tokens: row.outputTokens,
          estimated_cost_jpy: row.estimatedCostJpy,
          latency_ms: row.latencyMs,
          cache_hit: row.cacheHit,
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
