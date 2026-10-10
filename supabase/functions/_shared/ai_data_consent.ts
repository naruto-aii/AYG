// AI機能で個人の入力を外部へ送る前の同意。受け付ける版の行があるときだけ送る。
// 問い合わせ自体が失敗したときは false にせず投げる（呼び出し側で1回やり直し、だめなら一時的なエラーにする）。
//
// アプリは aiDataConsentVersion（2026-10-10）だけを今の同意にする。関数は
// 2026-10-08 も受け付ける。AI の送信先の文言は両方の版で同じなので、関数を
// 審査の前に出しても、旧アプリの同意者も新しい版の同意も止まらない。

import { GateCheckError, gateRowsExist } from "./gate_check.ts";

export const aiDataConsentVersion = "2026-10-10";

/// 関数が有効な同意とみなす版。アプリの再表示は 2026-10-10 だけ。
export const acceptedAiDataConsentVersions = ["2026-10-08", "2026-10-10"] as const;

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
  const versions = acceptedAiDataConsentVersions.map((version) => `"${version}"`).join(",");
  const url =
    `${args.base}/rest/v1/ai_data_consents?user_id=eq.${encodeURIComponent(args.userId)}` +
    `&policy_version=in.(${versions})` +
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
