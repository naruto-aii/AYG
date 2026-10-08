// カロナビ+の加入は、検証済みの StoreKit 2 取引だけから書く。
// アプリが送った status や期限は使わない。

export const plusProductIds = new Set([
  "calonavi_plus_monthly",
  "calonavi_plus_half_year",
  "calonavi_plus_yearly",
]);

export const acceptedStoreEnvironments = new Set(["Sandbox", "Production"]);

export type EntitlementStatus = "active" | "expired" | "inactive";

export type EntitlementRow = {
  user_id: string;
  product_id: string;
  expires_at: string | null;
  status: EntitlementStatus;
  advertising_use: false;
};

export type EntitlementDecision =
  | { ok: true; row: EntitlementRow }
  | { ok: false; code: "invalid_transaction" | "bound_to_other_user" };

export function entitlementTiming(input: {
  expiresDate: number | null;
  revocationDate: number | null;
  now: Date;
}): { status: EntitlementStatus; expiresAt: string | null } {
  const expires = input.expiresDate == null ? null : new Date(input.expiresDate);
  const expiresAt = expires != null && !Number.isNaN(expires.getTime())
    ? expires.toISOString()
    : null;
  if (input.revocationDate != null || expiresAt == null) {
    return { status: "inactive", expiresAt };
  }
  if (expires!.getTime() > input.now.getTime()) {
    return { status: "active", expiresAt };
  }
  return { status: "expired", expiresAt };
}

/// 署名検証が通った取引だけを渡す。bundleId、商品、環境、取引の持ち主をここで見る。
export function decideEntitlement(input: {
  userId: string;
  expectedBundleId: string;
  bundleId: string;
  productId: string;
  environment: string;
  originalTransactionId: string;
  boundUserId: string | null;
  expiresDate: number | null;
  revocationDate: number | null;
  now: Date;
}): EntitlementDecision {
  const original = input.originalTransactionId.trim();
  const bundle = input.expectedBundleId.trim();
  if (
    !input.userId ||
    !bundle ||
    input.bundleId !== bundle ||
    !plusProductIds.has(input.productId) ||
    !acceptedStoreEnvironments.has(input.environment) ||
    original.length === 0 ||
    original.length > 128
  ) {
    return { ok: false, code: "invalid_transaction" };
  }
  if (input.boundUserId != null && input.boundUserId !== input.userId) {
    return { ok: false, code: "bound_to_other_user" };
  }
  const timing = entitlementTiming({
    expiresDate: input.expiresDate,
    revocationDate: input.revocationDate,
    now: input.now,
  });
  return {
    ok: true,
    row: {
      user_id: input.userId,
      product_id: input.productId,
      expires_at: timing.expiresAt,
      status: timing.status,
      advertising_use: false,
    },
  };
}
