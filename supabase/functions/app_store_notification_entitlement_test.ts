import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Environment } from "npm:@apple/app-store-server-library";
import { handleAppStoreNotification } from "./app-store-notifications/handler.ts";
import {
  appleRootCertificates,
  calonaviAppAppleId,
  calonaviBundleId,
  expectedAppAppleId,
  expectedBundleId,
  storeVerificationEnvironments,
  verifySignedNotification,
} from "./_shared/apple_signed_data.ts";
import {
  decideNotificationEntitlement,
  type EntitlementRow,
  notificationSkipsOlderExpiry,
} from "./_shared/store_entitlement.ts";
import { chooseStoreUser } from "./_shared/store_live.ts";

const user = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
const bundle = calonaviBundleId;
const now = new Date("2026-10-08T00:00:00Z");
const trialEnd = Date.parse("2026-10-11T00:00:00Z");
const paidEnd = Date.parse("2026-11-08T00:00:00Z");
const graceEnd = Date.parse("2026-10-24T00:00:00Z");

type Fixture = {
  notificationType: string;
  subtype?: string | null;
  expiresDate?: number | null;
  revocationDate?: number | null;
  gracePeriodExpiresDate?: number | null;
  offerType?: number | null;
  offerDiscountType?: string | null;
  environment?: string;
  productId?: string;
};

function decide(fixture: Fixture) {
  return decideNotificationEntitlement({
    notificationType: fixture.notificationType,
    subtype: fixture.subtype ?? null,
    userId: user,
    expectedBundleId: bundle,
    bundleId: bundle,
    productId: fixture.productId ?? "calonavi_plus_monthly",
    environment: fixture.environment ?? "Production",
    originalTransactionId: "1000000123",
    boundUserId: user,
    expiresDate: fixture.expiresDate ?? paidEnd,
    revocationDate: fixture.revocationDate ?? null,
    gracePeriodExpiresDate: fixture.gracePeriodExpiresDate ?? null,
    now,
  });
}

function row(fixture: Fixture): EntitlementRow {
  const decision = decide(fixture);
  if (!decision.ok) {
    throw new Error(decision.code);
  }
  return decision.row;
}

Deno.test("signed notifications trust the Apple root chain for this bundle", () => {
  const roots = appleRootCertificates();
  assertEquals(roots.length >= 3, true);
  assertEquals(roots.every((cert) => cert[0] === 0x30), true);
  const configuredBundle = Deno.env.get("APP_BUNDLE_ID")?.trim() ?? "";
  const configuredApp = Deno.env.get("ASC_APP_APPLE_ID")?.trim() ?? "";
  assertEquals(expectedBundleId(), configuredBundle || calonaviBundleId);
  assertEquals(
    expectedAppAppleId(),
    configuredApp ? Number(configuredApp) : calonaviAppAppleId,
  );
  assertEquals(storeVerificationEnvironments(), [
    Environment.PRODUCTION,
    Environment.SANDBOX,
  ]);
});

Deno.test("a payload that is not signed by Apple is rejected", async () => {
  await assertRejects(() => verifySignedNotification("not-a-jws"));
  await assertRejects(
    () => verifySignedNotification("eyJhbGciOiJFUzI1NiJ9.eyJub3RpZmljYXRpb25VVUlEIjoidCJ9.c2ln"),
  );
});

Deno.test("fixtures keep a renewing subscriber on Plus, including after the free trial", () => {
  const trial = row({
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    expiresDate: trialEnd,
    offerType: 1,
    offerDiscountType: "FREE_TRIAL",
    environment: "Sandbox",
  });
  assertEquals(trial.status, "active");
  assertEquals(trial.expires_at, "2026-10-11T00:00:00.000Z");

  const renewed = row({
    notificationType: "DID_RENEW",
    expiresDate: paidEnd,
    offerType: null,
    environment: "Production",
    productId: "calonavi_plus_yearly",
  });
  assertEquals(renewed.status, "active");
  assertEquals(renewed.product_id, "calonavi_plus_yearly");
  assertEquals(renewed.expires_at, "2026-11-08T00:00:00.000Z");
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "DID_RENEW",
    revoked: false,
    currentExpiresAt: trial.expires_at,
    nextExpiresAt: renewed.expires_at,
  }), false);

  const half = row({
    notificationType: "DID_RENEW",
    productId: "calonavi_plus_half_year",
    expiresDate: paidEnd,
  });
  assertEquals(half.status, "active");
});

Deno.test("fixtures for expiry, billing failure, refund, revoke, and renewal status", () => {
  assertEquals(row({
    notificationType: "EXPIRED",
    subtype: "VOLUNTARY",
    expiresDate: Date.parse("2026-10-07T00:00:00Z"),
  }).status, "expired");
  assertEquals(row({
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    expiresDate: Date.parse("2026-10-07T00:00:00Z"),
    gracePeriodExpiresDate: graceEnd,
  }).status, "active");
  assertEquals(row({
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    expiresDate: Date.parse("2026-10-07T00:00:00Z"),
    gracePeriodExpiresDate: graceEnd,
  }).expires_at, "2026-10-24T00:00:00.000Z");
  assertEquals(row({
    notificationType: "DID_FAIL_TO_RENEW",
    expiresDate: Date.parse("2026-10-07T00:00:00Z"),
  }).status, "expired");
  assertEquals(row({
    notificationType: "DID_FAIL_TO_RENEW",
    expiresDate: paidEnd,
  }).status, "active");
  assertEquals(row({
    notificationType: "GRACE_PERIOD_EXPIRED",
    expiresDate: Date.parse("2026-10-01T00:00:00Z"),
    gracePeriodExpiresDate: Date.parse("2026-10-07T00:00:00Z"),
  }).status, "expired");
  assertEquals(row({
    notificationType: "GRACE_PERIOD_EXPIRED",
    expiresDate: Date.parse("2026-10-01T00:00:00Z"),
    gracePeriodExpiresDate: Date.parse("2026-10-07T00:00:00Z"),
  }).expires_at, "2026-10-07T00:00:00.000Z");
  assertEquals(row({
    notificationType: "REFUND",
    expiresDate: paidEnd,
    revocationDate: Date.parse("2026-10-09T00:00:00Z"),
  }).status, "inactive");
  assertEquals(row({
    notificationType: "REVOKE",
    expiresDate: paidEnd,
  }).status, "inactive");
  assertEquals(row({
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    expiresDate: paidEnd,
  }).status, "active");
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "EXPIRED",
    revoked: false,
    currentExpiresAt: "2026-12-01T00:00:00.000Z",
    nextExpiresAt: "2026-10-08T00:00:00.000Z",
  }), true);
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "GRACE_PERIOD_EXPIRED",
    revoked: false,
    currentExpiresAt: "2026-12-01T00:00:00.000Z",
    nextExpiresAt: "2026-10-07T00:00:00.000Z",
  }), true);
  assertEquals(notificationSkipsOlderExpiry({
    notificationType: "REFUND",
    revoked: true,
    currentExpiresAt: "2026-12-01T00:00:00.000Z",
    nextExpiresAt: "2026-10-08T00:00:00.000Z",
  }), false);
  assertEquals(decide({
    notificationType: "DID_RENEW",
    environment: "Local",
  }).ok, false);
});

Deno.test("the original purchase row wins over appAccountToken", () => {
  const mapped = chooseStoreUser({
    originalUserId: user,
    originalExists: true,
    originalDeleted: false,
    appAccountToken: other,
    tokenExists: true,
    tokenDeleted: false,
  });
  assertEquals(mapped, {
    userId: user,
    deleted: false,
    source: "original_transaction",
  });

  const fromToken = chooseStoreUser({
    originalUserId: null,
    originalExists: false,
    originalDeleted: false,
    appAccountToken: other.toUpperCase(),
    tokenExists: true,
    tokenDeleted: false,
  });
  assertEquals(fromToken.userId, other);
  assertEquals(fromToken.source, "app_account_token");

  const closed = chooseStoreUser({
    originalUserId: user,
    originalExists: true,
    originalDeleted: true,
    appAccountToken: other,
    tokenExists: true,
    tokenDeleted: false,
  });
  assertEquals(closed.deleted, true);
  assertEquals(closed.userId, null);

  const unknownToken = chooseStoreUser({
    originalUserId: null,
    originalExists: false,
    originalDeleted: false,
    appAccountToken: "33333333-3333-4333-8333-333333333333",
    tokenExists: false,
    tokenDeleted: true,
  });
  assertEquals(unknownToken.userId, null);
  assertEquals(unknownToken.deleted, false);
  assertEquals(unknownToken.source, "none");
});

Deno.test("a duplicate notification does not apply the entitlement again", async () => {
  let applies = 0;
  const rows: Record<string, unknown>[] = [];
  const deps = {
    verify: () => Promise.resolve({
      notificationUUID: "33333333-3333-4333-8333-333333333333",
      notificationType: "DID_RENEW",
      subtype: null,
      appAccountToken: user,
      originalTransactionId: "1000000123",
      productId: "calonavi_plus_monthly",
      bundleId: bundle,
      environment: "Sandbox",
      expiresDate: paidEnd,
      revocationDate: null,
      offerType: null,
      offerDiscountType: null,
      signedPayload: "signed",
      decoded: { notificationType: "DID_RENEW" },
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
    new Request("https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications", {
      method: "POST",
      body,
    }),
    deps,
  );
  const second = await handleAppStoreNotification(
    new Request("https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications", {
      method: "POST",
      body,
    }),
    deps,
  );
  assertEquals(first.status, 200);
  assertEquals(await second.text(), "duplicate");
  assertEquals(applies, 1);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].environment, "Sandbox");
  assertEquals(rows[0].bundle_id, bundle);
  assertEquals(rows[0].user_id, user);
});

Deno.test("the wrong bundle does not become an entitlement write", () => {
  const decision = decideNotificationEntitlement({
    notificationType: "DID_RENEW",
    userId: user,
    expectedBundleId: bundle,
    bundleId: "com.example.other",
    productId: "calonavi_plus_monthly",
    environment: "Production",
    originalTransactionId: "1000000123",
    boundUserId: null,
    expiresDate: paidEnd,
    revocationDate: null,
    now,
  });
  assertEquals(decision.ok, false);
});
