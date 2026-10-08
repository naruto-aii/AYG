// AIで探すの回数。1日は写真で登録と合算する。月の回数と費用は未設定なら止めない。

import {
  combinedDailyLimitFromEnv,
  photoLimitsFromEnv,
  readOptionalNonNegative,
  readPositiveInt,
  summarizeUsage,
  type PhotoAiEnv,
  type UsageRow,
} from "../analyze-meal-photo/policy.ts";

export const textCacheTtlHoursDefault = 168;
export const textMaxTokensDefault = 300;

export type TextLookupEnv = PhotoAiEnv & {
  TEXT_AI_DAILY_LIMIT?: string;
  TEXT_AI_MONTHLY_LIMIT?: string;
  TEXT_AI_CACHE_TTL_HOURS?: string;
  TEXT_AI_MAX_TOKENS?: string;
};

export type TextLookupLimits = {
  daily: number;
  monthly: number | null;
  spendJpy: number | null;
  cacheTtlHours: number;
  maxTokens: number;
};

export function textLookupLimitsFromEnv(env: TextLookupEnv): TextLookupLimits {
  const monthly = readOptionalNonNegative(env.TEXT_AI_MONTHLY_LIMIT);
  return {
    daily: combinedDailyLimitFromEnv(env),
    monthly: monthly == null ? null : Math.floor(monthly),
    spendJpy: photoLimitsFromEnv(env).spendJpy,
    cacheTtlHours: readPositiveInt(env.TEXT_AI_CACHE_TTL_HOURS, textCacheTtlHoursDefault),
    maxTokens: readPositiveInt(env.TEXT_AI_MAX_TOKENS, textMaxTokensDefault),
  };
}

export type LookupUsage = {
  dayCount: number;
  monthCount: number;
  monthSpendJpy: number;
};

// 1日は写真、AIで探す（外食・コンビニも同じ行）を足す。自炊コーチは入れない。
// 月の回数は AIで探すだけ。費用は写真と AIで探すを足す。
export function lookupUsageFromRows(args: {
  textRows: UsageRow[];
  photoRows: UsageRow[];
  now: Date;
}): LookupUsage {
  const text = summarizeUsage(args.textRows, args.now);
  const photo = summarizeUsage(args.photoRows, args.now);
  return {
    dayCount: text.dayCount + photo.dayCount,
    monthCount: text.monthCount,
    monthSpendJpy: text.monthSpendJpy + photo.monthSpendJpy,
  };
}
