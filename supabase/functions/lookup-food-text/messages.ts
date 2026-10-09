import { aiDataConsentRequiredMessage } from "../_shared/ai_data_consent.ts";

export const textLookupMessages = {
  not_plus: "こちらはカロナビ+の機能です。手入力で記録できます。",
  consent_required: aiDataConsentRequiredMessage,
  missing_key: "AIで探すは、いま準備中です。手入力で記録できます。",
  provider_unwired: "AIで探すは、いま準備中です。手入力で記録できます。",
  daily_cap: "本日の上限に達しました",
  monthly_cap: "今月のAIで探すは、上限に達しました。手入力で記録できます。",
  spend_cap: "今月のAIでの推定は、上限に達しました。手入力で記録できます。",
  invalid_result: "推定を確認できませんでした。別の名前で探すか、手入力で記録できます。",
  provider_error: "推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。",
  unauthenticated: "ログインしてから、もう一度試してください。",
  bad_request: "検索語を送れませんでした。もう一度試すか、手入力で記録できます。",
} as const;

export type TextLookupCode = keyof typeof textLookupMessages;

export function textLookupMessage(
  code: TextLookupCode,
  counts?: { daily?: number | null; monthly?: number | null },
): string {
  if (code === "daily_cap") {
    return textLookupMessages.daily_cap;
  }
  if (code === "monthly_cap" && counts?.monthly != null) {
    return `今月のAIで探すは、${counts.monthly}回までです。手入力で記録できます。`;
  }
  return textLookupMessages[code];
}
