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
  /// この期限を書いた取引。同じ取引の返金・失効・アップグレードだけが上書きする。
  source_transaction_id: string | null;
};

export type StoredEntitlement = {
  expiresAt: string | null;
  status: string;
  transactionId: string | null;
};

export type EntitlementDecision =
  | { ok: true; row: EntitlementRow }
  | {
    ok: false;
    code: "invalid_transaction" | "bound_to_other_user";
    reason: string;
  };

export function entitlementTiming(input: {
  expiresDate: number | null;
  revocationDate: number | null;
  /// 上位プランへ移ったあとの古い取引。期限が未来でも、この商品の加入にはしない。
  upgraded?: boolean;
  /// 返金・取り消し済みとして記録された transactionId。期限が未来でも有料にしない。
  knownRevoked?: boolean;
  now: Date;
}): { status: EntitlementStatus; expiresAt: string | null } {
  const expires = input.expiresDate == null ? null : new Date(input.expiresDate);
  const expiresAt = expires != null && !Number.isNaN(expires.getTime())
    ? expires.toISOString()
    : null;
  if (input.knownRevoked === true || input.revocationDate != null || expiresAt == null) {
    return { status: "inactive", expiresAt };
  }
  if (input.upgraded) {
    return { status: "expired", expiresAt };
  }
  if (expires!.getTime() > input.now.getTime()) {
    return { status: "active", expiresAt };
  }
  return { status: "expired", expiresAt };
}

/// AI 機能と同じ条件。`status = active` かつ `expires_at` が今よりあと。
export function plusAccessFromEntitlement(input: {
  status: string | null;
  expiresAt: string | null;
  now: Date;
}): boolean {
  if (input.status !== "active" || input.expiresAt == null) {
    return false;
  }
  const expires = Date.parse(input.expiresAt);
  return Number.isFinite(expires) && expires > input.now.getTime();
}

/// Apple の transactionId。文字列でも数値でも、前後の空白を除いた文字列にする。
export function storeTransactionId(value: unknown): string {
  if (typeof value === "string") {
    return value.trim();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(Math.trunc(value));
  }
  return "";
}

/// StoreKit の transactionId。空や長すぎる値は、同じ取引とはみなさない。
export function sourceTransactionId(value: string | null | undefined): string | null {
  const id = (value ?? "").trim();
  if (id.length === 0 || id.length > 128) {
    return null;
  }
  return id;
}

export type RevocationJournalPlan =
  | { action: "forget"; transactionId: string }
  | {
    action: "remember";
    transactionId: string;
    reason: "refund" | "revoke";
    revokedAt: Date;
  }
  | { action: "lookup"; transactionId: string }
  | { action: "none" };

/// 返金・取り消しは、保存行がその取引かどうかと関係なく記録する。
/// 記録を外すのは REFUND_REVERSED だけ。それ以外は、記録済みなら有料にしない。
export function revocationJournalPlan(input: {
  notificationType: string;
  transactionId?: string | null;
  revocationDate?: number | null;
  now: Date;
}): RevocationJournalPlan {
  const transactionId = sourceTransactionId(input.transactionId);
  if (transactionId == null) {
    return { action: "none" };
  }
  if (input.notificationType === "REFUND_REVERSED") {
    return { action: "forget", transactionId };
  }
  const revocation = input.revocationDate != null ||
    input.notificationType === "REFUND" ||
    input.notificationType === "REVOKE";
  if (revocation) {
    return {
      action: "remember",
      transactionId,
      reason: input.notificationType === "REFUND" ? "refund" : "revoke",
      revokedAt: input.revocationDate != null ? new Date(input.revocationDate) : input.now,
    };
  }
  return { action: "lookup", transactionId };
}

/// 届いた期限が今の期限より前なら、加入の行を上書きしない。
/// 返金・取り消しはここを直接使わない。skipsOlderEntitlement が期間を見る。
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
  transactionId?: string | null;
  upgraded?: boolean;
  knownRevoked?: boolean;
  now: Date;
}): EntitlementDecision {
  const original = input.originalTransactionId.trim();
  const bundle = input.expectedBundleId.trim();
  const reason = !input.userId
    ? "missing_user"
    : !bundle
    ? "missing_expected_bundle"
    : input.bundleId !== bundle
    ? "bundle_mismatch"
    : !plusProductIds.has(input.productId)
    ? "unknown_product"
    : !acceptedStoreEnvironments.has(input.environment)
    ? "environment"
    : original.length === 0
    ? "missing_original_transaction_id"
    : original.length > 128
    ? "original_transaction_id_too_long"
    : null;
  if (reason != null) {
    return { ok: false, code: "invalid_transaction", reason };
  }
  if (input.boundUserId != null && input.boundUserId !== input.userId) {
    return { ok: false, code: "bound_to_other_user", reason: "bound_to_other_user" };
  }
  const timing = entitlementTiming({
    expiresDate: input.expiresDate,
    revocationDate: input.revocationDate,
    upgraded: input.upgraded,
    knownRevoked: input.knownRevoked,
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
      source_transaction_id: sourceTransactionId(input.transactionId),
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
  "REFUND_REVERSED",
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
  transactionId?: string | null;
  upgraded?: boolean;
  knownRevoked?: boolean;
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
  } else if (type === "REFUND_REVERSED") {
    revocationDate = null;
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
    transactionId: input.transactionId,
    upgraded: input.upgraded,
    knownRevoked: input.knownRevoked,
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

/// 取引IDの無い古い行にだけ使う。返金・取り消しより先の加入が残っているか。
/// 取引の期限が無いときは、猶予より先の加入だけ残す。期限も猶予も無ければ消す。
/// 保存済みの期限がこの通知の猶予日と同じなら、払っていない延長なので消す。
/// 取引の期限より先の加入は消さない。
function storedPeriodOutlivesRevocation(input: {
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
  const transaction = epochMillis(input.transactionExpiresAt);
  const grace = epochMillis(input.gracePeriodExpiresAt);
  if (grace != null && stored === grace) {
    return false;
  }
  if (transaction == null) {
    return grace != null && stored > grace;
  }
  return stored > transaction;
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

/// 古い更新で期限を短くしない。verify-store-transaction と通知の両方がこれを使う。
/// 返金・取り消し・失効・isUpgraded は、保存行の source_transaction_id が
/// 届いた transactionId と一致するときだけ、その行を落とす。
/// IDが違えば、期限の長短や猶予日が同じでも落とさない。
/// source_transaction_id が null の古い行だけは、同じ期限か猶予日の一致で無効にする。
/// アプリが猶予中の同じ取引を、取り消しなしで送り直したときは、猶予の期限を短くしない。
/// 無効・期限切れの行は、別の取引の未来の加入を止めない。
export function skipsOlderEntitlement(input: {
  notificationType?: string | null;
  subtype?: string | null;
  revoked: boolean;
  currentExpiresAt: string | null;
  nextExpiresAt: string | null;
  /// 署名済み取引の expiresDate。クランプする前の値。
  transactionExpiresAt?: string | number | null;
  gracePeriodExpiresAt?: string | number | null;
  /// 保存してある行を書いた transactionId。originalTransactionId ではない。
  currentTransactionId?: string | null;
  /// 今届いた transactionId。
  transactionId?: string | null;
  /// 上位プランへ移った取引。同じ取引なら、期限が短くなっても上書きする。
  upgraded?: boolean;
  /// 保存してある行の状態。無効・期限切れは、別の取引の未来の加入を止めない。
  currentStatus?: string | null;
  /// この transactionId は返金・取り消し済み。有料には書かない。
  knownRevoked?: boolean;
  now?: Date;
}): boolean {
  const type = input.notificationType ?? "";
  const subtype = input.subtype ?? "";
  const currentId = sourceTransactionId(input.currentTransactionId);
  const incomingId = sourceTransactionId(input.transactionId);
  // 記録済みの返金は、取り消し日が無い再送でも有料に戻さない。
  // 保存行がそのIDなら inactive に上書きする。別のIDの加入は消さない。
  if (input.knownRevoked === true) {
    if (currentId != null && currentId === incomingId) {
      return false;
    }
    if (currentId != null && currentId !== incomingId) {
      return true;
    }
    if (input.currentExpiresAt != null) {
      return storedPeriodOutlivesRevocation(input);
    }
    return false;
  }
  const expiryNotice = type === "EXPIRED" ||
    type === "GRACE_PERIOD_EXPIRED" ||
    (type === "DID_FAIL_TO_RENEW" && subtype !== "GRACE_PERIOD");
  const destructive = input.revoked ||
    input.upgraded === true ||
    type === "REFUND" ||
    type === "REVOKE" ||
    expiryNotice;
  // 取引IDが分かっている行は、そのIDの返金・失効・アップグレードだけを受ける。
  // 届いたIDが空でも、保存してあるIDとは一致しないので落とさない。
  if (currentId != null && destructive) {
    return currentId !== incomingId;
  }
  // 取引IDの無い古い行だけ、期限と猶予日で判断する。
  if (currentId == null && (input.revoked || type === "REFUND" || type === "REVOKE")) {
    return storedPeriodOutlivesRevocation(input);
  }
  if (currentId == null && expiryNotice) {
    return storedPeriodOutlivesNotice({
      notificationType: type,
      currentExpiresAt: input.currentExpiresAt,
      transactionExpiresAt: input.transactionExpiresAt,
      gracePeriodExpiresAt: input.gracePeriodExpiresAt,
      now: input.now,
    });
  }
  // 返金やアップグレードで無効にした行の期限は、未来の日付のまま残ることがある。
  // その日付で、あとのお試しや買い直しを止めない。同じ取引の送り直しは期限の比較に任せる。
  const dead = input.currentStatus === "inactive" || input.currentStatus === "expired";
  const newTransaction = currentId == null || (incomingId != null && incomingId !== currentId);
  if (dead && newTransaction && input.upgraded !== true) {
    const next = epochMillis(input.nextExpiresAt);
    const nowMs = (input.now ?? new Date()).getTime();
    if (next != null && next > nowMs) {
      return false;
    }
  }
  return shouldSkipOlderExpiry({
    revoked: false,
    currentExpiresAt: input.currentExpiresAt,
    nextExpiresAt: input.nextExpiresAt,
  });
}

export function notificationSkipsOlderExpiry(
  input: Parameters<typeof skipsOlderEntitlement>[0] & { notificationType: string },
): boolean {
  return skipsOlderEntitlement(input);
}

/// 読み取った行と書く行が食い違っていたら false。呼び出し側は読み直す。
/// 判定そのものは skipsOlderEntitlement に残し、ここでは同時更新だけを弾く。
export async function settlePlusEntitlement(input: {
  row: EntitlementRow;
  load: () => Promise<StoredEntitlement | null>;
  skip: (current: StoredEntitlement | null) => boolean;
  save: (row: EntitlementRow, expected: StoredEntitlement | null) => Promise<boolean>;
}): Promise<void> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const current = await input.load();
    if (input.skip(current)) {
      return;
    }
    if (await input.save(input.row, current)) {
      return;
    }
  }
  throw new Error("entitlement conflict");
}
