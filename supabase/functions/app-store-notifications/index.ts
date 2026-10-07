import { Environment, SignedDataVerifier } from "npm:@apple/app-store-server-library";
import {
  insertFailedNotification,
  insertNotification,
  matchStoreUser,
  notificationExists,
} from "../_shared/store_live.ts";
import { handleAppStoreNotification, type DecodedStoreNotification } from "./handler.ts";

const bundleId = Deno.env.get("APP_BUNDLE_ID") ?? "";
const appAppleId = Number(Deno.env.get("ASC_APP_APPLE_ID") ?? "0");

function roots(): Uint8Array[] {
  const root = Deno.env.get("APPLE_ROOT_CA_BASE64") ?? Deno.env.get("APPLE_ROOT_CA") ?? "";
  if (!root) {
    return [];
  }
  return [Uint8Array.from(atob(root), (char) => char.charCodeAt(0))];
}

function verifier(environment: Environment) {
  return new SignedDataVerifier(roots(), true, environment, bundleId, appAppleId);
}

Deno.serve((request) =>
  handleAppStoreNotification(request, {
    verify: async (signedPayload) => {
      let decoded: Awaited<ReturnType<SignedDataVerifier["verifyAndDecodeNotification"]>> | null = null;
      let lastError: unknown;
      for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
        try {
          decoded = await verifier(environment).verifyAndDecodeNotification(signedPayload);
          break;
        } catch (error) {
          lastError = error;
        }
      }
      if (!decoded) {
        throw lastError ?? new Error("verification failed");
      }
      const data = decoded.data ?? {};
      let transaction: Record<string, unknown> = {};
      if (data.signedTransactionInfo) {
        const environment = data.environment === "Sandbox"
          ? Environment.SANDBOX
          : Environment.PRODUCTION;
        transaction = await verifier(environment).verifyAndDecodeTransaction(
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
        signedPayload,
        decoded: decoded as unknown as Record<string, unknown>,
      } satisfies DecodedStoreNotification;
    },
    exists: (notificationUuid) => notificationExists(notificationUuid),
    matchUser: (decoded) => matchStoreUser(decoded),
    insert: (row) => insertNotification(row),
    insertFailed: (signedPayload) => insertFailedNotification(signedPayload),
  })
);
