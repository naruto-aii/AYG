import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Buffer } from "node:buffer";
import { sign } from "node:crypto";
import { Environment } from "npm:@apple/app-store-server-library";
import {
  appleSignedDataOnlineChecks,
  calonaviAppAppleId,
  calonaviBundleId,
  signedDataVerifier,
  verifySignedNotification,
} from "./_shared/apple_signed_data.ts";

type Chain = {
  rootB64: string;
  leafPem: string;
  x5c: string[];
};

Deno.test("fixture chains verify for Sandbox and Production without calling Apple", async () => {
  const chain = await makeChain("calonavi-good");
  const other = await makeChain("calonavi-other");
  const previousOnline = Deno.env.get("APPLE_SIGNED_DATA_ONLINE_CHECKS");
  const previousRoot = Deno.env.get("APPLE_ROOT_CA_BASE64");
  const previousBundle = Deno.env.get("APP_BUNDLE_ID");
  const previousApp = Deno.env.get("ASC_APP_APPLE_ID");
  Deno.env.set("APPLE_SIGNED_DATA_ONLINE_CHECKS", "false");
  Deno.env.set("APPLE_ROOT_CA_BASE64", chain.rootB64);
  Deno.env.delete("APP_BUNDLE_ID");
  Deno.env.delete("ASC_APP_APPLE_ID");
  try {
    assertEquals(appleSignedDataOnlineChecks(), false);
    const trialEnd = Date.now() + 3 * 24 * 60 * 60 * 1000;
    const sandbox = await decode(signedNotification(chain, {
      environment: "Sandbox",
      notificationType: "SUBSCRIBED",
      subtype: "INITIAL_BUY",
      expiresDate: trialEnd,
      offerType: 1,
    }));
    assertEquals(sandbox.environment, "Sandbox");
    assertEquals(sandbox.bundleId, calonaviBundleId);
    assertEquals(sandbox.notificationType, "SUBSCRIBED");
    assertEquals(sandbox.offerType, 1);
    assertEquals(sandbox.expiresDate, trialEnd);
    assert(sandbox.gracePeriodExpiresDate != null && sandbox.gracePeriodExpiresDate > trialEnd);

    const production = await decode(signedNotification(chain, {
      environment: "Production",
      notificationType: "DID_RENEW",
      expiresDate: trialEnd + 30 * 24 * 60 * 60 * 1000,
    }));
    assertEquals(production.environment, "Production");
    assertEquals(production.notificationType, "DID_RENEW");
    assertEquals(production.bundleId, calonaviBundleId);

    Deno.env.set("APPLE_ROOT_CA_BASE64", other.rootB64);
    await assertRejects(() =>
      verifySignedNotification(signedNotification(chain, {
        environment: "Sandbox",
        notificationType: "SUBSCRIBED",
        expiresDate: trialEnd,
      }))
    );
    Deno.env.set("APPLE_ROOT_CA_BASE64", chain.rootB64);
    await assertRejects(() =>
      verifySignedNotification(signedNotification(chain, {
        environment: "Production",
        notificationType: "SUBSCRIBED",
        bundleId: "com.example.other",
        expiresDate: trialEnd,
      }))
    );
    await assertRejects(() =>
      verifySignedNotification(signedNotification(chain, {
        environment: "Production",
        notificationType: "SUBSCRIBED",
        appAppleId: 1,
        expiresDate: trialEnd,
      }))
    );
  } finally {
    restore("APPLE_SIGNED_DATA_ONLINE_CHECKS", previousOnline);
    restore("APPLE_ROOT_CA_BASE64", previousRoot);
    restore("APP_BUNDLE_ID", previousBundle);
    restore("ASC_APP_APPLE_ID", previousApp);
  }
  Deno.env.delete("APPLE_SIGNED_DATA_ONLINE_CHECKS");
  assertEquals(appleSignedDataOnlineChecks(), true);
  restore("APPLE_SIGNED_DATA_ONLINE_CHECKS", previousOnline);
});

async function decode(signedPayload: string) {
  const { decoded } = await verifySignedNotification(signedPayload);
  const data = decoded.data ?? {};
  const environment = data.environment === "Sandbox" ? Environment.SANDBOX : Environment.PRODUCTION;
  const transaction = await signedDataVerifier(environment).verifyAndDecodeTransaction(
    data.signedTransactionInfo ?? "",
  );
  const renewal = await signedDataVerifier(environment).verifyAndDecodeRenewalInfo(
    data.signedRenewalInfo ?? "",
  );
  return {
    notificationType: decoded.notificationType,
    environment: transaction.environment,
    bundleId: transaction.bundleId,
    offerType: transaction.offerType,
    expiresDate: transaction.expiresDate,
    gracePeriodExpiresDate: renewal.gracePeriodExpiresDate,
  };
}

function signedNotification(chain: Chain, input: {
  environment: string;
  notificationType: string;
  subtype?: string;
  expiresDate: number;
  offerType?: number;
  bundleId?: string;
  appAppleId?: number;
}): string {
  const bundleId = input.bundleId ?? calonaviBundleId;
  const signedDate = Date.now();
  const transaction = signPayload(chain, {
    bundleId,
    environment: input.environment,
    productId: "calonavi_plus_monthly",
    originalTransactionId: "1000000000000001",
    transactionId: "1000000000000002",
    appAccountToken: "11111111-1111-4111-8111-111111111111",
    expiresDate: input.expiresDate,
    offerType: input.offerType,
    signedDate,
    type: "Auto-Renewable Subscription",
  });
  const renewal = signPayload(chain, {
    environment: input.environment,
    originalTransactionId: "1000000000000001",
    productId: "calonavi_plus_monthly",
    gracePeriodExpiresDate: input.expiresDate + 16 * 24 * 60 * 60 * 1000,
    signedDate,
  });
  return signPayload(chain, {
    notificationType: input.notificationType,
    subtype: input.subtype,
    notificationUUID: crypto.randomUUID(),
    version: "2.0",
    signedDate,
    data: {
      environment: input.environment,
      bundleId,
      appAppleId: input.appAppleId ?? calonaviAppAppleId,
      signedTransactionInfo: transaction,
      signedRenewalInfo: renewal,
    },
  });
}

function signPayload(chain: Chain, payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: "ES256", x5c: chain.x5c })).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const raw = sign("sha256", Buffer.from(`${header}.${body}`), {
    key: chain.leafPem,
    dsaEncoding: "ieee-p1363",
  });
  return `${header}.${body}.${Buffer.from(raw).toString("base64url")}`;
}

function restore(name: string, value: string | undefined) {
  if (value == null) {
    Deno.env.delete(name);
  } else {
    Deno.env.set(name, value);
  }
}

async function makeChain(label: string): Promise<Chain> {
  const dir = await Deno.makeTempDir({ prefix: `${label}-` });
  const config = `${dir}/openssl.cnf`;
  await Deno.writeTextFile(config, `
[v3_root]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[v3_intermediate]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
1.2.840.113635.100.6.2.1 = ASN1:NULL
[v3_leaf]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
1.2.840.113635.100.6.11.1 = ASN1:NULL
`);
  await openssl(["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${dir}/root.key`]);
  await openssl(["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${dir}/int.key`]);
  await openssl(["ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${dir}/leaf.key`]);
  await openssl([
    "req", "-new", "-x509", "-key", `${dir}/root.key`, "-out", `${dir}/root.pem`, "-days", "4000",
    "-subj", `/CN=${label} Root/O=Calonavi Test/C=US`,
    "-config", config, "-extensions", "v3_root",
  ]);
  await openssl([
    "req", "-new", "-key", `${dir}/int.key`, "-out", `${dir}/int.csr`,
    "-subj", `/CN=${label} Intermediate/O=Calonavi Test/C=US`,
  ]);
  await openssl([
    "x509", "-req", "-in", `${dir}/int.csr`, "-CA", `${dir}/root.pem`, "-CAkey", `${dir}/root.key`,
    "-CAcreateserial", "-out", `${dir}/int.pem`, "-days", "4000",
    "-extfile", config, "-extensions", "v3_intermediate",
  ]);
  await openssl([
    "req", "-new", "-key", `${dir}/leaf.key`, "-out", `${dir}/leaf.csr`,
    "-subj", `/CN=${label} Leaf/O=Calonavi Test/C=US`,
  ]);
  await openssl([
    "x509", "-req", "-in", `${dir}/leaf.csr`, "-CA", `${dir}/int.pem`, "-CAkey", `${dir}/int.key`,
    "-CAcreateserial", "-out", `${dir}/leaf.pem`, "-days", "4000",
    "-extfile", config, "-extensions", "v3_leaf",
  ]);
  const rootDer = await openssl(["x509", "-in", `${dir}/root.pem`, "-outform", "DER"]);
  const intDer = await openssl(["x509", "-in", `${dir}/int.pem`, "-outform", "DER"]);
  const leafDer = await openssl(["x509", "-in", `${dir}/leaf.pem`, "-outform", "DER"]);
  return {
    rootB64: Buffer.from(rootDer).toString("base64"),
    leafPem: await Deno.readTextFile(`${dir}/leaf.key`),
    x5c: [leafDer, intDer, rootDer].map((der) => Buffer.from(der).toString("base64")),
  };
}

async function openssl(args: string[]): Promise<Uint8Array> {
  const command = new Deno.Command("openssl", { args, stdout: "piped", stderr: "piped" });
  const result = await command.output();
  if (!result.success) {
    throw new Error(new TextDecoder().decode(result.stderr));
  }
  return result.stdout;
}
