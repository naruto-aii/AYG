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

/// 届いた期限が今の期限より前なら、加入の行を上書きしない。
/// 返金・取り消し（revocationDate）は、期限が前でも権利を無効にする。
export function shouldSkipOlderExpiry(input: {
  revoked: boolean;
  currentExpiresAt: string | null;
  nextExpiresAt: string | null;
}): boolean {
  if (input.revoked) {
    return false;
  }
  if (!input.currentExpiresAt) {
    return false;
  }
  if (!input.nextExpiresAt) {
    return true;
  }
  const current = Date.parse(input.currentExpiresAt);
  const next = Date.parse(input.nextExpiresAt);
  if (!Number.isFinite(current) || !Number.isFinite(next)) {
    return false;
  }
  return next < current;
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

/// 加入を必ず書き換える通知。取引が欠けていたら Apple に再送させる。
export const entitlementNotificationTypes = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
  "EXPIRED",
  "DID_FAIL_TO_RENEW",
  "GRACE_PERIOD_EXPIRED",
  "REFUND",
  "REVOKE",
]);

export type NotificationEntitlementInput = {
  notificationType: string;
  subtype?: string | null;
  userId: string;
  expectedBundleId: string;
  bundleId: string;
  productId: string;
  environment: string;
  originalTransactionId: string;
  boundUserId: string | null;
  expiresDate: number | null;
  revocationDate: number | null;
  gracePeriodExpiresDate?: number | null;
  now: Date;
};

function clampToPast(now: Date, expiresDate: number | null): number | null {
  if (expiresDate == null || expiresDate > now.getTime()) {
    return now.getTime() - 1;
  }
  return expiresDate;
}

/// 通知の種類で、期限と取り消しを決めてから decideEntitlement に渡す。
/// 3日間の無料トライアル（offerType 1）も、その後の DID_RENEW も、未来の期限なら active。
export function decideNotificationEntitlement(
  input: NotificationEntitlementInput,
): EntitlementDecision {
  const type = input.notificationType;
  const subtype = input.subtype ?? "";
  let expiresDate = input.expiresDate;
  let revocationDate = input.revocationDate;

  if (type === "REFUND" || type === "REVOKE") {
    revocationDate = input.revocationDate ?? input.now.getTime();
  } else if (type === "DID_FAIL_TO_RENEW" && subtype === "GRACE_PERIOD") {
    const grace = input.gracePeriodExpiresDate ?? null;
    if (grace != null && grace > input.now.getTime()) {
      expiresDate = grace;
      revocationDate = null;
    } else if (expiresDate != null && expiresDate > input.now.getTime()) {
      revocationDate = null;
    } else {
      expiresDate = clampToPast(input.now, grace ?? expiresDate);
      revocationDate = null;
    }
  } else if (
    type === "EXPIRED" ||
    type === "GRACE_PERIOD_EXPIRED" ||
    (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD")
  ) {
    expiresDate = clampToPast(input.now, expiresDate);
    revocationDate = null;
  } else if (type === "DID_CHANGE_RENEWAL_STATUS") {
    revocationDate = input.revocationDate;
  }

  return decideEntitlement({
    userId: input.userId,
    expectedBundleId: input.expectedBundleId,
    bundleId: input.bundleId,
    productId: input.productId,
    environment: input.environment,
    originalTransactionId: input.originalTransactionId,
    boundUserId: input.boundUserId,
    expiresDate,
    revocationDate,
    now: input.now,
  });
}

/// 古い更新で期限を短くしない。返金・失効・猶予切れは、期限が前でも反映する。
export function notificationSkipsOlderExpiry(input: {
  notificationType: string;
  subtype?: string | null;
  revoked: boolean;
  currentExpiresAt: string | null;
  nextExpiresAt: string | null;
}): boolean {
  const type = input.notificationType;
  const subtype = input.subtype ?? "";
  if (input.revoked || type === "REFUND" || type === "REVOKE") {
    return false;
  }
  if (type === "EXPIRED" || type === "GRACE_PERIOD_EXPIRED") {
    return false;
  }
  if (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD") {
    return false;
  }
  return shouldSkipOlderExpiry({
    revoked: false,
    currentExpiresAt: input.currentExpiresAt,
    nextExpiresAt: input.nextExpiresAt,
  });
}
