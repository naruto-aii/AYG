// アプリが購入・復元・起動時に渡す StoreKit 2 の署名付き取引を検証し、
// 加入の行は service_role で書く。アプリからの status と期限は見ない。

import {
  decideEntitlement,
  settlePlusEntitlement,
  skipsOlderEntitlement,
  type EntitlementRow,
  type StoredEntitlement,
} from "../_shared/store_entitlement.ts";

export type VerifiedTransaction = {
  bundleId: string;
  productId: string;
  environment: string;
  originalTransactionId: string;
  transactionId: string;
  expiresDate: number | null;
  revocationDate: number | null;
  upgraded: boolean;
};

export type VerifyStoreDeps = {
  userId: (req: Request) => Promise<string | null>;
  now: () => Date;
  expectedBundleId: string;
  verify: (jws: string) => Promise<VerifiedTransaction>;
  boundUser: (originalTransactionId: string) => Promise<string | null>;
  bind: (originalTransactionId: string, userId: string, productId: string) => Promise<void>;
  /// 読み取った行と一致するときだけ書く。食い違ったら false。
  write: (row: EntitlementRow, expected: StoredEntitlement | null) => Promise<boolean>;
  /// 今の加入。無いときは null。古い期限で上書きしないために読む。
  /// status と transactionId は、別の取引の返金・失効で新しい加入を消さないために使う。
  current?: (
    userId: string,
    productId: string,
  ) => Promise<{
    expiresAt: string | null;
    status?: string | null;
    transactionId?: string | null;
  } | null>;
  /// 返金・取り消しされた transactionId を記録する。行の更新より先に呼ぶ。
  rememberRevoked?: (input: {
    userId: string;
    productId: string;
    transactionId: string;
    reason: "refund" | "revoke";
    revokedAt: Date;
  }) => Promise<void>;
  /// 記録済みなら true。取り消し日が無くても有料に戻さない。
  transactionRevoked?: (input: {
    userId: string;
    productId: string;
    transactionId: string;
  }) => Promise<boolean>;
  /// 拒否理由。JWS 本体は渡さない。
  log?: (entry: { code: string; reason: string }) => void;
};

function logRejection(
  deps: VerifyStoreDeps,
  code: string,
  reason: string,
): void {
  const entry = { code, reason };
  if (deps.log) {
    deps.log(entry);
    return;
  }
  console.error("[verify-store-transaction] rejected", entry);
}

const maxTransactions = 8;
const maxJwsLength = 32000;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function signedTransactionsFromBody(body: unknown): string[] | null {
  if (body == null || typeof body !== "object") {
    return null;
  }
  const record = body as { signedTransaction?: unknown; signedTransactions?: unknown };
  const many = Array.isArray(record.signedTransactions)
    ? record.signedTransactions
    : record.signedTransaction != null
    ? [record.signedTransaction]
    : null;
  if (!many || many.length === 0 || many.length > maxTransactions) {
    return null;
  }
  const signed: string[] = [];
  for (const item of many) {
    if (typeof item !== "string") {
      return null;
    }
    const trimmed = item.trim();
    if (!trimmed || trimmed.length > maxJwsLength || trimmed.split(".").length !== 3) {
      return null;
    }
    signed.push(trimmed);
  }
  return signed;
}

export async function handleVerifyStoreTransaction(
  req: Request,
  deps: VerifyStoreDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return json({ ok: false, code: "bad_request" }, 405);
  }
  const userId = await deps.userId(req);
  if (!userId) {
    logRejection(deps, "unauthenticated", "missing_user");
    return json({ ok: false, code: "unauthenticated" }, 401);
  }
  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    logRejection(deps, "invalid_transaction", "malformed_body");
    return json({ ok: false, code: "invalid_transaction" }, 400);
  }
  const signed = signedTransactionsFromBody(payload);
  if (!signed) {
    logRejection(deps, "invalid_transaction", "malformed_jws");
    return json({ ok: false, code: "invalid_transaction" }, 400);
  }
  const now = deps.now();
  let conflict = false;
  for (const jws of signed) {
    let verified: VerifiedTransaction;
    try {
      verified = await deps.verify(jws);
    } catch {
      logRejection(deps, "invalid_transaction", "verify_failed");
      return json({ ok: false, code: "invalid_transaction" }, 400);
    }
    const boundUserId = await deps.boundUser(verified.originalTransactionId);
    const decision = decideEntitlement({
      userId,
      expectedBundleId: deps.expectedBundleId,
      bundleId: verified.bundleId,
      productId: verified.productId,
      environment: verified.environment,
      originalTransactionId: verified.originalTransactionId,
      boundUserId,
      expiresDate: verified.expiresDate,
      revocationDate: verified.revocationDate,
      transactionId: verified.transactionId,
      upgraded: verified.upgraded,
      now,
    });
    if (!decision.ok) {
      logRejection(deps, decision.code, decision.reason);
      if (decision.code === "bound_to_other_user") {
        conflict = true;
        continue;
      }
      return json({ ok: false, code: "invalid_transaction" }, 400);
    }
    await deps.bind(
      verified.originalTransactionId,
      userId,
      verified.productId,
    );
    const transactionId = decision.row.source_transaction_id;
    if (transactionId && verified.revocationDate != null && deps.rememberRevoked) {
      await deps.rememberRevoked({
        userId,
        productId: decision.row.product_id,
        transactionId,
        reason: "revoke",
        revokedAt: new Date(verified.revocationDate),
      });
    }
    const knownRevoked = transactionId != null && deps.transactionRevoked
      ? verified.revocationDate != null || await deps.transactionRevoked({
        userId,
        productId: decision.row.product_id,
        transactionId,
      })
      : false;
    if (knownRevoked) {
      decision.row.status = "inactive";
    }
    await settlePlusEntitlement({
      row: decision.row,
      load: async () => {
        if (!deps.current) {
          return null;
        }
        const stored = await deps.current(userId, decision.row.product_id);
        if (!stored) {
          return null;
        }
        return {
          expiresAt: stored.expiresAt,
          status: stored.status ?? "",
          transactionId: stored.transactionId ?? null,
        };
      },
      skip: (current) => {
        if (!deps.current) {
          return false;
        }
        return skipsOlderEntitlement({
          revoked: verified.revocationDate != null,
          upgraded: verified.upgraded,
          currentExpiresAt: current?.expiresAt ?? null,
          currentStatus: current?.status ?? null,
          currentTransactionId: current?.transactionId ?? null,
          nextExpiresAt: decision.row.expires_at,
          transactionExpiresAt: verified.expiresDate,
          transactionId: verified.transactionId,
          knownRevoked,
          now,
        });
      },
      save: (row, expected) => deps.write(row, expected),
    });
  }
  if (conflict) {
    return json({ ok: false, code: "bound_to_other_user" }, 409);
  }
  return json({ ok: true }, 200);
}
