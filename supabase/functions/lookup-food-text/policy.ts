// AIで探すの回数。費用の上限は写真で登録と合算する。
// 回数とキャッシュ期限の初期値は仮置き。オーナーはまだ決めていない。

import {
  photoLimitsFromEnv,
  readPositiveInt,
  summarizeUsage,
  type PhotoAiEnv,
  type UsageRow,
} from "../analyze-meal-photo/policy.ts";

export const textDailyLimitDefault = 10;
export const textMonthlyLimitDefault = 60;
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
  monthly: number;
  spendJpy: number;
  cacheTtlHours: number;
  maxTokens: number;
};

export function textLookupLimitsFromEnv(env: TextLookupEnv): TextLookupLimits {
  const spend = photoLimitsFromEnv(env).spendJpy;
  return {
    daily: readPositiveInt(env.TEXT_AI_DAILY_LIMIT, textDailyLimitDefault),
    monthly: readPositiveInt(env.TEXT_AI_MONTHLY_LIMIT, textMonthlyLimitDefault),
    spendJpy: spend,
    cacheTtlHours: readPositiveInt(env.TEXT_AI_CACHE_TTL_HOURS, textCacheTtlHoursDefault),
    maxTokens: readPositiveInt(env.TEXT_AI_MAX_TOKENS, textMaxTokensDefault),
  };
}

export type LookupUsage = {
  dayCount: number;
  monthCount: number;
  monthSpendJpy: number;
};

// 回数は AIで探すだけ。費用は写真で登録の行と足す。
export function lookupUsageFromRows(args: {
  textRows: UsageRow[];
  photoRows: UsageRow[];
  now: Date;
}): LookupUsage {
  const text = summarizeUsage(args.textRows, args.now);
  const photo = summarizeUsage(args.photoRows, args.now);
  return {
    dayCount: text.dayCount,
    monthCount: text.monthCount,
    monthSpendJpy: text.monthSpendJpy + photo.monthSpendJpy,
  };
}
