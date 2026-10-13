import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Buffer } from "node:buffer";
import { sign } from "node:crypto";
import { calonaviBundleId } from "./_shared/apple_signed_data.ts";

/// `supabase functions serve` が使う Edge Runtime のイメージと同じ版。
const edgeRuntimeImage = "supabase/edge-runtime:v1.77.4";
const cachedRuntime = "/tmp/calonavi-edge-runtime/v1.77.4/edge-runtime";

Deno.test({
  name: "a self-signed chain verifies on the Edge Runtime without Not implemented",
  sanitizeOps: false,
  sanitizeResources: false,
}, async () => {
  const runtime = await edgeRuntimeBinary();
  const chain = await makeChain("edge-jws");
  const port = await freePort();
  const dir = await Deno.makeTempDir({ prefix: "edge-jws-" });
  const shared = new URL("./_shared/", import.meta.url);
  for (const name of ["apple_signed_data.ts", "apple_webcrypto_jws.ts", "apple_root_cas.ts"]) {
    await Deno.copyFile(new URL(name, shared), `${dir}/${name}`);
  }
  await Deno.writeTextFile(
    `${dir}/index.ts`,
    `import { verifySignedTransaction } from "./apple_signed_data.ts";

Deno.serve(async (request) => {
  const url = new URL(request.url);
  if (url.pathname === "/health") {
    return new Response("ok");
  }
  if (url.pathname === "/control") {
    try {
      const { X509Certificate } = await import("node:crypto");
      const der = Uint8Array.from(atob(Deno.env.get("APPLE_ROOT_CA_BASE64") ?? ""), (char) =>
        char.charCodeAt(0)
      );
      const cert = new X509Certificate(der);
      cert.verify(cert.publicKey);
      return new Response("control-implemented", { status: 200 });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return new Response(message, { status: 501 });
    }
  }
  const jws = await request.text();
  try {
    const payload = await verifySignedTransaction(jws);
    return new Response(JSON.stringify({
      ok: true,
      bundleId: payload.bundleId ?? null,
      environment: payload.environment ?? null,
    }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (error) {
    const cause = error instanceof Error && error.cause instanceof Error ? error.cause.message : "";
    const message = error instanceof Error ? error.message : String(error);
    const name = error instanceof Error ? error.name : "Error";
    return new Response(JSON.stringify({ ok: false, name, message, cause }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  }
});
`,
  );
  const jws = signPayload(chain, {
    bundleId: calonaviBundleId,
    environment: "Sandbox",
    productId: "calonavi_plus_yearly",
    originalTransactionId: "1000000000000001",
    transactionId: "1000000000000002",
    signedDate: Date.now(),
  });
  const child = new Deno.Command(runtime, {
    args: ["start", "--ip", "127.0.0.1", "--port", String(port), "--main-service", dir],
    env: {
      APPLE_SIGNED_DATA_ONLINE_CHECKS: "false",
      APPLE_ROOT_CA_BASE64: chain.rootB64,
      APP_BUNDLE_ID: "",
      ASC_APP_APPLE_ID: "",
    },
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  const stderrChunks: Uint8Array[] = [];
  const stdoutChunks: Uint8Array[] = [];
  const read = async (stream: ReadableStream<Uint8Array>, chunks: Uint8Array[]) => {
    const reader = stream.getReader();
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) {
          return;
        }
        chunks.push(next.value);
      }
    } catch {
      // プロセスを止めたあとの読み取りはここで終わる。
    }
  };
  const stdoutTask = read(child.stdout, stdoutChunks);
  const stderrTask = read(child.stderr, stderrChunks);
  let exitCode: number | null = null;
  child.status.then((status) => {
    exitCode = status.code;
  });
  try {
    await waitForHealth(port, () => exitCode, () => concat([...stdoutChunks, ...stderrChunks]));
    const verified = await fetch(`http://127.0.0.1:${port}/`, {
      method: "POST",
      body: jws,
    });
    const verifiedText = await verified.text();
    const logs = new TextDecoder().decode(
      concat(stdoutChunks.splice(0, stdoutChunks.length).concat(stderrChunks.splice(0, stderrChunks.length))),
    );
    assertEquals(verified.status, 200, `${verifiedText}\n${logs}`);
    assert(!verifiedText.includes("Not implemented"), verifiedText);
    assert(!logs.includes("Not implemented"), logs);
    const body = JSON.parse(verifiedText) as { ok: boolean; bundleId: string; environment: string };
    assertEquals(body.ok, true);
    assertEquals(body.bundleId, calonaviBundleId);
    assertEquals(body.environment, "Sandbox");

    const forged = await fetch(`http://127.0.0.1:${port}/`, {
      method: "POST",
      body: `${jws.slice(0, -4)}AAAA`,
    });
    const forgedText = await forged.text();
    assertEquals(forged.status, 400, forgedText);
    assert(!forgedText.includes("Not implemented"), forgedText);

    const control = await fetch(`http://127.0.0.1:${port}/control`);
    const controlText = await control.text();
    assertEquals(control.status, 501, controlText);
    assert(controlText.includes("Not implemented"), controlText);
  } finally {
    try {
      child.kill("SIGTERM");
    } catch {
      // すでに終了している。
    }
    await child.status;
    await stdoutTask;
    await stderrTask;
  }
});

async function waitForHealth(
  port: number,
  exitCode: () => number | null,
  logs: () => Uint8Array,
) {
  const started = Date.now();
  let last = "";
  while (Date.now() - started < 180_000) {
    const code = exitCode();
    if (code != null) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      throw new Error(`edge runtime exited ${code}: ${new TextDecoder().decode(logs())}`);
    }
    try {
      const response = await fetch(`http://127.0.0.1:${port}/health`);
      if (response.ok) {
        await response.body?.cancel();
        return;
      }
      last = `status ${response.status}`;
      await response.body?.cancel();
    } catch (error) {
      last = error instanceof Error ? error.message : String(error);
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`edge runtime did not start: ${last}\n${new TextDecoder().decode(logs())}`);
}

async function freePort(): Promise<number> {
  const listener = Deno.listen({ hostname: "127.0.0.1", port: 0 });
  const port = (listener.addr as Deno.NetAddr).port;
  listener.close();
  return port;
}

function concat(chunks: Uint8Array[]): Uint8Array {
  const size = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
  const out = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

async function edgeRuntimeBinary(): Promise<string> {
  const fromEnv = Deno.env.get("EDGE_RUNTIME_BIN");
  if (fromEnv && await fileExists(fromEnv)) {
    return fromEnv;
  }
  if (await fileExists(cachedRuntime)) {
    return cachedRuntime;
  }
  const extracted = "/tmp/edge-root/usr/local/bin/edge-runtime";
  if (await fileExists(extracted)) {
    return extracted;
  }
  const crane = await craneBinary();
  const tar = "/tmp/calonavi-edge-runtime/v1.77.4/image.tar";
  await Deno.mkdir("/tmp/calonavi-edge-runtime/v1.77.4", { recursive: true });
  const exported = await new Deno.Command(crane, {
    args: ["export", "--platform", "linux/amd64", edgeRuntimeImage, tar],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!exported.success) {
    throw new Error(new TextDecoder().decode(exported.stderr));
  }
  const unpacked = await new Deno.Command("tar", {
    args: ["-xf", tar, "-C", "/tmp/calonavi-edge-runtime/v1.77.4", "usr/local/bin/edge-runtime"],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!unpacked.success) {
    throw new Error(new TextDecoder().decode(unpacked.stderr));
  }
  const nested = "/tmp/calonavi-edge-runtime/v1.77.4/usr/local/bin/edge-runtime";
  await Deno.rename(nested, cachedRuntime);
  return cachedRuntime;
}

async function craneBinary(): Promise<string> {
  const path = "/tmp/calonavi-edge-runtime/crane";
  if (await fileExists(path)) {
    return path;
  }
  await Deno.mkdir("/tmp/calonavi-edge-runtime", { recursive: true });
  const archive = await fetch(
    "https://github.com/google/go-containerregistry/releases/download/v0.20.6/go-containerregistry_Linux_x86_64.tar.gz",
  );
  if (!archive.ok) {
    throw new Error(`crane download failed: ${archive.status}`);
  }
  const tar = "/tmp/calonavi-edge-runtime/crane.tgz";
  await Deno.writeFile(tar, new Uint8Array(await archive.arrayBuffer()));
  const unpacked = await new Deno.Command("tar", {
    args: ["-xzf", tar, "-C", "/tmp/calonavi-edge-runtime", "crane"],
    stderr: "piped",
  }).output();
  if (!unpacked.success) {
    throw new Error(new TextDecoder().decode(unpacked.stderr));
  }
  return path;
}

async function fileExists(path: string): Promise<boolean> {
  try {
    return (await Deno.stat(path)).isFile;
  } catch {
    return false;
  }
}

type Chain = { rootB64: string; leafPem: string; x5c: string[] };

function signPayload(chain: Chain, payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: "ES256", x5c: chain.x5c })).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const raw = sign("sha256", Buffer.from(`${header}.${body}`), {
    key: chain.leafPem,
    dsaEncoding: "ieee-p1363",
  });
  return `${header}.${body}.${Buffer.from(raw).toString("base64url")}`;
}

async function makeChain(label: string): Promise<Chain> {
  const dir = await Deno.makeTempDir({ prefix: `${label}-` });
  const config = `${dir}/openssl.cnf`;
  await Deno.writeTextFile(
    config,
    `
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
`,
  );
  await openssl(["ecparam", "-name", "secp384r1", "-genkey", "-noout", "-out", `${dir}/root.key`]);
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
  // ルートは P-384。Edge の WebCrypto は P-384 と SHA-256 の組み合わせを実装していない。
  await openssl([
    "x509", "-req", "-sha384", "-in", `${dir}/int.csr`, "-CA", `${dir}/root.pem`, "-CAkey", `${dir}/root.key`,
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
  const result = await new Deno.Command("openssl", { args, stdout: "piped", stderr: "piped" }).output();
  if (!result.success) {
    throw new Error(new TextDecoder().decode(result.stderr));
  }
  return result.stdout;
}
