// 写真で登録の振り分け、回数、費用。写真も API キーも持たない。

export const photoDailyLimit = 10;
export const photoMonthlyLimit = 120;
export const photoHeavyMonthlyLimit = 20;
export const photoMonthlySpendJpyDefault = 120;

export const lightModelDefault = "claude-haiku-5-5";
export const heavyModelDefault = "claude-sonnet-5-5";

// 2026-10 の Claude API 料金（100k トークン以下）を、1 ドル 160 円で円にしたもの。
// 軽いモデルは入力 100k を超えると 5 倍。推定が小さくなるより、早く止める方に寄せる。
export const lightInputJpyPerMillionDefault = 16;
export const lightOutputJpyPerMillionDefault = 80;
export const heavyInputJpyPerMillionDefault = 320;
export const heavyOutputJpyPerMillionDefault = 1600;

export type PhotoTier = "light" | "heavy";

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
  monthly: number;
  heavyMonthly: number;
  spendJpy: number;
};

export const defaultPhotoLimits: PhotoLimits = {
  daily: photoDailyLimit,
  monthly: photoMonthlyLimit,
  heavyMonthly: photoHeavyMonthlyLimit,
  spendJpy: photoMonthlySpendJpyDefault,
};

export type RouteDecision =
  | { kind: "model"; tier: PhotoTier }
  | { kind: "need_details" };

export function presentText(value: string | null | undefined): boolean {
  return (value ?? "").trim().length > 0;
}

// 写真は必須。料理名と量が両方あれば軽いモデル。欠けていて高性能の月間回数内なら高性能。
// 高性能を使い切ったあとは、料理名と量を入れるまで呼ばない。
export function routePhotoModel(args: {
  hasName: boolean;
  hasAmount: boolean;
  heavyMonthCount: number;
  heavyMonthlyLimit: number;
}): RouteDecision {
  if (args.hasName && args.hasAmount) {
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
  if (usage.monthCount >= limits.monthly) {
    return "monthly_cap";
  }
  if (usage.monthSpendJpy >= limits.spendJpy) {
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
  cacheReadRatio: number;
  cacheWriteRatio: number;
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
  const inputRate = args.prices.inputJpyPerMillion * long;
  const outputRate = args.prices.outputJpyPerMillion * long;
  const perMillion = 1_000_000;
  return (
    (args.inputTokens * inputRate) / perMillion +
    (args.outputTokens * outputRate) / perMillion +
    (args.cacheReadTokens * inputRate * args.prices.cacheReadRatio) / perMillion +
    (args.cacheWriteTokens * inputRate * args.prices.cacheWriteRatio) /
      perMillion
  );
}

export function readPositiveNumber(raw: string | undefined, fallback: number): number {
  if (raw == null || raw.trim() === "") {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0) {
    return fallback;
  }
  return value;
}
