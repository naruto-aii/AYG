import { verifySignedTransaction } from "../_shared/apple_signed_data.ts";
import {
  boundStoreUser,
  rememberOriginalTransaction,
  upsertPlusEntitlement,
} from "../_shared/store_live.ts";
import { handleVerifyStoreTransaction, type VerifiedTransaction } from "./handler.ts";

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

function verifiedFromApple(payload: Record<string, unknown>): VerifiedTransaction {
  return {
    bundleId: typeof payload.bundleId === "string" ? payload.bundleId : "",
    productId: typeof payload.productId === "string" ? payload.productId : "",
    environment: typeof payload.environment === "string" ? payload.environment : "",
    originalTransactionId: typeof payload.originalTransactionId === "string"
      ? payload.originalTransactionId
      : "",
    expiresDate: numberOrNull(payload.expiresDate),
    revocationDate: numberOrNull(payload.revocationDate),
  };
}

async function userId(req: Request): Promise<string | null> {
  const header = req.headers.get("Authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!base || !anon) {
    return null;
  }
  const response = await fetch(`${base}/auth/v1/user`, {
    headers: { Authorization: header, apikey: anon },
  });
  if (!response.ok) {
    return null;
  }
  const body = await response.json();
  const id = body && typeof body === "object" ? (body as { id?: unknown }).id : null;
  return typeof id === "string" && id.length > 0 ? id : null;
}

Deno.serve((req) =>
  handleVerifyStoreTransaction(req, {
    userId,
    now: () => new Date(),
    expectedBundleId: Deno.env.get("APP_BUNDLE_ID") ?? "",
    verify: async (jws) => verifiedFromApple(await verifySignedTransaction(jws)),
    boundUser: (originalTransactionId) => boundStoreUser(originalTransactionId),
    bind: (originalTransactionId, owner, productId) =>
      rememberOriginalTransaction(originalTransactionId, owner, productId),
    write: (row) => upsertPlusEntitlement(row),
  })
);
