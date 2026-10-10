import { Buffer } from "node:buffer";
import { Environment, SignedDataVerifier } from "npm:@apple/app-store-server-library";
import { appleIncRoot, appleRootCaG2, appleRootCaG3 } from "./apple_root_cas.ts";

/// カロナビの公開の値。秘密ではない。環境変数が空のときはこれを使う。
export const calonaviBundleId = "com.narutoaii.ayg";
export const calonaviAppAppleId = 6814054275;

/// 本番は失効確認をオンのままにする。テストだけ `false` にして、Apple の OCSP を呼ばない。
export function appleSignedDataOnlineChecks(): boolean {
  const raw = Deno.env.get("APPLE_SIGNED_DATA_ONLINE_CHECKS");
  if (raw == null || raw.trim() === "") {
    return true;
  }
  return raw.trim().toLowerCase() !== "false";
}

const bundledRootCertificates = [appleRootCaG3, appleRootCaG2, appleIncRoot];

export function storeVerificationEnvironments(): Environment[] {
  return [Environment.PRODUCTION, Environment.SANDBOX];
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

export function expectedAppAppleId(): number {
  const raw = Deno.env.get("ASC_APP_APPLE_ID")?.trim() ?? "";
  const parsed = Number(raw || String(calonaviAppAppleId));
  return Number.isFinite(parsed) ? parsed : calonaviAppAppleId;
}

export function signedDataVerifier(environment: Environment): SignedDataVerifier {
  return new SignedDataVerifier(
    appleRootCertificates(),
    appleSignedDataOnlineChecks(),
    environment,
    expectedBundleId(),
    expectedAppAppleId(),
  );
}

/// 審査と TestFlight は Sandbox、店頭の購入は Production。どちらも Apple の署名が通れば受ける。
export async function verifySignedTransaction(jws: string): Promise<Record<string, unknown>> {
  let lastError: unknown;
  for (const environment of storeVerificationEnvironments()) {
    try {
      return await signedDataVerifier(environment).verifyAndDecodeTransaction(jws) as Record<
        string,
        unknown
      >;
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("verification failed");
}

export async function verifySignedNotification(signedPayload: string) {
  let lastError: unknown;
  for (const environment of storeVerificationEnvironments()) {
    try {
      const decoded = await signedDataVerifier(environment).verifyAndDecodeNotification(
        signedPayload,
      );
      return { decoded, environment };
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("verification failed");
}
