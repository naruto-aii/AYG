// 加入行が無いときだけ、課金ではない付与を見る。
// 加入の問い合わせが失敗したときは、今までどおり例外にして 503 のままにする。
// 付与の問い合わせが失敗したときは false。無料の利用者を 503 にしない。

import { gateRowsExist } from "./gate_check.ts";

export type FetchLike = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export async function plusFromEntitlementOrGrant(
  entitlement: { ok: boolean; status: number; body: unknown },
  hasGrant: () => Promise<boolean>,
): Promise<boolean> {
  if (gateRowsExist(entitlement)) {
    return true;
  }
  try {
    return (await hasGrant()) === true;
  } catch {
    return false;
  }
}

export async function readComplimentaryPlus(
  base: string,
  serviceKey: string,
  userId: string,
  fetchImpl: FetchLike,
): Promise<boolean> {
  const response = await fetchImpl(
    `${base}/rest/v1/rpc/user_has_complimentary_plus`,
    {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_user_id: userId }),
    },
  );
  if (!response.ok) {
    return false;
  }
  try {
    return (await response.json()) === true;
  } catch {
    return false;
  }
}
