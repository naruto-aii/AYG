import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Environment, VerificationStatus } from "npm:@apple/app-store-server-library";
import {
  appBundleIdFlags,
  appleVerifyFailure,
  calonaviBundleId,
  expectedBundleId,
  unsignedTransactionClaims,
  verifyAcrossStoreEnvironments,
} from "./_shared/apple_signed_data.ts";

function b64url(value: string): string {
  return btoa(value).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function withBundle(value: string | null, body: () => Promise<void> | void): Promise<void> {
  const previous = Deno.env.get("APP_BUNDLE_ID");
  if (value == null) {
    Deno.env.delete("APP_BUNDLE_ID");
  } else {
    Deno.env.set("APP_BUNDLE_ID", value);
  }
  const restore = () => {
    if (previous == null) {
      Deno.env.delete("APP_BUNDLE_ID");
    } else {
      Deno.env.set("APP_BUNDLE_ID", previous);
    }
  };
  return Promise.resolve(body()).then(
    (result) => {
      restore();
      return result;
    },
    (error) => {
      restore();
      throw error;
    },
  );
}

Deno.test("an empty APP_BUNDLE_ID uses the public bundle and a different value is left as-is", async () => {
  await withBundle(null, () => {
    assertEquals(expectedBundleId(), calonaviBundleId);
    assertEquals(appBundleIdFlags(), { set: false, matches: false });
  });
  await withBundle("   ", () => {
    assertEquals(expectedBundleId(), calonaviBundleId);
    assertEquals(appBundleIdFlags(), { set: false, matches: false });
  });
  await withBundle(calonaviBundleId, () => {
    assertEquals(appBundleIdFlags(), { set: true, matches: true });
  });
  await withBundle("com.example.other", () => {
    assertEquals(expectedBundleId(), "com.example.other");
    assertEquals(appBundleIdFlags(), { set: true, matches: false });
  });
});

Deno.test("verify-store-transaction passes the bundle fallback into the entitlement decision", async () => {
  const source = await Deno.readTextFile(
    new URL("./verify-store-transaction/index.ts", import.meta.url),
  );
  assert(source.includes("expectedBundleId: expectedBundleId()"));
  assert(!source.includes('Deno.env.get("APP_BUNDLE_ID")'));
});

Deno.test("a failed verify logs each environment once and does not skip the revocation check", async () => {
  const payload = b64url(JSON.stringify({
    bundleId: calonaviBundleId,
    environment: "Sandbox",
    originalTransactionId: "do-not-log",
  }));
  const jws = `eyJhbGciOiJFUzI1NiJ9.${payload}.sig`;
  const calls: string[] = [];
  const logs: unknown[][] = [];
  const original = console.error;
  console.error = (...args: unknown[]) => {
    logs.push(args);
  };
  try {
    await withBundle("com.example.other", async () => {
      await assertRejects(() =>
        verifyAcrossStoreEnvironments(async (environment) => {
          calls.push(String(environment));
          if (environment === Environment.PRODUCTION) {
            const error = new Error("production");
            (error as { status?: number }).status = VerificationStatus.INVALID_ENVIRONMENT;
            throw error;
          }
          const cause = new TypeError(`ocsp ${jws} com.example.other`);
          const error = new Error("sandbox");
          (error as { status?: number; cause?: Error }).status =
            VerificationStatus.RETRYABLE_VERIFICATION_FAILURE;
          (error as { cause?: Error }).cause = cause;
          throw error;
        }, jws)
      );
    });
  } finally {
    console.error = original;
  }
  assertEquals(calls, [Environment.PRODUCTION, Environment.SANDBOX]);
  assertEquals(logs.length, 1);
  assertEquals(logs[0][0], "[apple-signed-data] verify failed");
  const entry = logs[0][1] as {
    attempts: Array<{ environment: string; status: string; cause: string; message: string }>;
    appBundleIdSet: boolean;
    appBundleIdMatches: boolean;
    transactionBundleId: string | null;
    transactionEnvironment: string | null;
  };
  assertEquals(entry.attempts.map((attempt) => attempt.environment), ["Production", "Sandbox"]);
  assertEquals(entry.attempts[0].status, "INVALID_ENVIRONMENT");
  assertEquals(entry.attempts[1].status, "RETRYABLE_VERIFICATION_FAILURE");
  assertEquals(entry.attempts[1].cause, "TypeError");
  assert(entry.attempts[1].message.includes("[jws]"));
  assert(entry.attempts[1].message.includes("[app-bundle-id]"));
  assertEquals(entry.appBundleIdSet, true);
  assertEquals(entry.appBundleIdMatches, false);
  assertEquals(entry.transactionBundleId, calonaviBundleId);
  assertEquals(entry.transactionEnvironment, "Sandbox");
  const text = JSON.stringify(logs);
  assert(!text.includes(jws));
  assert(!text.includes("do-not-log"));
  assert(!text.includes("com.example.other"));
  assert(!text.includes("originalTransactionId"));
});

Deno.test("unsigned claims keep only the bundle and environment", () => {
  const payload = b64url(JSON.stringify({
    bundleId: calonaviBundleId,
    environment: "Production",
    appAccountToken: "user-secret",
  }));
  assertEquals(unsignedTransactionClaims(`h.${payload}.s`), {
    bundleId: calonaviBundleId,
    environment: "Production",
  });
  assertEquals(unsignedTransactionClaims("not-a-jws"), {
    bundleId: null,
    environment: null,
  });
});

Deno.test("a verification status name is logged without the JWS", () => {
  const cause = new TypeError("eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ0In0.sig");
  const error = new Error("wrapper");
  (error as { status?: number; cause?: Error }).status = VerificationStatus.VERIFICATION_FAILURE;
  (error as { cause?: Error }).cause = cause;
  const failure = appleVerifyFailure(error);
  assertEquals(failure.status, "VERIFICATION_FAILURE");
  assertEquals(failure.cause, "TypeError");
  assertEquals(failure.message, "[jws]");
});
