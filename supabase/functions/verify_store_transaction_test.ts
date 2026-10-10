import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decideEntitlement,
  decideNotificationEntitlement,
  notificationSkipsOlderExpiry,
  shouldSkipOlderExpiry,
  skipsOlderEntitlement,
} from "./_shared/store_entitlement.ts";
import {
  handleVerifyStoreTransaction,
  type VerifiedTransaction,
  type VerifyStoreDeps,
} from "./verify-store-transaction/handler.ts";

const user = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
const bundle = "com.narutoaii.ayg";
const now = new Date("2026-10-08T00:00:00Z");
const future = Date.parse("2026-11-08T00:00:00Z");

function verified(overrides: Partial<VerifiedTransaction> = {}): VerifiedTransaction {
  return {
    bundleId: bundle,
    productId: "calonavi_plus_monthly",
    environment: "Production",
    originalTransactionId: "1000001",
    expiresDate: future,
    revocationDate: null,
    ...overrides,
  };
}

function harness(options: {
  verify?: (jws: string) => Promise<VerifiedTransaction>;
  bound?: Record<string, string>;
  userId?: string | null;
  current?: (userId: string, productId: string) => Promise<{ expiresAt: string | null } | null>;
} = {}): { deps: VerifyStoreDeps; writes: Array<Record<string, unknown>>; binds: string[] } {
  const writes: Array<Record<string, unknown>> = [];
  const binds: string[] = [];
  const bound = { ...(options.bound ?? {}) };
  return {
    writes,
    binds,
    deps: {
      userId: () => Promise.resolve(options.userId === undefined ? user : options.userId),
      now: () => now,
      expectedBundleId: bundle,
      verify: options.verify ?? ((jws) => {
        if (jws.includes("forged")) {
          return Promise.reject(new Error("bad chain"));
        }
        return Promise.resolve(verified());
      }),
      boundUser: (originalTransactionId) => Promise.resolve(bound[originalTransactionId] ?? null),
      bind: (originalTransactionId, owner) => {
        binds.push(`${originalTransactionId}:${owner}`);
        bound[originalTransactionId] = owner;
        return Promise.resolve();
      },
      write: (row) => {
        writes.push(row);
        return Promise.resolve();
      },
      current: options.current,
    },
  };
}

function post(body: unknown): Request {
  return new Request("https://example.test/verify-store-transaction", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

const jws = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ0In0.sig";

Deno.test("a forged transaction is rejected and writes nothing", async () => {
  const { deps, writes, binds } = harness();
  const response = await handleVerifyStoreTransaction(
    post({ signedTransaction: "aaa.forged.bbb", status: "active", expiresAt: "2099-01-01" }),
    deps,
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_transaction");
  assertEquals(writes, []);
  assertEquals(binds, []);
});

Deno.test("a verified transaction writes the server row, not the client expiry", async () => {
  const { deps, writes, binds } = harness();
  const response = await handleVerifyStoreTransaction(
    post({
      signedTransaction: jws,
      status: "active",
      expiresAt: "2099-01-01T00:00:00Z",
    }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(binds, ["1000001:" + user]);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].status, "active");
  assertEquals(writes[0].expires_at, "2026-11-08T00:00:00.000Z");
  assertEquals(writes[0].product_id, "calonavi_plus_monthly");
  assertEquals(writes[0].advertising_use, false);
});

Deno.test("sandbox transactions are accepted for review and TestFlight", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({ environment: "Sandbox", productId: "calonavi_plus_yearly" })),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes[0].product_id, "calonavi_plus_yearly");
  assertEquals(writes[0].status, "active");
});

Deno.test("a transaction bound to another user is rejected", async () => {
  const { deps, writes, binds } = harness({
    bound: { "1000001": other },
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 409);
  assertEquals((await response.json()).code, "bound_to_other_user");
  assertEquals(writes, []);
  assertEquals(binds, []);
});

Deno.test("the wrong bundle or product is rejected", async () => {
  const wrongBundle = harness({
    verify: () => Promise.resolve(verified({ bundleId: "com.example.other" })),
  });
  const bundleResponse = await handleVerifyStoreTransaction(
    post({ signedTransaction: jws }),
    wrongBundle.deps,
  );
  assertEquals(bundleResponse.status, 400);
  assertEquals(wrongBundle.writes, []);

  const wrongProduct = harness({
    verify: () => Promise.resolve(verified({ productId: "calonavi_plus_test" })),
  });
  const productResponse = await handleVerifyStoreTransaction(
    post({ signedTransaction: jws }),
    wrongProduct.deps,
  );
  assertEquals(productResponse.status, 400);
  assertEquals(wrongProduct.writes, []);
});

Deno.test("an older renewal does not move expires_at backward", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({ expiresDate: Date.parse("2026-10-20T00:00:00Z") })),
    current: () => Promise.resolve({ expiresAt: "2026-12-08T00:00:00.000Z" }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes, []);
  assertEquals(shouldSkipOlderExpiry({
    revoked: false,
    currentExpiresAt: "2026-12-08T00:00:00.000Z",
    nextExpiresAt: "2026-10-20T00:00:00.000Z",
  }), true);
});

Deno.test("a later renewal replaces the stored expiry", async () => {
  const later = Date.parse("2027-01-08T00:00:00Z");
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({ expiresDate: later })),
    current: () => Promise.resolve({ expiresAt: "2026-11-08T00:00:00.000Z" }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].expires_at, "2027-01-08T00:00:00.000Z");
  assertEquals(writes[0].status, "active");
});

Deno.test("an older revoked transaction does not clear a later paid period", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({
      expiresDate: Date.parse("2026-10-20T00:00:00Z"),
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
    })),
    current: () => Promise.resolve({ expiresAt: "2026-12-08T00:00:00.000Z" }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes, []);
});

Deno.test("a same-period refund revokes Plus immediately", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({
      expiresDate: future,
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
    })),
    current: () => Promise.resolve({ expiresAt: "2026-11-08T00:00:00.000Z" }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].status, "inactive");
  assertEquals(writes[0].expires_at, "2026-11-08T00:00:00.000Z");
});

Deno.test("a newer signed transaction survives an older revoked one in the same request", async () => {
  let stored: string | null = null;
  const newer = "header.newer.payload";
  const older = "header.older.payload";
  const { deps, writes } = harness({
    verify: (token) => {
      if (token === newer) {
        return Promise.resolve(verified({
          expiresDate: Date.parse("2026-12-01T00:00:00Z"),
          originalTransactionId: "200",
        }));
      }
      return Promise.resolve(verified({
        expiresDate: Date.parse("2026-11-01T00:00:00Z"),
        revocationDate: Date.parse("2026-10-09T00:00:00Z"),
        originalTransactionId: "100",
      }));
    },
    current: () => Promise.resolve(stored == null ? null : { expiresAt: stored }),
  });
  const write = deps.write;
  deps.write = (row) => {
    stored = row.expires_at;
    return write(row);
  };
  const response = await handleVerifyStoreTransaction(
    post({ signedTransactions: [newer, older] }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].status, "active");
  assertEquals(writes[0].expires_at, "2026-12-01T00:00:00.000Z");
});

Deno.test("verify and notifications skip the same revocation periods", () => {
  const graceEnd = Date.parse("2026-10-24T00:00:00Z");
  const cases = [
    {
      name: "older revocation keeps a later paid period",
      stored: "2026-12-01T00:00:00.000Z",
      expiresDate: Date.parse("2026-11-01T00:00:00Z"),
      grace: Date.parse("2026-12-15T00:00:00Z"),
      skip: true,
    },
    {
      name: "same-period refund revokes",
      stored: "2026-11-08T00:00:00.000Z",
      expiresDate: future,
      grace: null,
      skip: false,
    },
    {
      name: "stored grace date is revoked",
      stored: "2026-10-24T00:00:00.000Z",
      expiresDate: Date.parse("2026-10-07T00:00:00Z"),
      grace: graceEnd,
      skip: false,
    },
    {
      name: "a past stored expiry is revoked",
      stored: "2026-10-01T00:00:00.000Z",
      expiresDate: Date.parse("2026-10-01T00:00:00Z"),
      grace: null,
      skip: false,
    },
  ];
  for (const row of cases) {
    const verifyDecision = decideEntitlement({
      userId: user,
      expectedBundleId: bundle,
      bundleId: bundle,
      productId: "calonavi_plus_monthly",
      environment: "Production",
      originalTransactionId: "1000001",
      boundUserId: user,
      expiresDate: row.expiresDate,
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
      now,
    });
    const notificationDecision = decideNotificationEntitlement({
      notificationType: "REFUND",
      userId: user,
      expectedBundleId: bundle,
      bundleId: bundle,
      productId: "calonavi_plus_monthly",
      environment: "Production",
      originalTransactionId: "1000001",
      boundUserId: user,
      expiresDate: row.expiresDate,
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
      gracePeriodExpiresDate: row.grace,
      now,
    });
    if (!verifyDecision.ok || !notificationDecision.ok) {
      throw new Error(row.name);
    }
    const verifySkip = skipsOlderEntitlement({
      revoked: true,
      currentExpiresAt: row.stored,
      nextExpiresAt: verifyDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      gracePeriodExpiresAt: row.grace,
      now,
    });
    const notificationSkip = notificationSkipsOlderExpiry({
      notificationType: "REFUND",
      revoked: true,
      currentExpiresAt: row.stored,
      nextExpiresAt: notificationDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      gracePeriodExpiresAt: row.grace,
      now,
    });
    const revokeSkip = notificationSkipsOlderExpiry({
      notificationType: "REVOKE",
      revoked: true,
      currentExpiresAt: row.stored,
      nextExpiresAt: notificationDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      gracePeriodExpiresAt: row.grace,
      now,
    });
    assertEquals(verifySkip, notificationSkip, row.name);
    assertEquals(verifySkip, revokeSkip, row.name);
    assertEquals(verifySkip, row.skip, row.name);
    assertEquals(verifyDecision.row.status, "inactive", row.name);
    assertEquals(notificationDecision.row.status, "inactive", row.name);
  }
});

Deno.test("decideEntitlement keeps a revoked transaction inactive", () => {
  const decision = decideEntitlement({
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: "calonavi_plus_half_year",
    environment: "Production",
    originalTransactionId: "9",
    boundUserId: user,
    expiresDate: future,
    revocationDate: Date.parse("2026-10-01T00:00:00Z"),
    now,
  });
  assertEquals(decision.ok, true);
  if (decision.ok) {
    assertEquals(decision.row.status, "inactive");
  }
});
