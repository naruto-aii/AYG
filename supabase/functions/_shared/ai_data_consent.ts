// AI機能で個人の入力を外部へ送る前の同意。版が一致する行があるときだけ送る。

export const aiDataConsentVersion = "2026-10-08";

export const aiDataConsentRequiredMessage = "AI機能を使うには、同意が必要です。";

type ConsentFetch = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export async function hasAiDataConsent(args: {
  base: string;
  serviceKey: string;
  userId: string;
  fetchImpl: ConsentFetch;
}): Promise<boolean> {
  if (!args.base || !args.serviceKey || !args.userId) {
    return false;
  }
  const url =
    `${args.base}/rest/v1/ai_data_consents?user_id=eq.${encodeURIComponent(args.userId)}` +
    `&policy_version=eq.${encodeURIComponent(aiDataConsentVersion)}` +
    `&select=user_id&limit=1`;
  const response = await args.fetchImpl(url, {
    headers: {
      apikey: args.serviceKey,
      Authorization: `Bearer ${args.serviceKey}`,
      Accept: "application/json",
    },
  });
  if (!response.ok) {
    return false;
  }
  const body = await response.json();
  return Array.isArray(body) && body.length > 0;
}
