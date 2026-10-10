import { Environment } from "npm:@apple/app-store-server-library";
import {
  expectedBundleId,
  signedDataVerifier,
  verifySignedNotification,
} from "../_shared/apple_signed_data.ts";
import {
  decideNotificationEntitlement,
  entitlementNotificationTypes,
  skipsOlderEntitlement,
} from "../_shared/store_entitlement.ts";
import {
  boundStoreUser,
  insertFailedNotification,
  insertNotification,
  matchStoreUser,
  notificationExists,
  rememberOriginalTransaction,
  readPlusEntitlement,
  upsertPlusEntitlement,
} from "../_shared/store_live.ts";
import { handleAppStoreNotification, type DecodedStoreNotification } from "./handler.ts";

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

Deno.serve((request) =>
  handleAppStoreNotification(request, {
    verify: async (signedPayload) => {
      const { decoded, environment: verifiedEnvironment } = await verifySignedNotification(
        signedPayload,
      );
      const data = decoded.data ?? {};
      const environment = data.environment === "Sandbox"
        ? Environment.SANDBOX
        : data.environment === "Production"
        ? Environment.PRODUCTION
        : verifiedEnvironment;
      const environmentName = environment === Environment.SANDBOX ? "Sandbox" : "Production";
      let transaction: Record<string, unknown> = {};
      let renewal: Record<string, unknown> = {};
      if (data.signedTransactionInfo) {
        transaction = await signedDataVerifier(environment).verifyAndDecodeTransaction(
          data.signedTransactionInfo,
        ) as Record<string, unknown>;
      }
      if (data.signedRenewalInfo) {
        renewal = await signedDataVerifier(environment).verifyAndDecodeRenewalInfo(
          data.signedRenewalInfo,
        ) as Record<string, unknown>;
      }
      const bundleId = stringOrNull(transaction.bundleId) ?? stringOrNull(data.bundleId);
      const transactionEnvironment = stringOrNull(transaction.environment) ?? environmentName;
      return {
        notificationUUID: decoded.notificationUUID ?? "",
        notificationType: decoded.notificationType ?? "",
        subtype: decoded.subtype ?? null,
        appAccountToken: stringOrNull(transaction.appAccountToken),
        originalTransactionId: stringOrNull(transaction.originalTransactionId) ??
          stringOrNull(renewal.originalTransactionId),
        transactionId: stringOrNull(transaction.transactionId),
        productId: stringOrNull(transaction.productId) ?? stringOrNull(renewal.productId),
        bundleId,
        environment: transactionEnvironment,
        expiresDate: numberOrNull(transaction.expiresDate),
        revocationDate: numberOrNull(transaction.revocationDate),
        revocationReason: numberOrNull(transaction.revocationReason),
        gracePeriodExpiresDate: numberOrNull(renewal.gracePeriodExpiresDate),
        signedDate: numberOrNull(decoded.signedDate),
        offerType: numberOrNull(transaction.offerType),
        offerDiscountType: stringOrNull(transaction.offerDiscountType),
        autoRenewStatus: numberOrNull(renewal.autoRenewStatus),
        signedPayload,
        decoded: decoded as unknown as Record<string, unknown>,
      } satisfies DecodedStoreNotification;
    },
    exists: (notificationUuid) => notificationExists(notificationUuid),
    matchUser: (decoded) => matchStoreUser({
      appAccountToken: decoded.appAccountToken,
      originalTransactionId: decoded.originalTransactionId,
      productId: decoded.productId,
    }),
    applyEntitlement: async (input) => {
      const notificationType = input.notificationType;
      if (!input.productId || !input.originalTransactionId || !input.bundleId || !input.environment) {
        if (entitlementNotificationTypes.has(notificationType)) {
          throw new Error("incomplete transaction");
        }
        return;
      }
      const now = new Date();
      const decision = decideNotificationEntitlement({
        notificationType,
        subtype: input.subtype,
        userId: input.userId,
        expectedBundleId: expectedBundleId(),
        bundleId: input.bundleId,
        productId: input.productId,
        environment: input.environment,
        originalTransactionId: input.originalTransactionId,
        boundUserId: await boundStoreUser(input.originalTransactionId),
        expiresDate: input.expiresDate,
        revocationDate: input.revocationDate,
        gracePeriodExpiresDate: input.gracePeriodExpiresDate,
        now,
      });
      if (!decision.ok) {
        if (decision.code === "bound_to_other_user") {
          return;
        }
        throw new Error(decision.code);
      }
      await rememberOriginalTransaction(
        input.originalTransactionId,
        input.userId,
        input.productId,
      );
      const stored = await readPlusEntitlement(input.userId, input.productId);
      const revoked = input.revocationDate != null ||
        notificationType === "REFUND" ||
        notificationType === "REVOKE";
      if (skipsOlderEntitlement({
        notificationType,
        subtype: input.subtype,
        revoked,
        currentExpiresAt: stored?.expiresAt ?? null,
        nextExpiresAt: decision.row.expires_at,
        transactionExpiresAt: input.expiresDate,
        gracePeriodExpiresAt: input.gracePeriodExpiresDate,
        now,
      })) {
        return;
      }
      await upsertPlusEntitlement(decision.row);
    },
    insert: (row) => insertNotification(row),
    insertFailed: (signedPayload) => insertFailedNotification(signedPayload),
  })
);
