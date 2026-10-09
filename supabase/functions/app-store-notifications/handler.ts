export type DecodedStoreNotification = {
  notificationUUID: string;
  notificationType: string;
  subtype?: string | null;
  appAccountToken?: string | null;
  originalTransactionId?: string | null;
  productId?: string | null;
  bundleId?: string | null;
  environment?: string | null;
  expiresDate?: number | null;
  revocationDate?: number | null;
  signedPayload: string;
  decoded: Record<string, unknown>;
};

export type UserMatch = {
  userId: string | null;
  deleted: boolean;
};

export type NotificationDeps = {
  verify: (signedPayload: string) => Promise<DecodedStoreNotification>;
  exists: (notificationUUID: string) => Promise<boolean>;
  matchUser: (decoded: DecodedStoreNotification) => Promise<UserMatch>;
  insert: (row: Record<string, unknown>) => Promise<void>;
  insertFailed: (signedPayload: string) => Promise<void>;
  /// 更新・期限・返金を、検証済みの取引から加入の行へ書く。失敗したら Apple に再送させる。
  applyEntitlement?: (input: {
    userId: string;
    productId: string | null;
    originalTransactionId: string | null;
    bundleId: string | null;
    environment: string | null;
    expiresDate: number | null;
    revocationDate: number | null;
  }) => Promise<void>;
};

export async function handleAppStoreNotification(
  request: Request,
  deps: NotificationDeps,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("method", { status: 405 });
  }
  let signedPayload = "";
  try {
    const body = await request.json();
    signedPayload = typeof body?.signedPayload === "string" ? body.signedPayload : "";
  } catch {
    return new Response("bad json", { status: 400 });
  }
  if (!signedPayload) {
    return new Response("missing signedPayload", { status: 400 });
  }
  let decoded: DecodedStoreNotification;
  try {
    decoded = await deps.verify(signedPayload);
  } catch {
    try {
      await deps.insertFailed(signedPayload);
    } catch {
      return new Response("store failed", { status: 500 });
    }
    return new Response("verification failed", { status: 400 });
  }
  if (await deps.exists(decoded.notificationUUID)) {
    return new Response("duplicate", { status: 200 });
  }
  const match = await deps.matchUser(decoded);
  if (deps.applyEntitlement && match.userId && !match.deleted) {
    try {
      await deps.applyEntitlement({
        userId: match.userId,
        productId: decoded.productId ?? null,
        originalTransactionId: decoded.originalTransactionId ?? null,
        bundleId: decoded.bundleId ?? null,
        environment: decoded.environment ?? null,
        expiresDate: decoded.expiresDate ?? null,
        revocationDate: decoded.revocationDate ?? null,
      });
    } catch {
      return new Response("entitlement failed", { status: 500 });
    }
  }
  const row: Record<string, unknown> = {
    notification_uuid: decoded.notificationUUID,
    notification_type: decoded.notificationType,
    subtype: decoded.subtype ?? null,
    verification_status: "verified",
    user_id: match.deleted ? null : match.userId,
    app_account_token: match.deleted ? null : decoded.appAccountToken ?? null,
    original_transaction_id: match.deleted ? null : decoded.originalTransactionId ?? null,
    product_id: decoded.productId ?? null,
    signed_payload: match.deleted ? null : decoded.signedPayload,
    decoded_payload: match.deleted ? null : decoded.decoded,
  };
  try {
    await deps.insert(row);
  } catch {
    return new Response("save failed", { status: 500 });
  }
  return new Response("ok", { status: 200 });
}
