import { Buffer } from "node:buffer";
import { appleIncRoot, appleRootCaG2, appleRootCaG3 } from "./apple_root_cas.ts";
import {
  EdgeSignedDataVerifier,
  type SignedPayload,
  VerificationStatus,
} from "./apple_webcrypto_jws.ts";

/// カロナビの公開の値。秘密ではない。環境変数が空のときはこれを使う。
export const calonaviBundleId = "com.narutoaii.ayg";
export const calonaviAppAppleId = 6814054275;

/// 未設定か true なら、証明書の期限は今の時刻で見る。`false` はテスト専用で、signedDate を使う。
/// OCSP は Edge Runtime で Node の crypto が動かないため呼ばない。
export function appleSignedDataOnlineChecks(): boolean {
  const raw = Deno.env.get("APPLE_SIGNED_DATA_ONLINE_CHECKS");
  if (raw == null || raw.trim() === "") {
    return true;
  }
  return raw.trim().toLowerCase() !== "false";
}

const bundledRootCertificates = [appleRootCaG3, appleRootCaG2, appleIncRoot];
const failureMessageLimit = 180;

export const StoreEnvironment = {
  PRODUCTION: "Production",
  SANDBOX: "Sandbox",
} as const;

export function storeVerificationEnvironments(): string[] {
  return [StoreEnvironment.PRODUCTION, StoreEnvironment.SANDBOX];
}

function derFromBase64(value: string): Buffer | null {
  const trimmed = value.replace(/\s+/g, "");
  if (!trimmed) {
    return null;
  }
  let raw: Uint8Array;
  try {
    raw = Uint8Array.from(atob(trimmed), (char) => char.charCodeAt(0));
  } catch {
    return null;
  }
  if (raw.byteLength < 2 || raw[0] !== 0x30) {
    return null;
  }
  const copy = new ArrayBuffer(raw.byteLength);
  new Uint8Array(copy).set(raw);
  return Buffer.from(copy);
}

/// 同梱の Apple ルートに、APPLE_ROOT_CA_BASE64（DER の Base64。カンマ区切り可）を足す。
export function appleRootCertificates(): Buffer[] {
  const extra = Deno.env.get("APPLE_ROOT_CA_BASE64") ?? Deno.env.get("APPLE_ROOT_CA") ?? "";
  const certs = bundledRootCertificates
    .map((value) => derFromBase64(value))
    .filter((value): value is Buffer => value != null);
  for (const piece of extra.split(",")) {
    const cert = derFromBase64(piece);
    if (cert) {
      certs.push(cert);
    }
  }
  return certs;
}

export function expectedBundleId(): string {
  const value = Deno.env.get("APP_BUNDLE_ID")?.trim() ?? "";
  return value || calonaviBundleId;
}

/// ログに出すのは真偽だけ。設定値そのものは出さない。
export function appBundleIdFlags(): { set: boolean; matches: boolean } {
  const value = Deno.env.get("APP_BUNDLE_ID")?.trim() ?? "";
  return {
    set: value.length > 0,
    matches: value === calonaviBundleId,
  };
}

export function expectedAppAppleId(): number {
  const raw = Deno.env.get("ASC_APP_APPLE_ID")?.trim() ?? "";
  const parsed = Number(raw || String(calonaviAppAppleId));
  return Number.isFinite(parsed) ? parsed : calonaviAppAppleId;
}

export function signedDataVerifier(environment: string): EdgeSignedDataVerifier {
  return new EdgeSignedDataVerifier(
    appleRootCertificates(),
    appleSignedDataOnlineChecks(),
    environment,
    expectedBundleId(),
    expectedAppAppleId(),
  );
}

export type AppleVerifyFailure = {
  status: string;
  cause: string;
  message: string;
};

function verificationStatus(error: unknown): number | null {
  if (!error || typeof error !== "object" || !("status" in error)) {
    return null;
  }
  const status = (error as { status?: unknown }).status;
  return typeof status === "number" ? status : null;
}

function causeError(error: unknown): Error | null {
  if (error && typeof error === "object" && "cause" in error) {
    const inner = (error as { cause?: unknown }).cause;
    if (inner instanceof Error) {
      return inner;
    }
  }
  if (error instanceof Error && verificationStatus(error) == null) {
    return error;
  }
  return null;
}

function clipFailureMessage(value: string): string {
  let text = value.replace(
    /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
    "[jws]",
  );
  const configured = Deno.env.get("APP_BUNDLE_ID")?.trim() ?? "";
  if (configured && configured !== calonaviBundleId) {
    text = text.split(configured).join("[app-bundle-id]");
  }
  const collapsed = text.replace(/\s+/g, " ").trim();
  if (collapsed.length <= failureMessageLimit) {
    return collapsed;
  }
  return collapsed.slice(0, failureMessageLimit);
}

/// Apple ライブラリの状態名と、原因のエラー名とメッセージ。JWS と鍵は含めない。
export function appleVerifyFailure(error: unknown): AppleVerifyFailure {
  const statusNumber = verificationStatus(error);
  const status = statusNumber == null
    ? "unknown"
    : VerificationStatus[statusNumber] ?? "unknown";
  const cause = causeError(error);
  return {
    status,
    cause: cause?.name || "unknown",
    message: clipFailureMessage(cause?.message ?? ""),
  };
}

function decodeBase64Url(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  return atob(padded + pad);
}

/// 署名が通る前でも、ログ用に bundleId と environment だけを読む。ほかの項目は捨てる。
export function unsignedTransactionClaims(jws: string): {
  bundleId: string | null;
  environment: string | null;
} {
  const payload = jws.split(".")[1] ?? "";
  if (!payload) {
    return { bundleId: null, environment: null };
  }
  try {
    const json = JSON.parse(decodeBase64Url(payload));
    if (!json || typeof json !== "object") {
      return { bundleId: null, environment: null };
    }
    const record = json as { bundleId?: unknown; environment?: unknown };
    return {
      bundleId: typeof record.bundleId === "string" ? record.bundleId.slice(0, 200) : null,
      environment: typeof record.environment === "string" ? record.environment.slice(0, 40) : null,
    };
  } catch {
    return { bundleId: null, environment: null };
  }
}

export type StoreVerifyAttempt = AppleVerifyFailure & { environment: string };

/// Production を先に試し、違えば Sandbox。各環境は1回だけ。
export async function verifyAcrossStoreEnvironments<T>(
  verify: (environment: string) => Promise<T>,
  jws = "",
): Promise<T> {
  const attempts: StoreVerifyAttempt[] = [];
  let lastError: unknown;
  for (const environment of storeVerificationEnvironments()) {
    try {
      return await verify(environment);
    } catch (error) {
      lastError = error;
      attempts.push({ environment: String(environment), ...appleVerifyFailure(error) });
    }
  }
  const bundle = appBundleIdFlags();
  const claims = unsignedTransactionClaims(jws);
  console.error("[apple-signed-data] verify failed", {
    attempts,
    appBundleIdSet: bundle.set,
    appBundleIdMatches: bundle.matches,
    transactionBundleId: claims.bundleId,
    transactionEnvironment: claims.environment,
  });
  throw lastError ?? new Error("verification failed");
}

/// 審査と TestFlight は Sandbox、店頭の購入は Production。どちらも Apple の署名が通れば受ける。
export function verifySignedTransaction(jws: string): Promise<SignedPayload> {
  return verifyAcrossStoreEnvironments(
    (environment) => signedDataVerifier(environment).verifyAndDecodeTransaction(jws),
    jws,
  );
}

export function verifySignedNotification(signedPayload: string) {
  return verifyAcrossStoreEnvironments(async (environment) => {
    const decoded = await signedDataVerifier(environment).verifyAndDecodeNotification(
      signedPayload,
    );
    return { decoded, environment };
  }, signedPayload);
}
