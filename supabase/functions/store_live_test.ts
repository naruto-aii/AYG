import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  accountIsClosed,
  analyticsRequestBody,
  recentReportDates,
  signAppleJwt,
  storeOriginalTransactionPath,
} from "./_shared/store_live.ts";

Deno.test("apple jwt expires in under 20 minutes and names the audience", async () => {
  const key = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", key.privateKey);
  const nowSeconds = 1_700_000_000;
  const token = await signAppleJwt({
    issuer: "issuer",
    keyId: "KEYID",
    pkcs8,
    nowSeconds,
  });
  const [header, payload, signature] = token.split(".");
  const decodedHeader = JSON.parse(new TextDecoder().decode(decode(header)));
  const decodedPayload = JSON.parse(new TextDecoder().decode(decode(payload)));
  assertEquals(decodedHeader.alg, "ES256");
  assertEquals(decodedHeader.kid, "KEYID");
  assertEquals(decodedPayload.aud, "appstoreconnect-v1");
  assertEquals(decodedPayload.iss, "issuer");
  assertEquals(decodedPayload.exp - decodedPayload.iat, 19 * 60);
  assertEquals(decodedPayload.exp - nowSeconds < 20 * 60, true);
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key.publicKey,
    bytesToArrayBuffer(decode(signature)),
    bytesToArrayBuffer(new TextEncoder().encode(`${header}.${payload}`)),
  );
  assertEquals(verified, true);
});

Deno.test("ongoing analytics request names the app and does not repeat an existing one", () => {
  const body = analyticsRequestBody("123");
  const data = body.data as {
    attributes: { accessType: string };
    relationships: { app: { data: { id: string } } };
  };
  assertEquals(data.attributes.accessType, "ONGOING");
  assertEquals(data.relationships.app.data.id, "123");
});

Deno.test("notification users are matched from the transaction table", () => {
  const path = storeOriginalTransactionPath("1000000123456789");
  assertEquals(path.startsWith("store_original_transactions?"), true);
  assertEquals(path.includes("app_events"), false);
  assertEquals(path.includes("entitlement_observed"), false);
  assertEquals(accountIsClosed(null), false);
  assertEquals(accountIsClosed(undefined), false);
  assertEquals(accountIsClosed("2026-10-07T00:00:00Z"), true);
});

Deno.test("sales dates cover the previous 14 days", () => {
  const dates = recentReportDates(new Date("2026-10-08T00:00:00Z"));
  assertEquals(dates.length, 14);
  assertEquals(dates[0], "2026-10-07");
  assertEquals(dates[13], "2026-09-24");
});

function bytesToArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(copy).set(bytes);
  return copy;
}

function decode(value: string): Uint8Array {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") +
    "=".repeat((4 - value.length % 4) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
