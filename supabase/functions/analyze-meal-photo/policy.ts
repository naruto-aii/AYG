// 写真で登録の振り分け、回数、費用。写真も API キーも持たない。
// 1日の回数は、写真で登録と AIで探すの合計。月の回数と費用は、環境変数が無いあいだは止めない。

export const combinedAiDailyLimitDefault = 15;
export const photoDailyLimitDefault = combinedAiDailyLimitDefault;
export const photoHeavyMonthlyLimitDefault = 20;

export const lightModelDefault = "claude-haiku-5-5";
export const heavyModelDefault = "claude-sonnet-5-5";

// 単価は USD / 100万トークン。円は PHOTO_AI_USD_JPY。キャッシュ書き込みの初期値は入力の 1.25 倍。
export const usdJpyDefault = 158;
export const lightInputUsdPerMillionDefault = 0.1;
export const lightOutputUsdPerMillionDefault = 0.5;
export const lightCacheReadUsdPerMillionDefault = 0.01;
export const lightCacheWriteUsdPerMillionDefault = 0.125;
export const heavyInputUsdPerMillionDefault = 2;
export const heavyOutputUsdPerMillionDefault = 10;
export const heavyCacheReadUsdPerMillionDefault = 0.1;
export const heavyCacheWriteUsdPerMillionDefault = 2.5;

export const maxTokensDefault = 300;
export const imageMaxEdgeDefault = 1024;

export type PhotoTier = "light" | "heavy";
export type ThinkingMode = "on" | "off";

export type UsageRow = {
  createdAt: string;
  tier: PhotoTier;
  costJpy: number;
};

export type UsageSnapshot = {
  dayCount: number;
  monthCount: number;
  heavyMonthCount: number;
  monthSpendJpy: number;
};

export type CapCode = "daily_cap" | "monthly_cap" | "spend_cap";

export type PhotoLimits = {
  daily: number;
  monthly: number | null;
  heavyMonthly: number;
  spendJpy: number | null;
};

export const defaultPhotoLimits: PhotoLimits = {
  daily: photoDailyLimitDefault,
  monthly: null,
  heavyMonthly: photoHeavyMonthlyLimitDefault,
  spendJpy: null,
};

export type PhotoAiEnv = {
  AI_COMBINED_DAILY_LIMIT?: string;
  AI_DAILY_LIMIT?: string;
  PHOTO_AI_DAILY_LIMIT?: string;
  PHOTO_AI_MONTHLY_LIMIT?: string;
  PHOTO_AI_HEAVY_MONTHLY_LIMIT?: string;
  PHOTO_AI_MONTHLY_SPEND_JPY?: string;
  PHOTO_AI_USD_JPY?: string;
  PHOTO_AI_LIGHT_INPUT_USD_PER_MILLION?: string;
  PHOTO_AI_LIGHT_OUTPUT_USD_PER_MILLION?: string;
  PHOTO_AI_LIGHT_CACHE_READ_USD_PER_MILLION?: string;
  PHOTO_AI_LIGHT_CACHE_WRITE_USD_PER_MILLION?: string;
  PHOTO_AI_HEAVY_INPUT_USD_PER_MILLION?: string;
  PHOTO_AI_HEAVY_OUTPUT_USD_PER_MILLION?: string;
  PHOTO_AI_HEAVY_CACHE_READ_USD_PER_MILLION?: string;
  PHOTO_AI_HEAVY_CACHE_WRITE_USD_PER_MILLION?: string;
  PHOTO_AI_MAX_TOKENS?: string;
  PHOTO_AI_LIGHT_MAX_TOKENS?: string;
  PHOTO_AI_HEAVY_MAX_TOKENS?: string;
  PHOTO_AI_LIGHT_THINKING?: string;
  PHOTO_AI_HEAVY_THINKING?: string;
  PHOTO_AI_LIGHT_EFFORT?: string;
  PHOTO_AI_HEAVY_EFFORT?: string;
  PHOTO_AI_LIGHT_IMAGE_MAX_EDGE?: string;
  PHOTO_AI_HEAVY_IMAGE_MAX_EDGE?: string;
};

export type RouteDecision =
  | { kind: "model"; tier: PhotoTier }
  | { kind: "need_details" };

export function presentText(value: string | null | undefined): boolean {
  return (value ?? "").trim().length > 0;
}

// 補足は見ない。料理名と量が両方あるときだけ軽いモデル。
// 写真だけ、または片方だけのときは高性能。
// 高性能の月間回数を超えたら、両方あるときだけ軽いモデルに落とす。
export function routePhotoModel(args: {
  hasName: boolean;
  hasAmount: boolean;
  heavyMonthCount: number;
  heavyMonthlyLimit: number;
}): RouteDecision {
  const both = args.hasName && args.hasAmount;
  if (both) {
    return { kind: "model", tier: "light" };
  }
  if (args.heavyMonthCount >= args.heavyMonthlyLimit) {
    return { kind: "need_details" };
  }
  return { kind: "model", tier: "heavy" };
}

export function checkPhotoCaps(
  usage: UsageSnapshot,
  limits: PhotoLimits,
): CapCode | null {
  if (usage.dayCount >= limits.daily) {
    return "daily_cap";
  }
  if (limits.monthly != null && usage.monthCount >= limits.monthly) {
    return "monthly_cap";
  }
  if (limits.spendJpy != null && usage.monthSpendJpy >= limits.spendJpy) {
    return "spend_cap";
  }
  return null;
}

export function tokyoDateKey(instant: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

export function tokyoMonthKey(instant: Date): string {
  return tokyoDateKey(instant).slice(0, 7);
}

// 日本は夏時間がない。東京の月初 0 時を UTC にする。
export function tokyoMonthStartUtc(now: Date): Date {
  const [year, month] = tokyoDateKey(now).split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, 1, -9, 0, 0));
}

export function summarizeUsage(rows: UsageRow[], now: Date): UsageSnapshot {
  const day = tokyoDateKey(now);
  const month = tokyoMonthKey(now);
  let dayCount = 0;
  let monthCount = 0;
  let heavyMonthCount = 0;
  let monthSpendJpy = 0;
  for (const row of rows) {
    const at = new Date(row.createdAt);
    if (Number.isNaN(at.getTime())) {
      continue;
    }
    const key = tokyoDateKey(at);
    if (!key.startsWith(month)) {
      continue;
    }
    monthCount += 1;
    monthSpendJpy += row.costJpy;
    if (row.tier === "heavy") {
      heavyMonthCount += 1;
    }
    if (key === day) {
      dayCount += 1;
    }
  }
  return { dayCount, monthCount, heavyMonthCount, monthSpendJpy };
}

export type TokenPrices = {
  inputJpyPerMillion: number;
  outputJpyPerMillion: number;
  cacheReadJpyPerMillion: number;
  cacheWriteJpyPerMillion: number;
  longPromptMultiplier: number;
};

export function estimateCostJpy(args: {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  prices: TokenPrices;
}): number {
  const long = args.inputTokens > 100_000 ? args.prices.longPromptMultiplier : 1;
  const perMillion = 1_000_000;
  return (
    (args.inputTokens * args.prices.inputJpyPerMillion * long) / perMillion +
    (args.outputTokens * args.prices.outputJpyPerMillion * long) / perMillion +
    (args.cacheReadTokens * args.prices.cacheReadJpyPerMillion) / perMillion +
    (args.cacheWriteTokens * args.prices.cacheWriteJpyPerMillion) / perMillion
  );
}

export function readNonNegativeNumber(raw: string | undefined, fallback: number): number {
  if (raw == null || raw.trim() === "") {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0) {
    return fallback;
  }
  return value;
}

export function readNonNegativeInt(raw: string | undefined, fallback: number): number {
  return Math.floor(readNonNegativeNumber(raw, fallback));
}

export function readPositiveInt(raw: string | undefined, fallback: number): number {
  const value = readNonNegativeInt(raw, fallback);
  return value >= 1 ? value : fallback;
}

function firstSet(...values: Array<string | undefined>): string | undefined {
  for (const value of values) {
    if (value != null && value.trim() !== "") {
      return value;
    }
  }
  return undefined;
}

export function readOptionalNonNegative(raw: string | undefined): number | null {
  if (raw == null || raw.trim() === "") {
    return null;
  }
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return value;
}

/// 自炊コーチの行だけ。AIで探すは meal_text_lookups に入るので、ここには含めない。
export function cookCoachUsageQuery(userId: string, sinceIso: string): string {
  return `user_id=eq.${encodeURIComponent(userId)}` +
    `&feature=eq.cook_coach` +
    `&created_at=gte.${encodeURIComponent(sinceIso)}` +
    `&select=created_at,estimated_cost_jpy`;
}

/// 写真、外食・コンビニ、AIで探すで共有する1日の回数。自炊コーチは入れない。
/// 空なら `AI_COMBINED_DAILY_LIMIT`、それも空なら 15。
export function combinedDailyLimitFromEnv(env: PhotoAiEnv): number {
  return readPositiveInt(
    firstSet(env.AI_COMBINED_DAILY_LIMIT, env.AI_DAILY_LIMIT, env.PHOTO_AI_DAILY_LIMIT),
    combinedAiDailyLimitDefault,
  );
}

export function photoLimitsFromEnv(env: PhotoAiEnv): PhotoLimits {
  const monthly = readOptionalNonNegative(env.PHOTO_AI_MONTHLY_LIMIT);
  const spend = readOptionalNonNegative(env.PHOTO_AI_MONTHLY_SPEND_JPY);
  return {
    daily: combinedDailyLimitFromEnv(env),
    monthly: monthly == null ? null : Math.floor(monthly),
    heavyMonthly: readNonNegativeInt(
      env.PHOTO_AI_HEAVY_MONTHLY_LIMIT,
      photoHeavyMonthlyLimitDefault,
    ),
    spendJpy: spend,
  };
}

function usd(raw: string | undefined, fallback: number): number {
  return readNonNegativeNumber(raw, fallback);
}

export function tokenPricesFromEnv(tier: PhotoTier, env: PhotoAiEnv): TokenPrices {
  const rate = usd(env.PHOTO_AI_USD_JPY, usdJpyDefault);
  if (tier === "light") {
    return {
      inputJpyPerMillion: usd(env.PHOTO_AI_LIGHT_INPUT_USD_PER_MILLION, lightInputUsdPerMillionDefault) * rate,
      outputJpyPerMillion: usd(env.PHOTO_AI_LIGHT_OUTPUT_USD_PER_MILLION, lightOutputUsdPerMillionDefault) * rate,
      cacheReadJpyPerMillion: usd(
        env.PHOTO_AI_LIGHT_CACHE_READ_USD_PER_MILLION,
        lightCacheReadUsdPerMillionDefault,
      ) * rate,
      cacheWriteJpyPerMillion: usd(
        env.PHOTO_AI_LIGHT_CACHE_WRITE_USD_PER_MILLION,
        lightCacheWriteUsdPerMillionDefault,
      ) * rate,
      longPromptMultiplier: 5,
    };
  }
  return {
    inputJpyPerMillion: usd(env.PHOTO_AI_HEAVY_INPUT_USD_PER_MILLION, heavyInputUsdPerMillionDefault) * rate,
    outputJpyPerMillion: usd(env.PHOTO_AI_HEAVY_OUTPUT_USD_PER_MILLION, heavyOutputUsdPerMillionDefault) * rate,
    cacheReadJpyPerMillion: usd(
      env.PHOTO_AI_HEAVY_CACHE_READ_USD_PER_MILLION,
      heavyCacheReadUsdPerMillionDefault,
    ) * rate,
    cacheWriteJpyPerMillion: usd(
      env.PHOTO_AI_HEAVY_CACHE_WRITE_USD_PER_MILLION,
      heavyCacheWriteUsdPerMillionDefault,
    ) * rate,
    longPromptMultiplier: 1,
  };
}

export function thinkingMode(raw: string | undefined): ThinkingMode {
  const value = (raw ?? "").trim().toLowerCase();
  if (value === "on" || value === "true" || value === "1") {
    return "on";
  }
  return "off";
}

const effortsOn = ["low", "medium", "high", "xhigh", "max"];
const effortsOff = ["low", "medium", "high"];

export function effortFor(thinking: ThinkingMode, raw: string | undefined): string {
  const value = (raw ?? "").trim().toLowerCase();
  const allowed = thinking === "on" ? effortsOn : effortsOff;
  return allowed.includes(value) ? value : "low";
}

export type TierCallOptions = {
  maxTokens: number;
  thinking: ThinkingMode;
  effort: string;
  imageMaxEdge: number;
};

export function tierCallOptions(tier: PhotoTier, env: PhotoAiEnv): TierCallOptions {
  const sharedMax = readPositiveInt(env.PHOTO_AI_MAX_TOKENS, maxTokensDefault);
  const thinking = thinkingMode(
    tier === "light" ? env.PHOTO_AI_LIGHT_THINKING : env.PHOTO_AI_HEAVY_THINKING,
  );
  const maxRaw = tier === "light" ? env.PHOTO_AI_LIGHT_MAX_TOKENS : env.PHOTO_AI_HEAVY_MAX_TOKENS;
  const edgeRaw = tier === "light"
    ? env.PHOTO_AI_LIGHT_IMAGE_MAX_EDGE
    : env.PHOTO_AI_HEAVY_IMAGE_MAX_EDGE;
  const effortRaw = tier === "light" ? env.PHOTO_AI_LIGHT_EFFORT : env.PHOTO_AI_HEAVY_EFFORT;
  return {
    maxTokens: readPositiveInt(maxRaw, sharedMax),
    thinking,
    effort: effortFor(thinking, effortRaw),
    imageMaxEdge: readPositiveInt(edgeRaw, imageMaxEdgeDefault),
  };
}
