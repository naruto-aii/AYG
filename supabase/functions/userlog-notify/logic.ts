export const checkpointTypes = [
  "install",
  "login",
  "onboarding_complete",
  "trial_start",
  "paid_start",
  "cancel",
  "expired",
  "refund",
] as const;

export type CheckpointType = typeof checkpointTypes[number];

const labels: Record<CheckpointType, string> = {
  install: "インストール",
  login: "ログイン",
  onboarding_complete: "初回登録完了",
  trial_start: "無料トライアル開始",
  paid_start: "有料開始",
  cancel: "解約",
  expired: "期限切れ",
  refund: "返金",
};

const excludedSuffix = "（集計対象外）";

export type OfferFields = {
  offerType: number | null;
  offerDiscountType: string | null;
  priceMilliunits: number | null;
};

export type StoreNotice = OfferFields & {
  notificationUuid: string;
  notificationType: string;
  subtype: string | null;
  userId: string | null;
  originalTransactionId: string | null;
  signedDate: string | null;
  receivedAt: string | null;
  verificationStatus: string;
  decodedPayload: unknown;
  signedPayload: string | null;
};

export type StoreCheckpoint = {
  type: CheckpointType;
  sourceId: string;
  occurredAt: string;
};

export function checkpointLabel(type: CheckpointType, excluded: boolean): string {
  const label = labels[type];
  return excluded ? `${label}${excludedSuffix}` : label;
}

export function formatMention(raw: string): string {
  const trimmed = raw.trim();
  const inner = trimmed.startsWith("<@") && trimmed.endsWith(">")
    ? trimmed.slice(2, -1)
    : trimmed;
  if (!/^U[A-Z0-9]+$/.test(inner)) {
    return "";
  }
  return `<@${inner}>`;
}

export function formatJst(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const pick = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "";
  let hour = pick("hour");
  if (hour === "24") {
    hour = "00";
  }
  return `${pick("year")}-${pick("month")}-${pick("day")} ${hour}:${pick("minute")} JST`;
}

function safeUserId(userId: string | null): string {
  if (
    userId &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)
  ) {
    return userId.toLowerCase();
  }
  return "不明";
}

function safeName(name: string | null): string {
  const cleaned = (name ?? "").replace(/[\r\n<>]/g, " ").replace(/\s+/g, " ").trim();
  return cleaned.length > 0 ? cleaned.slice(0, 40) : "未設定";
}

export function slackText(input: {
  mention: string;
  userId: string | null;
  displayName: string | null;
  label: string;
  occurredAt: string;
}): string {
  return [
    input.mention,
    `ユーザーID: ${safeUserId(input.userId)}`,
    `表示名: ${safeName(input.displayName)}`,
    `種類: ${input.label}`,
    `時刻: ${formatJst(input.occurredAt)}`,
  ].join("\n");
}

export function authorizeNotify(header: string, secret: string): boolean {
  if (header.length < 32 || secret.length < 32 || header.length !== secret.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < header.length; i++) {
    mismatch |= header.charCodeAt(i) ^ secret.charCodeAt(i);
  }
  return mismatch === 0;
}

export function decodeJwsPayload(jws: string | null | undefined): Record<string, unknown> | null {
  if (!jws || !jws.includes(".")) {
    return null;
  }
  const part = jws.split(".")[1] ?? "";
  if (!part) {
    return null;
  }
  try {
    const padded = part.replaceAll("-", "+").replaceAll("_", "/") +
      "=".repeat((4 - (part.length % 4)) % 4);
    const json = new TextDecoder().decode(Uint8Array.from(atob(padded), (char) => char.charCodeAt(0)));
    const value = JSON.parse(json);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

export function numberOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) {
    return Number(value);
  }
  return null;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value : null;
}

export function transactionPayload(
  decodedPayload: unknown,
  signedPayload: string | null,
): Record<string, unknown> | null {
  const decoded = asRecord(decodedPayload);
  if (decoded && (decoded.offerDiscountType != null || decoded.offerType != null || decoded.transactionId != null)) {
    return decoded;
  }
  const nested = asRecord(decoded?.data)?.signedTransactionInfo;
  if (typeof nested === "string") {
    return decodeJwsPayload(nested);
  }
  const outer = decodeJwsPayload(signedPayload);
  const signedTransaction = asRecord(outer?.data)?.signedTransactionInfo;
  if (typeof signedTransaction === "string") {
    return decodeJwsPayload(signedTransaction);
  }
  return null;
}

export function readOffer(row: StoreNotice): OfferFields {
  const transaction = transactionPayload(row.decodedPayload, row.signedPayload);
  return {
    offerType: row.offerType ?? numberOrNull(transaction?.offerType),
    offerDiscountType: row.offerDiscountType ?? stringOrNull(transaction?.offerDiscountType),
    priceMilliunits: row.priceMilliunits ?? numberOrNull(transaction?.price),
  };
}

export function isFreeTrialOffer(offer: OfferFields): boolean {
  const discount = (offer.offerDiscountType ?? "").toUpperCase();
  if (discount === "FREE_TRIAL") {
    return true;
  }
  if (discount === "PAY_AS_YOU_GO" || discount === "PAY_UP_FRONT") {
    return false;
  }
  return offer.offerType === 1 && offer.priceMilliunits === 0;
}

export function isInitialBuy(type: string, subtype: string | null): boolean {
  return type === "INITIAL_BUY" || subtype === "INITIAL_BUY";
}

export function isCancel(row: Pick<StoreNotice, "notificationType" | "subtype">): boolean {
  return row.notificationType === "DID_CHANGE_RENEWAL_STATUS" && row.subtype === "AUTO_RENEW_DISABLED";
}

export function isScrubbed(row: StoreNotice): boolean {
  return row.verificationStatus === "verified" &&
    row.userId == null &&
    row.signedPayload == null &&
    row.decodedPayload == null &&
    row.notificationType !== "UNVERIFIED";
}

function offerKnown(offer: OfferFields): boolean {
  return offer.offerType != null || offer.offerDiscountType != null || offer.priceMilliunits != null;
}

export function noticeTime(row: StoreNotice): string {
  if (row.signedDate) {
    return row.signedDate;
  }
  const signed = numberOrNull(asRecord(row.decodedPayload)?.signedDate);
  if (signed != null) {
    return new Date(signed).toISOString();
  }
  const transactionSigned = numberOrNull(transactionPayload(row.decodedPayload, row.signedPayload)?.signedDate);
  if (transactionSigned != null) {
    return new Date(transactionSigned).toISOString();
  }
  return row.receivedAt ?? new Date(0).toISOString();
}

function timeMs(row: StoreNotice): number {
  const value = Date.parse(noticeTime(row));
  return Number.isNaN(value) ? 0 : value;
}

function sameTransaction(row: StoreNotice, originalTransactionId: string): boolean {
  return row.originalTransactionId === originalTransactionId && row.verificationStatus === "verified";
}

function isEarlier(left: StoreNotice, right: StoreNotice): boolean {
  const leftMs = timeMs(left);
  const rightMs = timeMs(right);
  if (leftMs !== rightMs) {
    return leftMs < rightMs;
  }
  return left.notificationUuid < right.notificationUuid;
}

export function classifyStore(current: StoreNotice, history: StoreNotice[]): StoreCheckpoint | null {
  if (current.verificationStatus !== "verified" || !current.notificationUuid) {
    return null;
  }
  const occurredAt = noticeTime(current);
  const sourceEvent = current.notificationUuid;
  if (isCancel(current)) {
    return { type: "cancel", sourceId: sourceEvent, occurredAt };
  }
  if (current.notificationType === "EXPIRED") {
    return { type: "expired", sourceId: sourceEvent, occurredAt };
  }
  if (current.notificationType === "REFUND") {
    return { type: "refund", sourceId: sourceEvent, occurredAt };
  }
  if (isInitialBuy(current.notificationType, current.subtype)) {
    const offer = readOffer(current);
    if (isScrubbed(current) && !offerKnown(offer)) {
      return null;
    }
    const type = isFreeTrialOffer(offer) ? "trial_start" : "paid_start";
    return {
      type,
      sourceId: current.originalTransactionId || sourceEvent,
      occurredAt,
    };
  }
  if (current.notificationType !== "DID_RENEW" || !current.originalTransactionId) {
    return null;
  }
  const related = history.filter((row) => sameTransaction(row, current.originalTransactionId!));
  const hadTrial = related.some((row) =>
    isInitialBuy(row.notificationType, row.subtype) && isFreeTrialOffer(readOffer(row))
  );
  if (!hadTrial) {
    return null;
  }
  const earlierRenew = related.some((row) =>
    row.notificationUuid !== current.notificationUuid &&
    row.notificationType === "DID_RENEW" &&
    isEarlier(row, current)
  );
  if (earlierRenew) {
    return null;
  }
  const cancelledFirst = related.some((row) => isCancel(row) && isEarlier(row, current));
  if (cancelledFirst) {
    return null;
  }
  return {
    type: "paid_start",
    sourceId: current.originalTransactionId,
    occurredAt,
  };
}
