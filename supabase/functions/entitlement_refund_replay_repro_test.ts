// レビュー用の再現。本番には適用しない。
//
// 更新のたびに transactionId は変わる。返金通知の signedTransactionInfo に入る
// transactionId は、返金されたその更新の ID で、originalTransactionId ではない。
// 保存行が新しい更新の ID になっていても、返金されたのがその ID ならすぐ止める。
// 止めたあとに、取り消し日の無い同じ署名をアプリが送り直しても、有料に戻してはいけない。
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decideNotificationEntitlement,
  type EntitlementRow,
  revocationJournalPlan,
  settlePlusEntitlement,
  skipsOlderEntitlement,
  type StoredEntitlement,
} from "./_shared/store_entitlement.ts";
import {
  handleVerifyStoreTransaction,
  type VerifiedTransaction,
} from "./verify-store-transaction/handler.ts";

const user = "11111111-1111-4111-8111-111111111111";
const bundle = "com.narutoaii.ayg";
const now = new Date("2026-10-08T00:00:00.000Z");
const monthly = "calonavi_plus_monthly";
const firstEnd = Date.parse("2026-11-08T00:00:00.000Z");
const renewalEnd = Date.parse("2026-12-08T00:00:00.000Z");
const jws = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ0In0.sig";

function grantsPlus(row: StoredEntitlement | null, at: Date = now): boolean {
  if (row?.status !== "active" || row.expiresAt == null) {
    return false;
  }
  const expiry = Date.parse(row.expiresAt);
  return Number.isFinite(expiry) && expiry > at.getTime();
}

function ledger() {
  let row: StoredEntitlement | null = null;
  const revoked = new Set<string>();
  return {
    get current() {
      return row;
    },
    plus(at: Date = now): boolean {
      return grantsPlus(row, at);
    },
    write(next: EntitlementRow, expected: StoredEntitlement | null): boolean {
      if (expected == null) {
        if (row != null) return false;
      } else if (
        row == null ||
        row.expiresAt !== expected.expiresAt ||
        row.status !== expected.status ||
        row.transactionId !== expected.transactionId
      ) {
        return false;
      }
      row = {
        expiresAt: next.expires_at,
        status: next.status,
        transactionId: next.source_transaction_id,
      };
      return true;
    },
    remember(transactionId: string): void {
      revoked.add(transactionId);
    },
    forget(transactionId: string): void {
      revoked.delete(transactionId);
    },
    has(transactionId: string): boolean {
      return revoked.has(transactionId);
    },
  };
}

function verified(overrides: Partial<VerifiedTransaction> = {}): VerifiedTransaction {
  return {
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: "1000001",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
    revocationDate: null,
    upgraded: false,
    ...overrides,
  };
}

async function applyVerify(
  book: ReturnType<typeof ledger>,
  transaction: VerifiedTransaction,
): Promise<Response> {
  return await handleVerifyStoreTransaction(
    new Request("https://example.test/verify-store-transaction", {
      method: "POST",
      body: JSON.stringify({ signedTransaction: jws }),
    }),
    {
      userId: () => Promise.resolve(user),
      now: () => now,
      expectedBundleId: bundle,
      verify: () => Promise.resolve(transaction),
      boundUser: () => Promise.resolve(null),
      bind: () => Promise.resolve(),
      current: () => Promise.resolve(book.current),
      write: (row, expected) => Promise.resolve(book.write(row, expected)),
      rememberRevoked: (input) => {
        book.remember(input.transactionId);
        return Promise.resolve();
      },
      transactionRevoked: (input) => Promise.resolve(book.has(input.transactionId)),
    },
  );
}

async function applyNotice(
  book: ReturnType<typeof ledger>,
  notice: {
    notificationType: string;
    subtype?: string | null;
    expiresDate?: number | null;
    revocationDate?: number | null;
    transactionId?: string | null;
    originalTransactionId?: string;
  },
): Promise<void> {
  const decision = decideNotificationEntitlement({
    notificationType: notice.notificationType,
    subtype: notice.subtype ?? null,
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: notice.originalTransactionId ?? "1000001",
    boundUserId: user,
    expiresDate: notice.expiresDate ?? null,
    revocationDate: notice.revocationDate ?? null,
    transactionId: notice.transactionId ?? null,
    now,
  });
  if (!decision.ok) {
    throw new Error(decision.code);
  }
  const plan = revocationJournalPlan({
    notificationType: notice.notificationType,
    transactionId: notice.transactionId,
    revocationDate: notice.revocationDate,
    now,
  });
  let knownRevoked = false;
  if (plan.action === "forget") {
    book.forget(plan.transactionId);
  } else if (plan.action === "remember") {
    book.remember(plan.transactionId);
    knownRevoked = true;
  } else if (plan.action === "lookup") {
    knownRevoked = book.has(plan.transactionId);
  }
  if (knownRevoked) {
    decision.row.status = "inactive";
  }
  const revoked = notice.revocationDate != null ||
    notice.notificationType === "REFUND" ||
    notice.notificationType === "REVOKE";
  await settlePlusEntitlement({
    row: decision.row,
    load: () => Promise.resolve(book.current),
    skip: (current) =>
      skipsOlderEntitlement({
        notificationType: notice.notificationType,
        subtype: notice.subtype ?? null,
        revoked,
        currentExpiresAt: current?.expiresAt ?? null,
        currentStatus: current?.status ?? null,
        currentTransactionId: current?.transactionId ?? null,
        nextExpiresAt: decision.row.expires_at,
        transactionExpiresAt: notice.expiresDate ?? null,
        transactionId: notice.transactionId ?? null,
        knownRevoked,
        now,
      }),
    save: (row, expected) => Promise.resolve(book.write(row, expected)),
  });
}

async function storeRenewal(book: ReturnType<typeof ledger>): Promise<void> {
  await applyNotice(book, {
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    transactionId: "tx-first",
    expiresDate: firstEnd,
  });
  await applyNotice(book, {
    notificationType: "DID_RENEW",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
  });
  assertEquals(book.current?.transactionId, "tx-renewal");
  assertEquals(book.plus(), true);
}

Deno.test("a refund of the stored renewal stops Plus even though the transaction id changed", async () => {
  const book = ledger();
  await storeRenewal(book);
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-renewal",
    originalTransactionId: "tx-first",
    expiresDate: renewalEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.current?.status, "inactive");
  assertEquals(book.current?.transactionId, "tx-renewal");
  assertEquals(book.plus(), false);
});

Deno.test("a refund of the previous renewal does not clear the newer paid period", async () => {
  const book = ledger();
  await storeRenewal(book);
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-first",
    originalTransactionId: "tx-first",
    expiresDate: firstEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.current?.transactionId, "tx-renewal");
  assertEquals(book.current?.status, "active");
  assertEquals(book.plus(), true);
});

Deno.test("a pre-refund signed transaction must not turn Plus back on", async () => {
  const book = ledger();
  await storeRenewal(book);
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.plus(), false);

  // StoreKit が取り消しを知る前の署名。revocationDate は無く、期限は未来のまま。
  const replay = await applyVerify(book, verified({
    originalTransactionId: "tx-first",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
    revocationDate: null,
  }));
  assertEquals(replay.status, 200);
  assertEquals(book.current?.status, "inactive");
  assertEquals(book.plus(), false);
});

Deno.test("a renewal notice must not grant a transaction that was already refunded", async () => {
  const book = ledger();
  await applyNotice(book, {
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    transactionId: "tx-first",
    expiresDate: firstEnd,
  });
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-renewal",
    originalTransactionId: "tx-first",
    expiresDate: renewalEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.current?.transactionId, "tx-first");
  assertEquals(book.plus(), true);

  await applyNotice(book, {
    notificationType: "DID_RENEW",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
  });
  const grantedRefundedRenewal = book.current?.transactionId === "tx-renewal" &&
    book.current?.status === "active";
  assertEquals(grantedRefundedRenewal, false);
});

Deno.test("only a refund reversal can grant that transaction again", async () => {
  const book = ledger();
  await storeRenewal(book);
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.plus(), false);
  assertEquals(book.has("tx-renewal"), true);

  const replay = await applyVerify(book, verified({ revocationDate: null }));
  assertEquals(replay.status, 200);
  assertEquals(book.plus(), false);

  await applyNotice(book, {
    notificationType: "REFUND_REVERSED",
    transactionId: "tx-renewal",
    expiresDate: renewalEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.has("tx-renewal"), false);
  assertEquals(book.current?.status, "active");
  assertEquals(book.current?.transactionId, "tx-renewal");
  assertEquals(book.plus(), true);

  const after = await applyVerify(book, verified({ revocationDate: null }));
  assertEquals(after.status, 200);
  assertEquals(book.plus(), true);
});
