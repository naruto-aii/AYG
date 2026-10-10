// 別の transactionId の返金・アップグレード・失効は、保存してある行を落とさない。
// 期限の長短では判断しない。
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decideEntitlement,
  decideNotificationEntitlement,
  type EntitlementRow,
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
const monthEnd = Date.parse("2026-11-08T00:00:00.000Z");
const trialEnd = Date.parse("2026-10-11T00:00:00.000Z");

function grantsPlus(row: StoredEntitlement | null, at: Date = now): boolean {
  if (row?.status !== "active" || row.expiresAt == null) {
    return false;
  }
  const expiry = Date.parse(row.expiresAt);
  return Number.isFinite(expiry) && expiry > at.getTime();
}

function ledger() {
  let row: StoredEntitlement | null = null;
  return {
    get current() {
      return row;
    },
    plus(): boolean {
      return grantsPlus(row);
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
  };
}

function verified(overrides: Partial<VerifiedTransaction> = {}): VerifiedTransaction {
  return {
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: "1000001",
    transactionId: "tx-month",
    expiresDate: monthEnd,
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
      body: JSON.stringify({ signedTransaction: "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ0In0.sig" }),
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
    gracePeriodExpiresDate?: number | null;
    transactionId?: string | null;
    upgraded?: boolean;
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
    originalTransactionId: "1000001",
    boundUserId: user,
    expiresDate: notice.expiresDate ?? null,
    revocationDate: notice.revocationDate ?? null,
    gracePeriodExpiresDate: notice.gracePeriodExpiresDate ?? null,
    transactionId: notice.transactionId ?? null,
    upgraded: notice.upgraded === true,
    now,
  });
  if (!decision.ok) {
    throw new Error(decision.code);
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
        upgraded: notice.upgraded === true,
        currentExpiresAt: current?.expiresAt ?? null,
        currentStatus: current?.status ?? null,
        currentTransactionId: current?.transactionId ?? null,
        nextExpiresAt: decision.row.expires_at,
        transactionExpiresAt: notice.expiresDate ?? null,
        transactionId: notice.transactionId ?? null,
        gracePeriodExpiresAt: notice.gracePeriodExpiresDate ?? null,
        now,
      }),
    save: (row, expected) => Promise.resolve(book.write(row, expected)),
  });
}

async function refundThenStartTrial(book: ReturnType<typeof ledger>): Promise<void> {
  await applyVerify(book, verified({ transactionId: "tx-month", expiresDate: monthEnd }));
  await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: monthEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  }));
  assertEquals(book.plus(), false);
  const trial = await applyVerify(book, verified({
    transactionId: "tx-trial",
    expiresDate: trialEnd,
  }));
  assertEquals(trial.status, 200);
  assertEquals(book.current?.transactionId, "tx-trial");
  assertEquals(book.current?.status, "active");
  assertEquals(book.plus(), true);
}

Deno.test("a late refund of a longer different transaction keeps the shorter trial", async () => {
  const book = ledger();
  await refundThenStartTrial(book);
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-month",
    expiresDate: monthEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
    // 猶予日がお試しの終わりと一致しても、取引IDが違うなら消さない。
    gracePeriodExpiresDate: trialEnd,
  });
  assertEquals(book.current?.transactionId, "tx-trial");
  assertEquals(book.current?.status, "active");
  assertEquals(book.current?.expiresAt, "2026-10-11T00:00:00.000Z");
  assertEquals(book.plus(), true);
});

Deno.test("the app sync order sends the trial and then the longer revocation", async () => {
  const book = ledger();
  await refundThenStartTrial(book);
  const trialJws = "header.trial.payload";
  const revokedJws = "header.revoked.payload";
  const response = await handleVerifyStoreTransaction(
    new Request("https://example.test/verify-store-transaction", {
      method: "POST",
      body: JSON.stringify({ signedTransactions: [trialJws, revokedJws] }),
    }),
    {
      userId: () => Promise.resolve(user),
      now: () => now,
      expectedBundleId: bundle,
      verify: (token) => {
        if (token === trialJws) {
          return Promise.resolve(verified({
            transactionId: "tx-trial",
            expiresDate: trialEnd,
          }));
        }
        return Promise.resolve(verified({
          transactionId: "tx-month",
          expiresDate: monthEnd,
          revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
        }));
      },
      boundUser: () => Promise.resolve(null),
      bind: () => Promise.resolve(),
      current: () => Promise.resolve(book.current),
      write: (row, expected) => Promise.resolve(book.write(row, expected)),
    },
  );
  assertEquals(response.status, 200);
  assertEquals(book.current?.transactionId, "tx-trial");
  assertEquals(book.current?.status, "active");
  assertEquals(book.plus(), true);
});

Deno.test("a replayed upgrade of the old transaction does not expire the shorter trial", async () => {
  const book = ledger();
  await refundThenStartTrial(book);
  const upgraded = decideEntitlement({
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: "1000001",
    boundUserId: user,
    expiresDate: monthEnd,
    revocationDate: null,
    transactionId: "tx-month",
    upgraded: true,
    now,
  });
  if (!upgraded.ok) {
    throw new Error(upgraded.code);
  }
  assertEquals(
    skipsOlderEntitlement({
      revoked: false,
      upgraded: true,
      currentExpiresAt: book.current?.expiresAt ?? null,
      currentStatus: book.current?.status ?? null,
      currentTransactionId: book.current?.transactionId ?? null,
      nextExpiresAt: upgraded.row.expires_at,
      transactionExpiresAt: monthEnd,
      transactionId: "tx-month",
      now,
    }),
    true,
  );
  await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: monthEnd,
    upgraded: true,
  }));
  assertEquals(book.current?.transactionId, "tx-trial");
  assertEquals(book.current?.status, "active");
  assertEquals(book.plus(), true);
});

Deno.test("an expired notice whose period already ended does not clear the trial", async () => {
  const book = ledger();
  await refundThenStartTrial(book);
  await applyNotice(book, {
    notificationType: "EXPIRED",
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-10-01T00:00:00.000Z"),
  });
  assertEquals(book.current?.transactionId, "tx-trial");
  assertEquals(book.plus(), true);
});
