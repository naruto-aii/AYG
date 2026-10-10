// 独立した確認。加入の書き込みと、複数商品をまたいだ isPlus の読みが同じ意味になるかを見る。
import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleAppStoreNotification } from "./app-store-notifications/handler.ts";
import {
  decideEntitlement,
  decideNotificationEntitlement,
  entitlementTiming,
  type EntitlementRow,
  settlePlusEntitlement,
  skipsOlderEntitlement,
  sourceTransactionId,
  storeTransactionId,
  type StoredEntitlement,
} from "./_shared/store_entitlement.ts";
import {
  handleVerifyStoreTransaction,
  type VerifiedTransaction,
  type VerifyStoreDeps,
} from "./verify-store-transaction/handler.ts";

const user = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
const bundle = "com.narutoaii.ayg";
const now = new Date("2026-10-08T00:00:00.000Z");
const monthly = "calonavi_plus_monthly";
const yearly = "calonavi_plus_yearly";
const half = "calonavi_plus_half_year";
const jws = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ0In0.sig";

type Notice = {
  notificationType: string;
  subtype?: string | null;
  productId?: string;
  expiresDate?: number | null;
  revocationDate?: number | null;
  gracePeriodExpiresDate?: number | null;
  transactionId?: string | null;
  upgraded?: boolean;
  originalTransactionId?: string;
};

function post(body: unknown): Request {
  return new Request("https://example.test/verify-store-transaction", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

/// サーバの isPlus。status が active で、期限が今より後の行が1つでもあれば有料。
/// lookup-food-text / analyze-meal-photo / cook-coach / アプリのサーバ参照と同じ。
function grantsPlus(
  rows: Iterable<StoredEntitlement>,
  at: Date,
): boolean {
  for (const row of rows) {
    if (row.status !== "active" || row.expiresAt == null) {
      continue;
    }
    const expiry = Date.parse(row.expiresAt);
    if (Number.isFinite(expiry) && expiry > at.getTime()) {
      return true;
    }
  }
  return false;
}

function ledger() {
  const rows = new Map<string, StoredEntitlement>();
  return {
    rows,
    current(productId: string): StoredEntitlement | null {
      return rows.get(productId) ?? null;
    },
    write(row: EntitlementRow, expected: StoredEntitlement | null): boolean {
      const current = rows.get(row.product_id) ?? null;
      if (expected == null) {
        if (current != null) {
          return false;
        }
        rows.set(row.product_id, {
          expiresAt: row.expires_at,
          status: row.status,
          transactionId: row.source_transaction_id,
        });
        return true;
      }
      if (
        current == null ||
        current.expiresAt !== expected.expiresAt ||
        current.status !== expected.status ||
        current.transactionId !== expected.transactionId
      ) {
        return false;
      }
      rows.set(row.product_id, {
        expiresAt: row.expires_at,
        status: row.status,
        transactionId: row.source_transaction_id,
      });
      return true;
    },
    plus(at: Date = now): boolean {
      return grantsPlus(rows.values(), at);
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
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    revocationDate: null,
    upgraded: false,
    ...overrides,
  };
}

function verifyDeps(
  book: ReturnType<typeof ledger>,
  transaction: VerifiedTransaction,
): VerifyStoreDeps {
  return {
    userId: () => Promise.resolve(user),
    now: () => now,
    expectedBundleId: bundle,
    verify: () => Promise.resolve(transaction),
    boundUser: () => Promise.resolve(null),
    bind: () => Promise.resolve(),
    current: (_owner, productId) => Promise.resolve(book.current(productId)),
    write: (row, expected) => Promise.resolve(book.write(row, expected)),
  };
}

async function applyVerify(
  book: ReturnType<typeof ledger>,
  transaction: VerifiedTransaction,
): Promise<Response> {
  return await handleVerifyStoreTransaction(
    post({
      signedTransaction: jws,
      status: "active",
      expiresAt: "2099-01-01T00:00:00.000Z",
    }),
    verifyDeps(book, transaction),
  );
}

/// app-store-notifications/index.ts と同じ引数で加入を書く。
async function applyNotice(book: ReturnType<typeof ledger>, notice: Notice): Promise<void> {
  const decision = decideNotificationEntitlement({
    notificationType: notice.notificationType,
    subtype: notice.subtype ?? null,
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: notice.productId ?? monthly,
    environment: "Production",
    originalTransactionId: notice.originalTransactionId ?? "1000001",
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
    load: () => Promise.resolve(book.current(decision.row.product_id)),
    skip: (current) => skipsOlderEntitlement({
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

Deno.test("isPlus reads any product row that is active and still in the future", async () => {
  const handlers = [
    "lookup-food-text/handler.ts",
    "analyze-meal-photo/handler.ts",
    "cook-coach/handler.ts",
  ];
  for (const path of handlers) {
    const source = await Deno.readTextFile(new URL(`./${path}`, import.meta.url));
    assert(
      source.includes("&status=eq.active&expires_at=gt."),
      path,
    );
  }
  // 端末の有料表示は StoreKit。以前 app_controller にあった
  // status=active かつ expires_at が未来、の読み取りは PR #80 の
  // ワンタップ切替だけが使い、1.0.0+11 でコードから外した。
  const app = await Deno.readTextFile(
    new URL("../../lib/state/app_controller.dart", import.meta.url),
  );
  assert(!app.includes("CALONAVI_TEST_PURCHASE"));
  assert(!app.includes("adoptServerPlusForTest"));
  const caller = await Deno.readTextFile(
    new URL("../../lib/repositories/usage_record_repository.dart", import.meta.url),
  );
  assert(caller.includes("'verify-store-transaction'"));
  assert(caller.includes("signedTransactions"));
  assert(!caller.includes("source_transaction_id"));

  const wiring = await Deno.readTextFile(
    new URL("./app-store-notifications/index.ts", import.meta.url),
  );
  for (const field of [
    "currentStatus: current?.status",
    "currentTransactionId: current?.transactionId",
    "transactionId: input.transactionId",
    "gracePeriodExpiresAt: input.gracePeriodExpiresDate",
    "upgraded: input.upgraded",
  ]) {
    assert(wiring.includes(field), field);
  }

  const at = now;
  assertEquals(grantsPlus([{
    expiresAt: "2026-11-08T00:00:00.000Z",
    status: "active",
    transactionId: "tx",
  }], at), true);
  assertEquals(grantsPlus([{
    expiresAt: now.toISOString(),
    status: "active",
    transactionId: "tx",
  }], at), false);
  assertEquals(grantsPlus([{
    expiresAt: "2027-01-01T00:00:00.000Z",
    status: "inactive",
    transactionId: "tx",
  }], at), false);
  assertEquals(grantsPlus([{
    expiresAt: "2027-01-01T00:00:00.000Z",
    status: "expired",
    transactionId: "tx",
  }], at), false);
  assertEquals(grantsPlus([
    {
      expiresAt: "2026-11-08T00:00:00.000Z",
      status: "expired",
      transactionId: "tx-month",
    },
    {
      expiresAt: "2027-10-08T00:00:00.000Z",
      status: "inactive",
      transactionId: "tx-year",
    },
  ], at), false);
  assertEquals(grantsPlus([
    {
      expiresAt: "2026-11-08T00:00:00.000Z",
      status: "active",
      transactionId: "tx-month",
    },
    {
      expiresAt: "2027-10-08T00:00:00.000Z",
      status: "inactive",
      transactionId: "tx-year",
    },
  ], at), true);
});

Deno.test("a same-transaction refund from the app clears grace without a grace date", async () => {
  const book = ledger();
  await applyNotice(book, {
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    transactionId: "tx-grace",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
    gracePeriodExpiresDate: Date.parse("2026-10-24T00:00:00.000Z"),
  });
  assertEquals(book.plus(), true);
  assertEquals(book.current(monthly)?.expiresAt, "2026-10-24T00:00:00.000Z");

  const resent = await applyVerify(book, verified({
    transactionId: "tx-grace",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
  }));
  assertEquals(resent.status, 200);
  assertEquals(book.current(monthly)?.expiresAt, "2026-10-24T00:00:00.000Z");
  assertEquals(book.plus(), true);

  const refund = await applyVerify(book, verified({
    transactionId: "tx-grace",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  }));
  assertEquals(refund.status, 200);
  assertEquals(await refund.json(), { ok: true });
  assertEquals(book.current(monthly)?.status, "inactive");
  assertEquals(book.plus(), false);
});

Deno.test("a refund notification clears the same transaction even when grace matches", async () => {
  const grace = Date.parse("2026-10-24T00:00:00.000Z");
  const book = ledger();
  await applyNotice(book, {
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    transactionId: "tx-grace",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
    gracePeriodExpiresDate: grace,
  });
  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-grace",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
    gracePeriodExpiresDate: grace,
  });
  assertEquals(book.current(monthly)?.status, "inactive");
  assertEquals(book.plus(), false);

  const kept = ledger();
  await applyNotice(kept, {
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    transactionId: "tx-current",
    expiresDate: Date.parse("2026-10-07T00:00:00.000Z"),
    gracePeriodExpiresDate: grace,
  });
  await applyNotice(kept, {
    notificationType: "REFUND",
    transactionId: "tx-old",
    expiresDate: Date.parse("2026-09-08T00:00:00.000Z"),
    gracePeriodExpiresDate: grace,
  });
  assertEquals(kept.current(monthly)?.transactionId, "tx-current");
  assertEquals(kept.current(monthly)?.status, "active");
  assertEquals(kept.plus(), true);
});

Deno.test("upgrading monthly to annual and refunding annual drops Plus", async () => {
  const book = ledger();
  const bought = await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
  }));
  assertEquals(bought.status, 200);
  const upgraded = await applyVerify(book, verified({
    productId: yearly,
    transactionId: "tx-year",
    originalTransactionId: "1000001",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  }));
  assertEquals(upgraded.status, 200);
  const oldPlan = await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    upgraded: true,
  }));
  assertEquals(oldPlan.status, 200);
  assertEquals(book.current(monthly)?.status, "expired");
  assertEquals(book.current(yearly)?.status, "active");
  assertEquals(book.plus(), true);

  await applyNotice(book, {
    notificationType: "REFUND",
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  });
  assertEquals(book.current(yearly)?.status, "inactive");
  assertEquals(book.current(monthly)?.status, "expired");
  assertEquals(book.current(half), null);
  assertEquals(book.plus(), false);
});

Deno.test("a paid monthly row stays Plus when a separate annual purchase is refunded", async () => {
  const book = ledger();
  await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
  }));
  await applyVerify(book, verified({
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  }));
  await applyNotice(book, {
    notificationType: "REFUND",
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  });
  assertEquals(book.current(monthly)?.status, "active");
  assertEquals(book.current(yearly)?.status, "inactive");
  assertEquals(book.plus(), true);
});

Deno.test("a crossgrade from annual to monthly keeps the paid annual period", async () => {
  const book = ledger();
  await applyNotice(book, {
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  });
  await applyNotice(book, {
    notificationType: "DID_CHANGE_RENEWAL_PREF",
    subtype: "DOWNGRADE",
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  });
  assertEquals(book.current(yearly)?.status, "active");
  assertEquals(book.plus(), true);

  await applyNotice(book, {
    notificationType: "DID_RENEW",
    productId: monthly,
    transactionId: "tx-month-next",
    expiresDate: Date.parse("2027-11-08T00:00:00.000Z"),
  });
  await applyNotice(book, {
    notificationType: "EXPIRED",
    productId: yearly,
    transactionId: "tx-year",
    expiresDate: Date.parse("2027-10-08T00:00:00.000Z"),
  });
  assertEquals(book.current(yearly)?.status, "expired");
  assertEquals(book.current(monthly)?.status, "active");
  assertEquals(book.plus(), true);
});

Deno.test("a renewal after a refund restores Plus, including a shorter trial", async () => {
  const book = ledger();
  await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
  }));
  await applyVerify(book, verified({
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  }));
  assertEquals(book.plus(), false);

  const trial = await applyVerify(book, verified({
    transactionId: "tx-trial",
    expiresDate: Date.parse("2026-10-11T00:00:00.000Z"),
  }));
  assertEquals(trial.status, 200);
  assertEquals(book.current(monthly)?.status, "active");
  assertEquals(book.current(monthly)?.transactionId, "tx-trial");
  assertEquals(book.plus(), true);

  await applyNotice(book, {
    notificationType: "REFUND",
    transactionId: "tx-trial",
    expiresDate: Date.parse("2026-10-11T00:00:00.000Z"),
  });
  assertEquals(book.plus(), false);
  await applyNotice(book, {
    notificationType: "DID_RENEW",
    transactionId: "tx-renewal",
    expiresDate: Date.parse("2026-12-08T00:00:00.000Z"),
  });
  assertEquals(book.current(monthly)?.status, "active");
  assertEquals(book.current(monthly)?.transactionId, "tx-renewal");
  assertEquals(book.plus(), true);
});

Deno.test("a late expiry after a renewal does not clear the newer period", async () => {
  const book = ledger();
  await applyNotice(book, {
    notificationType: "DID_RENEW",
    transactionId: "tx-new",
    expiresDate: Date.parse("2026-12-08T00:00:00.000Z"),
  });
  await applyNotice(book, {
    notificationType: "EXPIRED",
    transactionId: "tx-old",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    gracePeriodExpiresDate: Date.parse("2026-12-20T00:00:00.000Z"),
  });
  assertEquals(book.current(monthly)?.transactionId, "tx-new");
  assertEquals(book.current(monthly)?.status, "active");
  assertEquals(book.plus(), true);
});

Deno.test("a concurrent renewal wins over a late expiry, and a stuck conflict returns 500", async () => {
  let stored: StoredEntitlement | null = {
    expiresAt: "2026-11-08T00:00:00.000Z",
    status: "active",
    transactionId: "tx-old",
  };
  let writes = 0;
  const renewal = decideEntitlement({
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: "1000001",
    boundUserId: user,
    expiresDate: Date.parse("2026-12-08T00:00:00.000Z"),
    revocationDate: null,
    transactionId: "tx-new",
    now,
  });
  const expiry = decideNotificationEntitlement({
    notificationType: "EXPIRED",
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: monthly,
    environment: "Production",
    originalTransactionId: "1000001",
    boundUserId: user,
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    revocationDate: null,
    transactionId: "tx-old",
    now,
  });
  if (!renewal.ok || !expiry.ok) {
    throw new Error("decision");
  }
  const seen = stored;
  await Promise.all([
    settlePlusEntitlement({
      row: renewal.row,
      load: () => Promise.resolve(stored),
      skip: (current) => skipsOlderEntitlement({
        notificationType: "DID_RENEW",
        revoked: false,
        currentExpiresAt: current?.expiresAt ?? null,
        currentStatus: current?.status ?? null,
        currentTransactionId: current?.transactionId ?? null,
        nextExpiresAt: renewal.row.expires_at,
        transactionExpiresAt: Date.parse("2026-12-08T00:00:00.000Z"),
        transactionId: "tx-new",
        now,
      }),
      save: (row, expected) => {
        if (stored?.expiresAt !== expected?.expiresAt || stored?.transactionId !== expected?.transactionId) {
          return Promise.resolve(false);
        }
        stored = {
          expiresAt: row.expires_at,
          status: row.status,
          transactionId: row.source_transaction_id,
        };
        writes += 1;
        return Promise.resolve(true);
      },
    }),
    settlePlusEntitlement({
      row: expiry.row,
      load: () => Promise.resolve(stored),
      skip: (current) => skipsOlderEntitlement({
        notificationType: "EXPIRED",
        revoked: false,
        currentExpiresAt: current?.expiresAt ?? null,
        currentStatus: current?.status ?? null,
        currentTransactionId: current?.transactionId ?? null,
        nextExpiresAt: expiry.row.expires_at,
        transactionExpiresAt: Date.parse("2026-11-08T00:00:00.000Z"),
        transactionId: "tx-old",
        now,
      }),
      save: (row, expected) => {
        if (
          stored?.expiresAt !== expected?.expiresAt ||
          stored?.status !== expected?.status ||
          stored?.transactionId !== expected?.transactionId
        ) {
          return Promise.resolve(false);
        }
        stored = {
          expiresAt: row.expires_at,
          status: row.status,
          transactionId: row.source_transaction_id,
        };
        writes += 1;
        return Promise.resolve(true);
      },
    }),
  ]);
  assertEquals(seen.transactionId, "tx-old");
  assertEquals(stored?.transactionId, "tx-new");
  assertEquals(stored?.status, "active");
  assertEquals(grantsPlus([stored!], now), true);
  assert(writes >= 1);

  let reads = 0;
  await assertRejects(
    () => settlePlusEntitlement({
      row: expiry.row,
      load: () => {
        reads += 1;
        return Promise.resolve({
          expiresAt: "2026-11-08T00:00:00.000Z",
          status: "active",
          transactionId: "tx-old",
        });
      },
      skip: () => false,
      save: () => Promise.resolve(false),
    }),
    Error,
    "entitlement conflict",
  );
  assertEquals(reads, 4);

  const response = await handleAppStoreNotification(
    new Request("https://example.test/app-store-notifications", {
      method: "POST",
      body: JSON.stringify({ signedPayload: "signed" }),
    }),
    {
      verify: () => Promise.resolve({
        notificationUUID: "44444444-4444-4444-8444-444444444444",
        notificationType: "EXPIRED",
        subtype: null,
        originalTransactionId: "1000001",
        transactionId: "tx-old",
        productId: monthly,
        bundleId: bundle,
        environment: "Production",
        expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
        revocationDate: null,
        signedPayload: "signed",
        decoded: {},
      }),
      exists: () => Promise.resolve(false),
      matchUser: () => Promise.resolve({ userId: user, deleted: false }),
      applyEntitlement: () => settlePlusEntitlement({
        row: expiry.row,
        load: () => Promise.resolve({
          expiresAt: "2026-11-08T00:00:00.000Z",
          status: "active",
          transactionId: "tx-old",
        }),
        skip: () => false,
        save: () => Promise.resolve(false),
      }),
      insert: () => Promise.resolve(),
      insertFailed: () => Promise.resolve(),
    },
  );
  assertEquals(response.status, 500);
  assertEquals(await response.text(), "entitlement failed");
});

Deno.test("a duplicate notification is idempotent", async () => {
  let applies = 0;
  const rows: Record<string, unknown>[] = [];
  const deps = {
    verify: () => Promise.resolve({
      notificationUUID: "55555555-5555-4555-8555-555555555555",
      notificationType: "REFUND",
      subtype: null,
      originalTransactionId: "1000001",
      transactionId: "tx-month",
      productId: monthly,
      bundleId: bundle,
      environment: "Production",
      expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
      revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
      signedPayload: "signed",
      decoded: { notificationType: "REFUND" },
    }),
    exists: () => Promise.resolve(rows.length > 0),
    matchUser: () => Promise.resolve({ userId: user, deleted: false }),
    applyEntitlement: () => {
      applies += 1;
      return Promise.resolve();
    },
    insert: (row: Record<string, unknown>) => {
      rows.push(row);
      return Promise.resolve();
    },
    insertFailed: () => Promise.resolve(),
  };
  const body = JSON.stringify({ signedPayload: "signed" });
  const first = await handleAppStoreNotification(
    new Request("https://example.test/app-store-notifications", { method: "POST", body }),
    deps,
  );
  const second = await handleAppStoreNotification(
    new Request("https://example.test/app-store-notifications", { method: "POST", body }),
    deps,
  );
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(await second.text(), "duplicate");
  assertEquals(applies, 1);

  const book = ledger();
  const refund: Notice = {
    notificationType: "REFUND",
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
    revocationDate: Date.parse("2026-10-09T00:00:00.000Z"),
  };
  await applyNotice(book, {
    notificationType: "SUBSCRIBED",
    transactionId: "tx-month",
    expiresDate: Date.parse("2026-11-08T00:00:00.000Z"),
  });
  await applyNotice(book, refund);
  await applyNotice(book, refund);
  assertEquals(book.current(monthly)?.status, "inactive");
  assertEquals(book.plus(), false);
});

Deno.test("a legacy row without a transaction id stays conservative", async () => {
  const later = "2026-12-08T00:00:00.000Z";
  assertEquals(skipsOlderEntitlement({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: later,
    currentStatus: "active",
    currentTransactionId: null,
    nextExpiresAt: "2026-11-08T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-11-08T00:00:00.000Z"),
    transactionId: "tx-old",
    now,
  }), true);
  assertEquals(skipsOlderEntitlement({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: "2026-11-08T00:00:00.000Z",
    currentStatus: "active",
    currentTransactionId: null,
    nextExpiresAt: "2026-11-08T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-11-08T00:00:00.000Z"),
    transactionId: "tx-same-period",
    now,
  }), false);
  const grace = Date.parse("2026-10-24T00:00:00.000Z");
  assertEquals(skipsOlderEntitlement({
    revoked: true,
    currentExpiresAt: "2026-10-24T00:00:00.000Z",
    currentStatus: "active",
    currentTransactionId: null,
    nextExpiresAt: "2026-10-07T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-10-07T00:00:00.000Z"),
    transactionId: "tx-grace",
    now,
  }), true);
  assertEquals(skipsOlderEntitlement({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: "2026-10-24T00:00:00+00:00",
    currentStatus: "active",
    currentTransactionId: null,
    nextExpiresAt: "2026-10-07T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-10-07T00:00:00.000Z"),
    gracePeriodExpiresAt: grace,
    transactionId: "tx-grace",
    now,
  }), false);
  assertEquals(sourceTransactionId(null), null);
  assertEquals(sourceTransactionId("   "), null);
});

Deno.test("millisecond timestamps are active and second timestamps are not", () => {
  const instant = Date.parse("2026-11-08T00:00:00.000Z");
  assertEquals(entitlementTiming({
    expiresDate: instant,
    revocationDate: null,
    now,
  }).status, "active");
  assertEquals(entitlementTiming({
    expiresDate: Math.floor(instant / 1000),
    revocationDate: null,
    now,
  }).status, "expired");
  assertEquals(entitlementTiming({
    expiresDate: now.getTime(),
    revocationDate: null,
    now,
  }).status, "expired");
  assertEquals(storeTransactionId(" 2000000123456789 "), "2000000123456789");
  assertEquals(storeTransactionId(2000000123456789), "2000000123456789");
  assertEquals(
    sourceTransactionId(storeTransactionId(" 2000000123456789 ")),
    sourceTransactionId(storeTransactionId(2000000123456789)),
  );
  const grace = Date.parse("2026-10-24T00:00:00.000Z");
  assertEquals(skipsOlderEntitlement({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: "2026-10-24T00:00:00.000000+00:00",
    currentTransactionId: null,
    nextExpiresAt: "2026-10-07T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-10-07T00:00:00.000Z"),
    gracePeriodExpiresAt: grace,
    now,
  }), false);
});

Deno.test("verify responses stay 200, 401, 400, and 409", async () => {
  const book = ledger();
  const ok = await applyVerify(book, verified());
  assertEquals(ok.status, 200);
  assertEquals(await ok.json(), { ok: true });

  const anon = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), {
    ...verifyDeps(book, verified()),
    userId: () => Promise.resolve(null),
  });
  assertEquals(anon.status, 401);

  const bad = await handleVerifyStoreTransaction(post({ signedTransaction: "not-a-jws" }), verifyDeps(book, verified()));
  assertEquals(bad.status, 400);

  const conflict = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), {
    ...verifyDeps(book, verified()),
    boundUser: () => Promise.resolve(other),
  });
  assertEquals(conflict.status, 409);
  assertEquals((await conflict.json()).code, "bound_to_other_user");
});
