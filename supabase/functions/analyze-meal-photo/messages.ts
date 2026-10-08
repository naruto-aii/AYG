import { aiDataConsentRequiredMessage } from "../_shared/ai_data_consent.ts";

export const photoMealMessages = {
  not_plus: "こちらはカロナビ+の機能です。手入力で記録できます。",
  consent_required: aiDataConsentRequiredMessage,
  missing_key: "写真での登録は、いま準備中です。手入力で記録できます。",
  provider_unwired: "写真での登録は、いま準備中です。手入力で記録できます。",
  daily_cap: "本日の上限に達しました",
  monthly_cap: "今月の写真での登録は、上限に達しました。手入力で記録できます。",
  spend_cap: "今月の写真での登録は、上限に達しました。手入力で記録できます。",
  need_details: "料理名と量を入れると、引き続き写真で登録できます。",
  invalid_image: "写真を読み取れませんでした。別の写真か、手入力で記録できます。",
  invalid_result: "推定を確認できませんでした。料理名と量を入れるか、手入力で記録できます。",
  provider_error: "推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。",
  unauthenticated: "ログインしてから、もう一度試してください。",
  bad_request: "写真を送れませんでした。もう一度試すか、手入力で記録できます。",
} as const;

export type PhotoMealCode = keyof typeof photoMealMessages;

export function photoMealMessage(
  code: PhotoMealCode,
  counts?: { daily?: number | null; monthly?: number | null },
): string {
  if (code === "daily_cap") {
    return photoMealMessages.daily_cap;
  }
  if (code === "monthly_cap" && counts?.monthly != null) {
    return `今月の写真での登録は、${counts.monthly}回までです。手入力で記録できます。`;
  }
  return photoMealMessages[code];
}
