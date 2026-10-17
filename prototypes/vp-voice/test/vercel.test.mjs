import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createAuthStore } from "../relay/auth-store.mjs";
import { resetSessions, handleRequest } from "../relay/handler.mjs";
import { createFileSessionStore, createSessionStore } from "../relay/session-store.mjs";

test("本番の Vercel で Blob が無いときは手元のファイルに書かない", async () => {
  const auth = createAuthStore({ VERCEL: "1", VERCEL_ENV: "production", BLOB_READ_WRITE_TOKEN: "" });
  await assert.rejects(() => auth.read(), /BLOB_READ_WRITE_TOKEN/);
  const sessions = createSessionStore({ VERCEL: "1", VERCEL_ENV: "preview", BLOB_READ_WRITE_TOKEN: "" });
  await assert.rejects(() => sessions.read("session-prod"), /BLOB_READ_WRITE_TOKEN/);
});

test("vercel dev では Blob が無くても手元のファイルを使う", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "vp-dev-"));
  const auth = createAuthStore({
    VERCEL: "1",
    VERCEL_ENV: "development",
    BLOB_READ_WRITE_TOKEN: "",
    VP_AUTH_FILE: path.join(dir, "auth.json"),
  });
  const loaded = await auth.read();
  assert.equal(loaded.record, null);
});

test("下書きはメモリを消しても残り、承認が揃うまで送らない", async () => {
  resetSessions();
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "vp-sessions-"));
  const sessions = createFileSessionStore(dir);
  const deps = {
    apiKey: "",
    cursorKey: "",
    repo: { search() { return ""; }, read() { return ""; } },
    sessions,
  };
  const sessionId = "session-persist";
  const draft = await handleRequest(new Request("http://127.0.0.1/api/cursor/draft", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ sessionId, text: "ボタンの色を直す" }),
  }), deps);
  assert.equal(draft.status, 200);
  resetSessions();
  const blocked = await handleRequest(new Request("http://127.0.0.1/api/cursor/launch", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ sessionId, buttonApproved: false, phrase: "それでいい" }),
  }), deps);
  assert.equal(blocked.status, 403);
  const ready = await handleRequest(new Request("http://127.0.0.1/api/cursor/launch", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ sessionId, buttonApproved: true, phrase: "それでいい" }),
  }), deps);
  assert.equal(ready.status, 500);
  const body = await ready.json();
  assert.match(body.message, /CURSOR_API_KEY/);
  assert.equal(JSON.stringify(body).includes("ボタンの色"), false);
});

test("関数の入口は認証なしのAPIを401にし、鍵の値は返さない", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "vp-fn-"));
  const previous = {
    SETUP_TOKEN: process.env.SETUP_TOKEN,
    VP_AUTH_FILE: process.env.VP_AUTH_FILE,
    VP_SESSION_DIR: process.env.VP_SESSION_DIR,
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
    CURSOR_API_KEY: process.env.CURSOR_API_KEY,
    BLOB_READ_WRITE_TOKEN: process.env.BLOB_READ_WRITE_TOKEN,
    VERCEL: process.env.VERCEL,
  };
  process.env.SETUP_TOKEN = "vercel-setup-token";
  process.env.VP_AUTH_FILE = path.join(dir, "auth.json");
  process.env.VP_SESSION_DIR = path.join(dir, "sessions");
  process.env.ANTHROPIC_API_KEY = "sk-ant-test-should-not-leak";
  process.env.CURSOR_API_KEY = "cursor-test-should-not-leak";
  delete process.env.BLOB_READ_WRITE_TOKEN;
  delete process.env.VERCEL;
  try {
    const entry = await import("../api/health.mjs");
    const chat = await entry.POST(new Request("http://127.0.0.1/api/chat", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    }));
    assert.equal(chat.status, 401);
    const health = await entry.GET(new Request("http://127.0.0.1/api/health"));
    assert.equal(health.status, 401);
    const minutes = await entry.POST(new Request("http://127.0.0.1/api/minutes", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    }));
    assert.equal(minutes.status, 401);
    const status = await entry.GET(new Request("http://127.0.0.1/api/auth/status"));
    assert.equal(status.status, 200);
    const statusBody = await status.json();
    assert.equal(statusBody.mode, "setup");
    assert.equal(JSON.stringify(statusBody).includes("should-not-leak"), false);

    const setup = await entry.POST(new Request("http://127.0.0.1/api/auth/setup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: "vercel-setup-token", password: "correct-horse" }),
    }));
    assert.equal(setup.status, 200);
    const cookie = setup.headers.get("set-cookie");
    assert.match(cookie, /vp_session=/);
    assert.equal(cookie.includes("should-not-leak"), false);
    const opened = await entry.GET(new Request("http://127.0.0.1/api/health", { headers: { cookie } }));
    assert.equal(opened.status, 200);
    const openedBody = await opened.json();
    assert.equal(openedBody.hasAnthropicKey, true);
    assert.equal(openedBody.hasCursorKey, true);
    assert.equal(JSON.stringify(openedBody).includes("should-not-leak"), false);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  }
});
