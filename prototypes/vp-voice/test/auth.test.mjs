import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createAuth } from "../relay/auth.mjs";
import { createAuthStore, createBlobStore, createFileStore } from "../relay/auth-store.mjs";
import { startServer } from "../relay/server.mjs";

function cookieFrom(response) {
  const raw = response.headers.get("set-cookie") || "";
  const pair = raw.split(";")[0];
  assert.match(raw, /HttpOnly/);
  assert.match(raw, /SameSite=Lax/);
  return pair;
}

async function gate(file, tokenRef, limits) {
  let clock = 1_700_000_000_000;
  const auth = createAuth({
    setupToken: () => tokenRef.value,
    store: createFileStore(file),
    now: () => clock,
    limits,
  });
  const app = await startServer({ auth, apiKey: "test-key", port: 0 });
  return {
    app,
    clock: (value) => {
      clock = value;
    },
    now: () => clock,
  };
}

test("初回は合言葉がないと決まらず、決めたあとは同じ合言葉では二度と設定できない", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "vp-auth-"));
  const token = { value: "" };
  const { app } = await gate(path.join(dir, "auth.json"), token);
  try {
    const status = await fetch(`${app.url}/api/auth/status`).then((res) => res.json());
    assert.equal(status.mode, "unconfigured");
    const blocked = await fetch(`${app.url}/api/chat`, { method: "POST", body: "{}" });
    assert.equal(blocked.status, 401);

    token.value = "one-time-token";
    const opened = await fetch(`${app.url}/api/auth/status`).then((res) => res.json());
    assert.equal(opened.mode, "setup");
    assert.equal(opened.reset, false);

    const wrong = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "other", password: "correct-horse" }),
    });
    assert.equal(wrong.status, 401);

    const short = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "one-time-token", password: "short" }),
    });
    assert.equal(short.status, 400);

    const setup = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "one-time-token", password: "correct-horse" }),
    });
    assert.equal(setup.status, 200);
    const cookie = cookieFrom(setup);
    const health = await fetch(`${app.url}/api/health`, { headers: { cookie } });
    assert.equal(health.status, 200);
    const body = await health.json();
    assert.equal(body.hasAnthropicKey, true);
    assert.equal(JSON.stringify(body).includes("test-key"), false);

    const again = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "one-time-token", password: "another-secret" }),
    });
    assert.equal(again.status, 403);
    const oldLogin = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "correct-horse" }),
    });
    assert.equal(oldLogin.status, 200);
    const stored = JSON.parse(await fs.readFile(path.join(dir, "auth.json"), "utf8"));
    assert.equal(JSON.stringify(stored).includes("correct-horse"), false);
    assert.equal(JSON.stringify(stored).includes("one-time-token"), false);
  } finally {
    app.server.close();
  }
});

test("間違いが続くとロックし、合言葉を入れ替えるとパスワードを設定し直せる", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "vp-auth-"));
  const token = { value: "first-token" };
  const { app, clock, now } = await gate(path.join(dir, "auth.json"), token, {
    maxFailures: 2,
    lockMs: 60_000,
    sessionMs: 120_000,
    passwordMin: 8,
  });
  try {
    await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "first-token", password: "correct-horse" }),
    });
    const first = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "wrong-password" }),
    });
    assert.equal(first.status, 401);
    const second = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "wrong-password" }),
    });
    assert.equal(second.status, 429);
    const during = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "correct-horse" }),
    });
    assert.equal(during.status, 429);

    clock(now() + 61_000);
    const after = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "correct-horse" }),
    });
    assert.equal(after.status, 200);
    const oldCookie = cookieFrom(after);

    token.value = "second-token";
    const reset = await fetch(`${app.url}/api/auth/status`).then((res) => res.json());
    assert.equal(reset.mode, "setup");
    assert.equal(reset.reset, true);
    const replaced = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json", cookie: oldCookie },
      body: JSON.stringify({ token: "second-token", password: "brand-new-secret" }),
    });
    assert.equal(replaced.status, 200);
    const stale = await fetch(`${app.url}/api/health`, { headers: { cookie: oldCookie } });
    assert.equal(stale.status, 401);
    const oldPassword = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "correct-horse" }),
    });
    assert.equal(oldPassword.status, 401);
    const fresh = await fetch(`${app.url}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "brand-new-secret" }),
    });
    assert.equal(fresh.status, 200);
    const closed = await fetch(`${app.url}/api/auth/setup`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "second-token", password: "yet-another-secret" }),
    });
    assert.equal(closed.status, 403);
  } finally {
    app.server.close();
  }
});

test("Blob が無い Vercel では一時ディスクに書かない", async () => {
  const store = createAuthStore({ VERCEL: "1", BLOB_READ_WRITE_TOKEN: "" });
  await assert.rejects(() => store.read(), /BLOB_READ_WRITE_TOKEN/);
});

test("Blob へは非公開で、読むときはキャッシュを外す", async () => {
  const calls = [];
  const fetchImpl = async (url, init = {}) => {
    calls.push({ url: String(url), method: init.method || "GET", headers: init.headers, body: init.body });
    if (!init.method || init.method === "GET") {
      return new Response("not found", { status: 404 });
    }
    return new Response(JSON.stringify({ etag: "etag-1" }), {
      status: 200,
      headers: { etag: "etag-1" },
    });
  };
  const store = createBlobStore("vercel_blob_rw_store123_secret", fetchImpl);
  const missing = await store.read();
  assert.equal(missing.record, null);
  assert.match(calls[0].url, /store123\.private\.blob\.vercel-storage\.com\/vp-voice\/auth\.json\?cache=0/);
  await store.write({ version: 1 }, null);
  assert.equal(calls[1].method, "PUT");
  assert.equal(calls[1].headers["x-vercel-blob-access"], "private");
  assert.equal(calls[1].headers["x-allow-overwrite"], "1");
  assert.equal(calls[1].headers["x-if-match"], undefined);
});
