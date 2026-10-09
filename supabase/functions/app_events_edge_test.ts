import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleAppStoreNotification } from "./app-store-notifications/handler.ts";
import { importAnalytics } from "./store-analytics-import/import.ts";
import { importSales } from "./store-sales-import/import.ts";

Deno.test("broken notification chain is stored as failed and returns 400", async () => {
  const failed: string[] = [];
  const response = await handleAppStoreNotification(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ signedPayload: "broken" }),
    }),
    {
      verify: () => Promise.reject(new Error("bad chain")),
      exists: () => Promise.resolve(false),
      matchUser: () => Promise.resolve({ userId: null, deleted: false }),
      insert: () => Promise.resolve(),
      insertFailed: (payload) => {
        failed.push(payload);
        return Promise.resolve();
      },
    },
  );
  assertEquals(response.status, 400);
  assertEquals(failed, ["broken"]);
});

Deno.test("the same notification is stored once", async () => {
  const rows: Record<string, unknown>[] = [];
  const deps = {
    verify: () => Promise.resolve({
      notificationUUID: "uuid-1",
      notificationType: "SUBSCRIBED",
      appAccountToken: "11111111-1111-4111-8111-111111111111",
      originalTransactionId: "100",
      productId: "ayg.plus.monthly",
      signedPayload: "signed",
      decoded: { ok: true },
    }),
    exists: () => Promise.resolve(rows.length > 0),
    matchUser: () => Promise.resolve({
      userId: "11111111-1111-4111-8111-111111111111",
      deleted: false,
    }),
    insert: (row: Record<string, unknown>) => {
      rows.push(row);
      return Promise.resolve();
    },
    insertFailed: () => Promise.resolve(),
  };
  const first = await handleAppStoreNotification(post("signed"), deps);
  const second = await handleAppStoreNotification(post("signed"), deps);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].user_id, "11111111-1111-4111-8111-111111111111");
});

Deno.test("a deleted user drops identifiers and payloads", async () => {
  const rows: Record<string, unknown>[] = [];
  const response = await handleAppStoreNotification(post("signed"), {
    verify: () => Promise.resolve({
      notificationUUID: "uuid-2",
      notificationType: "EXPIRED",
      appAccountToken: "gone",
      originalTransactionId: "200",
      signedPayload: "signed",
      decoded: { secret: true },
    }),
    exists: () => Promise.resolve(false),
    matchUser: () => Promise.resolve({ userId: null, deleted: true }),
    insert: (row) => {
      rows.push(row);
      return Promise.resolve();
    },
    insertFailed: () => Promise.resolve(),
  });
  assertEquals(response.status, 200);
  assertEquals(rows[0].user_id, null);
  assertEquals(rows[0].signed_payload, null);
  assertEquals(rows[0].decoded_payload, null);
  assertEquals(rows[0].original_transaction_id, null);
});

Deno.test("a renewal updates the entitlement before the notification is stored", async () => {
  const applied: Array<Record<string, unknown>> = [];
  const rows: Record<string, unknown>[] = [];
  const response = await handleAppStoreNotification(post("signed"), {
    verify: () => Promise.resolve({
      notificationUUID: "uuid-renew",
      notificationType: "DID_RENEW",
      originalTransactionId: "300",
      productId: "calonavi_plus_monthly",
      bundleId: "com.narutoaii.ayg",
      environment: "Sandbox",
      expiresDate: Date.parse("2026-12-01T00:00:00Z"),
      revocationDate: null,
      signedPayload: "signed",
      decoded: {},
    }),
    exists: () => Promise.resolve(false),
    matchUser: () => Promise.resolve({
      userId: "11111111-1111-4111-8111-111111111111",
      deleted: false,
    }),
    applyEntitlement: (input) => {
      applied.push(input);
      return Promise.resolve();
    },
    insert: (row) => {
      rows.push(row);
      return Promise.resolve();
    },
    insertFailed: () => Promise.resolve(),
  });
  assertEquals(response.status, 200);
  assertEquals(applied.length, 1);
  assertEquals(applied[0].environment, "Sandbox");
  assertEquals(applied[0].expiresDate, Date.parse("2026-12-01T00:00:00Z"));
  assertEquals(rows.length, 1);
});

Deno.test("an entitlement write failure is retried and does not store the notification", async () => {
  const rows: Record<string, unknown>[] = [];
  const response = await handleAppStoreNotification(post("signed"), {
    verify: () => Promise.resolve({
      notificationUUID: "uuid-retry",
      notificationType: "DID_RENEW",
      signedPayload: "signed",
      decoded: {},
    }),
    exists: () => Promise.resolve(false),
    matchUser: () => Promise.resolve({ userId: "user", deleted: false }),
    applyEntitlement: () => Promise.reject(new Error("db")),
    insert: (row) => {
      rows.push(row);
      return Promise.resolve();
    },
    insertFailed: () => Promise.resolve(),
  });
  assertEquals(response.status, 500);
  assertEquals(rows, []);
});

Deno.test("a save failure returns 500 so Apple retries", async () => {
  const response = await handleAppStoreNotification(post("signed"), {
    verify: () => Promise.resolve({
      notificationUUID: "uuid-3",
      notificationType: "SUBSCRIBED",
      signedPayload: "signed",
      decoded: {},
    }),
    exists: () => Promise.resolve(false),
    matchUser: () => Promise.resolve({ userId: "user", deleted: false }),
    insert: () => Promise.reject(new Error("db")),
    insertFailed: () => Promise.resolve(),
  });
  assertEquals(response.status, 500);
});

Deno.test("analytics import resumes after the time budget and skips a second pass", async () => {
  const imported = new Set<string>();
  let clock = 0;
  const segments = ["a", "b", "c"].map((id) => ({
    id,
    url: id,
    checksum: id,
  }));
  const deps = {
    now: () => clock,
    budgetMs: 100,
    listRequests: () => Promise.resolve([{ id: "req", stoppedDueToInactivity: false }]),
    listReports: () => Promise.resolve([{ id: "report" }]),
    listInstances: () => Promise.resolve([{ id: "instance" }]),
    listSegments: () => Promise.resolve(segments),
    alreadyImported: (checksum: string) => Promise.resolve(imported.has(checksum)),
    download: (segment: { checksum: string }) => {
      clock += 60;
      return Promise.resolve([{ Date: "2026-10-07", Units: segment.checksum }]);
    },
    insertRows: () => Promise.resolve(),
    markImported: (segment: { checksum: string }) => {
      imported.add(segment.checksum);
      return Promise.resolve();
    },
    startRun: () => Promise.resolve("run"),
    finishRun: () => Promise.resolve(),
  };
  const first = await importAnalytics(deps);
  assertEquals(first.status, "partial");
  assertEquals(imported.size < 9, true);
  clock = 0;
  const second = await importAnalytics({ ...deps, budgetMs: 10_000, now: () => 0 });
  assertEquals(second.status, "success");
  const third = await importAnalytics({ ...deps, budgetMs: 10_000, now: () => 0 });
  assertEquals(third.inserted, 0);
});

Deno.test("inactivity fails the analytics run", async () => {
  let status = "";
  const result = await importAnalytics({
    now: () => 0,
    budgetMs: 1000,
    listRequests: () => Promise.resolve([{ id: "req", stoppedDueToInactivity: true }]),
    listReports: () => Promise.resolve([]),
    listInstances: () => Promise.resolve([]),
    listSegments: () => Promise.resolve([]),
    alreadyImported: () => Promise.resolve(false),
    download: () => Promise.resolve([]),
    insertRows: () => Promise.resolve(),
    markImported: () => Promise.resolve(),
    startRun: () => Promise.resolve("run"),
    finishRun: (_run, next) => {
      status = next;
      return Promise.resolve();
    },
  });
  assertEquals(result.status, "failed");
  assertEquals(status, "failed");
});

Deno.test("a missing sales file is checked again next time", async () => {
  const marks = new Map<string, string>();
  let fetches = 0;
  const deps = {
    dates: () => ["2026-10-07"],
    fetchReport: () => {
      fetches += 1;
      return Promise.resolve({ status: 404, rows: [] });
    },
    alreadyImported: (key: string) => Promise.resolve(marks.get(key) === "imported"),
    mark: (key: string, status: string) => {
      marks.set(key, status);
      return Promise.resolve();
    },
    insertRows: () => Promise.resolve(),
  };
  const first = await importSales(deps);
  assertEquals(first.notAvailable > 0, true);
  const second = await importSales(deps);
  assertEquals(second.notAvailable, first.notAvailable);
  assertEquals(fetches > first.notAvailable, true);
});

function post(signedPayload: string): Request {
  return new Request("https://example.test", {
    method: "POST",
    body: JSON.stringify({ signedPayload }),
  });
}
