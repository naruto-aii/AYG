import { Environment, SignedDataVerifier } from "npm:@apple/app-store-server-library";

export function appleRootCertificates(): Uint8Array[] {
  const root = Deno.env.get("APPLE_ROOT_CA_BASE64") ?? Deno.env.get("APPLE_ROOT_CA") ?? "";
  if (!root) {
    return [];
  }
  return [Uint8Array.from(atob(root), (char) => char.charCodeAt(0))];
}

export function signedDataVerifier(environment: Environment): SignedDataVerifier {
  const bundleId = Deno.env.get("APP_BUNDLE_ID") ?? "";
  const appAppleId = Number(Deno.env.get("ASC_APP_APPLE_ID") ?? "0");
  return new SignedDataVerifier(
    appleRootCertificates(),
    true,
    environment,
    bundleId,
    appAppleId,
  );
}

/// 審査と TestFlight は Sandbox、店頭の購入は Production。どちらも Apple の署名が通れば受ける。
export async function verifySignedTransaction(jws: string): Promise<Record<string, unknown>> {
  let lastError: unknown;
  for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
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
  for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
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
