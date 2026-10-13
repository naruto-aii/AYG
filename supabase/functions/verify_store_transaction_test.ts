import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decideEntitlement,
  decideNotificationEntitlement,
  notificationSkipsOlderExpiry,
  plusAccessFromEntitlement,
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
    transactionId: "tx-1000001",
    expiresDate: future,
    revocationDate: null,
    upgraded: false,
    ...overrides,
  };
}

function harness(options: {
  verify?: (jws: string) => Promise<VerifiedTransaction>;
  bound?: Record<string, string>;
  userId?: string | null;
  current?: VerifyStoreDeps["current"];
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
        return Promise.resolve(true);
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
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.code, undefined);
  assertEquals(body.plus, true);
  assertEquals(body.expiresAt, "2026-11-08T00:00:00.000Z");
  assertEquals(build11ClientAccepts(response.status, body), true);
});

Deno.test("a new sandbox purchase unlocks Plus and another account cannot reuse it", async () => {
  const review = verified({
    environment: "Sandbox",
    productId: "calonavi_plus_yearly",
    originalTransactionId: "sandbox-review-1",
    transactionId: "sandbox-review-tx",
    expiresDate: Date.parse("2026-11-11T00:00:00Z"),
  });
  const first = harness({
    verify: () => Promise.resolve(review),
  });
  const bought = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), first.deps);
  assertEquals(bought.status, 200);
  assertEquals(first.writes[0].status, "active");
  assertEquals(first.writes[0].product_id, "calonavi_plus_yearly");
  assertEquals(plusAccessFromEntitlement({
    status: String(first.writes[0].status),
    expiresAt: String(first.writes[0].expires_at),
    now,
  }), true);

  const second = harness({
    userId: other,
    bound: { "sandbox-review-1": user },
    verify: () => Promise.resolve(review),
  });
  const reused = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), second.deps);
  assertEquals(reused.status, 409);
  assertEquals((await reused.json()).code, "bound_to_other_user");
  assertEquals(second.writes, []);

  const refunded = harness({
    verify: () => Promise.resolve(verified({
      environment: "Sandbox",
      originalTransactionId: "sandbox-review-2",
      revocationDate: now.getTime(),
    })),
  });
  const refund = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), refunded.deps);
  assertEquals(refund.status, 200);
  assertEquals(refunded.writes[0].status, "inactive");
  assertEquals(plusAccessFromEntitlement({
    status: String(refunded.writes[0].status),
    expiresAt: refunded.writes[0].expires_at == null
      ? null
      : String(refunded.writes[0].expires_at),
    now,
  }), false);
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
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.plus, false);
  assertEquals(body.expiresAt, null);
  assertEquals(body.code, undefined);
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
          transactionId: "tx-new",
        }));
      }
      return Promise.resolve(verified({
        expiresDate: Date.parse("2026-11-01T00:00:00Z"),
        revocationDate: Date.parse("2026-10-09T00:00:00Z"),
        originalTransactionId: "100",
        transactionId: "tx-old",
      }));
    },
    current: () => Promise.resolve(stored == null ? null : { expiresAt: stored }),
  });
  const write = deps.write;
  deps.write = (row, expected) => {
    stored = row.expires_at;
    return write(row, expected);
  };
  const response = await handleVerifyStoreTransaction(
    post({ signedTransactions: [newer, older] }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].status, "active");
  assertEquals(writes[0].expires_at, "2026-12-01T00:00:00.000Z");
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.plus, true);
  assertEquals(body.expiresAt, "2026-12-01T00:00:00.000Z");
});

Deno.test("verify and notifications skip the same revocation periods", () => {
  const graceEnd = Date.parse("2026-10-24T00:00:00Z");
  const cases = [
    {
      name: "older revocation keeps a later paid period",
      stored: "2026-12-01T00:00:00.000Z",
      storedTransactionId: "tx-new",
      transactionId: "tx-old",
      expiresDate: Date.parse("2026-11-01T00:00:00Z"),
      grace: Date.parse("2026-12-15T00:00:00Z"),
      skip: true,
    },
    {
      name: "same-period refund revokes",
      stored: "2026-11-08T00:00:00.000Z",
      storedTransactionId: "tx-current",
      transactionId: "tx-current",
      expiresDate: future,
      grace: null,
      skip: false,
    },
    {
      name: "stored grace date is revoked without the verify request seeing grace",
      stored: "2026-10-24T00:00:00.000Z",
      storedTransactionId: "tx-grace",
      transactionId: "tx-grace",
      expiresDate: Date.parse("2026-10-07T00:00:00Z"),
      grace: null,
      skip: false,
    },
    {
      name: "a past stored expiry is revoked",
      stored: "2026-10-01T00:00:00.000Z",
      storedTransactionId: "tx-old",
      transactionId: "tx-old",
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
      transactionId: row.transactionId,
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
      transactionId: row.transactionId,
      now,
    });
    if (!verifyDecision.ok || !notificationDecision.ok) {
      throw new Error(row.name);
    }
    // verify-store-transaction は猶予日を受け取らない。取引IDで通知と揃える。
    const verifySkip = skipsOlderEntitlement({
      revoked: true,
      currentExpiresAt: row.stored,
      currentTransactionId: row.storedTransactionId,
      nextExpiresAt: verifyDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      transactionId: row.transactionId,
      now,
    });
    const notificationSkip = notificationSkipsOlderExpiry({
      notificationType: "REFUND",
      revoked: true,
      currentExpiresAt: row.stored,
      currentTransactionId: row.storedTransactionId,
      nextExpiresAt: notificationDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      transactionId: row.transactionId,
      gracePeriodExpiresAt: row.grace,
      now,
    });
    const revokeSkip = notificationSkipsOlderExpiry({
      notificationType: "REVOKE",
      revoked: true,
      currentExpiresAt: row.stored,
      currentTransactionId: row.storedTransactionId,
      nextExpiresAt: notificationDecision.row.expires_at,
      transactionExpiresAt: row.expiresDate,
      transactionId: row.transactionId,
      gracePeriodExpiresAt: row.grace,
      now,
    });
    assertEquals(verifySkip, notificationSkip, row.name);
    assertEquals(verifySkip, revokeSkip, row.name);
    assertEquals(verifySkip, row.skip, row.name);
    assertEquals(verifyDecision.row.status, "inactive", row.name);
    assertEquals(notificationDecision.row.status, "inactive", row.name);
    assertEquals(verifyDecision.row.source_transaction_id, row.transactionId, row.name);
  }
});

Deno.test("a refund of the stored transaction clears a grace extension", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({
      transactionId: "tx-grace",
      expiresDate: Date.parse("2026-10-07T00:00:00Z"),
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
    })),
    current: () => Promise.resolve({
      expiresAt: "2026-10-24T00:00:00.000Z",
      status: "active",
      transactionId: "tx-grace",
    }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes.length, 1);
  assertEquals(writes[0].status, "inactive");
  assertEquals(writes[0].source_transaction_id, "tx-grace");
});

Deno.test("resending the grace transaction does not shorten the grace date", async () => {
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({
      transactionId: "tx-grace",
      expiresDate: Date.parse("2026-10-07T00:00:00Z"),
    })),
    current: () => Promise.resolve({
      expiresAt: "2026-10-24T00:00:00.000Z",
      status: "active",
      transactionId: "tx-grace",
    }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(writes, []);
});

Deno.test("an upgraded transaction expires that product without clearing a later one", async () => {
  const yearly = "header.yearly.payload";
  const monthly = "header.monthly.payload";
  const stored = new Map<string, { expiresAt: string | null; status: string; transactionId: string | null }>();
  stored.set("calonavi_plus_monthly", {
    expiresAt: "2026-12-01T00:00:00.000Z",
    status: "active",
    transactionId: "tx-month",
  });
  const { deps, writes } = harness({
    verify: (token) => {
      if (token === yearly) {
        return Promise.resolve(verified({
          productId: "calonavi_plus_yearly",
          originalTransactionId: "same-group",
          transactionId: "tx-year",
          expiresDate: Date.parse("2027-10-08T00:00:00Z"),
        }));
      }
      return Promise.resolve(verified({
        productId: "calonavi_plus_monthly",
        originalTransactionId: "same-group",
        transactionId: "tx-month",
        expiresDate: Date.parse("2026-10-10T00:00:00Z"),
        upgraded: true,
      }));
    },
    current: (_userId, productId) => Promise.resolve(stored.get(productId) ?? null),
  });
  const write = deps.write;
  deps.write = (row, expected) => {
    stored.set(row.product_id, {
      expiresAt: row.expires_at,
      status: row.status,
      transactionId: row.source_transaction_id,
    });
    return write(row, expected);
  };
  const response = await handleVerifyStoreTransaction(
    post({ signedTransactions: [yearly, monthly] }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(writes.map((row) => [row.product_id, row.status]), [
    ["calonavi_plus_yearly", "active"],
    ["calonavi_plus_monthly", "expired"],
  ]);

  const laterMonthly = harness({
    verify: () => Promise.resolve(verified({
      transactionId: "tx-month-old",
      expiresDate: Date.parse("2026-11-01T00:00:00Z"),
      upgraded: true,
    })),
    current: () => Promise.resolve({
      expiresAt: "2027-01-08T00:00:00.000Z",
      status: "active",
      transactionId: "tx-month-new",
    }),
  });
  const kept = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), laterMonthly.deps);
  assertEquals(kept.status, 200);
  assertEquals(laterMonthly.writes, []);
});

Deno.test("a stale entitlement write is retried and then keeps the newer period", async () => {
  let reads = 0;
  let saves = 0;
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({
      transactionId: "tx-old",
      expiresDate: future,
      revocationDate: Date.parse("2026-10-09T00:00:00Z"),
    })),
    current: () => {
      reads += 1;
      if (reads === 1) {
        return Promise.resolve({
          expiresAt: "2026-11-08T00:00:00.000Z",
          status: "active",
          transactionId: "tx-old",
        });
      }
      return Promise.resolve({
        expiresAt: "2026-12-01T00:00:00.000Z",
        status: "active",
        transactionId: "tx-new",
      });
    },
  });
  const write = deps.write;
  deps.write = (row, expected) => {
    saves += 1;
    if (saves === 1) {
      return Promise.resolve(false);
    }
    return write(row, expected);
  };
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  assertEquals(response.status, 200);
  assertEquals(saves, 1);
  assertEquals(writes, []);
});

Deno.test("expiry equal to the grace date still counts as expired", () => {
  const graceEnd = Date.parse("2026-10-24T00:00:00Z");
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "GRACE_PERIOD_EXPIRED",
    revoked: false,
    currentExpiresAt: "2026-10-24T00:00:00.000Z",
    nextExpiresAt: "2026-10-07T23:59:59.000Z",
    transactionExpiresAt: Date.parse("2026-10-07T00:00:00Z"),
    gracePeriodExpiresAt: graceEnd,
    now,
  }), false);
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: "2026-10-24T00:00:00.000Z",
    nextExpiresAt: "2026-10-07T00:00:00.000Z",
    transactionExpiresAt: Date.parse("2026-10-07T00:00:00Z"),
    gracePeriodExpiresAt: graceEnd,
    now,
  }), false);
  const upgraded = decideEntitlement({
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: "calonavi_plus_monthly",
    environment: "Production",
    originalTransactionId: "same-group",
    transactionId: "tx-month",
    boundUserId: user,
    expiresDate: future,
    revocationDate: null,
    upgraded: true,
    now,
  });
  assertEquals(upgraded.ok && upgraded.row.status, "expired");
});

Deno.test("rejection reasons are logged and the JWS is not", async () => {
  const logs: Array<{ code: string; reason: string }> = [];
  const secret = "jws-secret-do-not-log";
  const { deps } = harness({
    verify: () => Promise.resolve(verified({ bundleId: "com.example.other" })),
  });
  deps.log = (entry) => logs.push(entry);
  const response = await handleVerifyStoreTransaction(
    post({ signedTransaction: `aaa.${secret}.bbb` }),
    deps,
  );
  assertEquals(response.status, 400);
  assertEquals(logs, [{ code: "invalid_transaction", reason: "bundle_mismatch" }]);
  assertEquals(JSON.stringify(logs).includes(secret), false);
});

Deno.test("a skipped older renewal keeps the later active period in the response", async () => {
  const keptUntil = "2026-12-08T00:00:00.000Z";
  const { deps, writes } = harness({
    verify: () => Promise.resolve(verified({ expiresDate: Date.parse("2026-10-20T00:00:00Z") })),
    current: () => Promise.resolve({
      expiresAt: keptUntil,
      status: "active",
      transactionId: "tx-later",
    }),
  });
  const response = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(writes, []);
  assertEquals(body.ok, true);
  assertEquals(body.plus, true);
  assertEquals(body.expiresAt, keptUntil);
  assertEquals(build11ClientAccepts(response.status, body), true);
});

Deno.test("error bodies stay ok false and a code, with no plus field", async () => {
  const bound = harness({ bound: { "1000001": other } });
  const conflict = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), bound.deps);
  assertEquals(conflict.status, 409);
  assertEquals(await conflict.json(), { ok: false, code: "bound_to_other_user" });

  const missing = harness({ userId: null });
  const unsigned = await handleVerifyStoreTransaction(post({ signedTransaction: jws }), missing.deps);
  assertEquals(unsigned.status, 401);
  assertEquals(await unsigned.json(), { ok: false, code: "unauthenticated" });
});

function build11ClientAccepts(
  status: number,
  body: { ok?: boolean; code?: string },
): boolean {
  // 審査中の build 11 は invoke が成功したことだけを見る。本文の新しい項目は読まない。
  return status === 200 && body.ok === true && body.code == null;
}

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
