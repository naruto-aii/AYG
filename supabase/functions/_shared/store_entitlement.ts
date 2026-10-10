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
  } else if (type === "GRACE_PERIOD_EXPIRED") {
    expiresDate = clampToPast(
      input.now,
      input.gracePeriodExpiresDate ?? input.expiresDate,
    );
    revocationDate = null;
  } else if (type === "EXPIRED" || (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD")) {
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

function epochMillis(value: string | number | null | undefined): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/// この失効が終わらせる期間の終わり。
/// 猶予切れは猶予の終わり。それ以外は取引の expiresDate だけを見る。
/// 更新情報に残った古い猶予日で、その後の加入を失効扱いしない。
function noticePeriodEnd(input: {
  notificationType: string;
  transactionExpiresAt?: string | number | null;
  gracePeriodExpiresAt?: string | number | null;
}): number | null {
  const transaction = epochMillis(input.transactionExpiresAt);
  const grace = epochMillis(input.gracePeriodExpiresAt);
  if (input.notificationType === "GRACE_PERIOD_EXPIRED") {
    return grace ?? transaction;
  }
  return transaction;
}

/// 失効通知の期間より先の加入が残っているか。
/// 同じ期間の失効は false。期限の無い失効は、未来の加入を消さない。
function storedPeriodOutlivesNotice(input: {
  notificationType: string;
  currentExpiresAt: string | null;
  transactionExpiresAt?: string | number | null;
  gracePeriodExpiresAt?: string | number | null;
  now?: Date;
}): boolean {
  const stored = epochMillis(input.currentExpiresAt);
  const now = (input.now ?? new Date()).getTime();
  if (stored == null || stored <= now) {
    return false;
  }
  const periodEnd = noticePeriodEnd(input);
  if (periodEnd == null) {
    return true;
  }
  return stored > periodEnd;
}

/// 古い更新で期限を短くしない。
/// 返金と取り消しは、期限が前でも反映する。
/// EXPIRED、猶予切れ、猶予なしの更新失敗は、今の加入がその通知の期間より新しいときだけ飛ばす。
export function notificationSkipsOlderExpiry(input: {
  notificationType: string;
  subtype?: string | null;
  revoked: boolean;
  currentExpiresAt: string | null;
  nextExpiresAt: string | null;
  /// 署名済み取引の expiresDate。クランプする前の値。
  transactionExpiresAt?: string | number | null;
  gracePeriodExpiresAt?: string | number | null;
  now?: Date;
}): boolean {
  const type = input.notificationType;
  const subtype = input.subtype ?? "";
  if (input.revoked || type === "REFUND" || type === "REVOKE") {
    return false;
  }
  if (
    type === "EXPIRED" ||
    type === "GRACE_PERIOD_EXPIRED" ||
    (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD")
  ) {
    return storedPeriodOutlivesNotice(input);
  }
  return shouldSkipOlderExpiry({
    revoked: false,
    currentExpiresAt: input.currentExpiresAt,
    nextExpiresAt: input.nextExpiresAt,
  });
}
