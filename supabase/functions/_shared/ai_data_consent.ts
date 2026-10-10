// AI機能で個人の入力を外部へ送る前の同意。版が一致する行があるときだけ送る。
// 問い合わせ自体が失敗したときは false にせず投げる（呼び出し側で1回やり直し、だめなら一時的なエラーにする）。

import { GateCheckError, gateRowsExist } from "./gate_check.ts";

export const aiDataConsentVersion = "2026-10-10";

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
  if (!args.userId) {
    return false;
  }
  if (!args.base || !args.serviceKey) {
    throw new GateCheckError(null, "consent check not configured");
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
  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return gateRowsExist({ ok: response.ok, status: response.status, body });
}
