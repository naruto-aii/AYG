import { Environment } from "npm:@apple/app-store-server-library";
import {
  signedDataVerifier,
  verifySignedNotification,
} from "../_shared/apple_signed_data.ts";
import { decideEntitlement } from "../_shared/store_entitlement.ts";
import {
  boundStoreUser,
  insertFailedNotification,
  insertNotification,
  matchStoreUser,
  notificationExists,
  rememberOriginalTransaction,
  upsertPlusEntitlement,
} from "../_shared/store_live.ts";
import { handleAppStoreNotification, type DecodedStoreNotification } from "./handler.ts";

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

Deno.serve((request) =>
  handleAppStoreNotification(request, {
    verify: async (signedPayload) => {
      const { decoded } = await verifySignedNotification(signedPayload);
      const data = decoded.data ?? {};
      let transaction: Record<string, unknown> = {};
      if (data.signedTransactionInfo) {
        const environment = data.environment === "Sandbox"
          ? Environment.SANDBOX
          : Environment.PRODUCTION;
        transaction = await signedDataVerifier(environment).verifyAndDecodeTransaction(
          data.signedTransactionInfo,
        ) as Record<string, unknown>;
      }
      return {
        notificationUUID: decoded.notificationUUID ?? "",
        notificationType: decoded.notificationType ?? "",
        subtype: decoded.subtype ?? null,
        appAccountToken: (transaction.appAccountToken as string | undefined) ?? null,
        originalTransactionId: (transaction.originalTransactionId as string | undefined) ?? null,
        productId: (transaction.productId as string | undefined) ?? null,
        bundleId: typeof transaction.bundleId === "string" ? transaction.bundleId : null,
        environment: typeof transaction.environment === "string" ? transaction.environment : null,
        expiresDate: numberOrNull(transaction.expiresDate),
        revocationDate: numberOrNull(transaction.revocationDate),
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
      if (!input.productId || !input.originalTransactionId || !input.bundleId || !input.environment) {
        return;
      }
      const decision = decideEntitlement({
        userId: input.userId,
        expectedBundleId: Deno.env.get("APP_BUNDLE_ID") ?? "",
        bundleId: input.bundleId,
        productId: input.productId,
        environment: input.environment,
        originalTransactionId: input.originalTransactionId,
        boundUserId: await boundStoreUser(input.originalTransactionId),
        expiresDate: input.expiresDate,
        revocationDate: input.revocationDate,
        now: new Date(),
      });
      if (!decision.ok) {
        return;
      }
      await rememberOriginalTransaction(
        input.originalTransactionId,
        input.userId,
        input.productId,
      );
      await upsertPlusEntitlement(decision.row);
    },
    insert: (row) => insertNotification(row),
    insertFailed: (signedPayload) => insertFailedNotification(signedPayload),
  })
);
