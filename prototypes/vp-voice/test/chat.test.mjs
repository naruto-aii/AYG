import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { resetSessions } from "../relay/handler.mjs";
import { nodeRepo, startServer } from "../relay/server.mjs";
import { startAnthropic, startCursor } from "./upstream.mjs";

const ANTHROPIC_KEY = "test-anthropic-key";
const CURSOR_KEY = "test-cursor-key";

async function fixture() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "vp-chat-"));
  await fs.writeFile(path.join(root, "README.md"), "カロナビは食事、運動、体重を記録するアプリ");
  await fs.writeFile(path.join(root, ".env"), "ANTHROPIC_API_KEY=SUPERSECRETVALUE\n");
  return root;
}

test("会話、承認前は送らず、承認後だけCursorを呼ぶ", async () => {
  resetSessions();
  const root = await fixture();
  const anthropic = await startAnthropic();
  const cursor = await startCursor();
  const app = await startServer({
    apiKey: ANTHROPIC_KEY,
    cursorKey: CURSOR_KEY,
    anthropicBase: anthropic.url,
    cursorBase: cursor.url,
    repo: nodeRepo(root),
    port: 0,
  });
  const sessionId = "session-chat-1";

  try {
    const health = await fetch(`${app.url}/api/health`).then((res) => res.json());
    assert.equal(health.hasAnthropicKey, true);
    assert.equal(health.hasCursorKey, true);
    assert.equal(JSON.stringify(health).includes(ANTHROPIC_KEY), false);

    const page = await fetch(`${app.url}/`);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /打ち合わせを始める/);

    const repoReply = await chat(app.url, {
      sessionId,
      model: "claude-haiku-5-5",
      messages: [{ role: "user", content: "このリポジトリは何をしてる？" }],
    });
    assert.match(repoReply, /カロナビ/);
    assert.match(repoReply, /"type":"usage"/);
    assert.equal(repoReply.includes(ANTHROPIC_KEY), false);
    assert.equal(repoReply.includes("SUPERSECRETVALUE"), false);
    const toolResult = JSON.stringify(anthropic.calls.at(-1).body);
    assert.match(toolResult, /カロナビは食事/);
    assert.equal(anthropic.calls[0].key, ANTHROPIC_KEY);

    const secretReply = await chat(app.url, {
      sessionId: "session-secret",
      messages: [{ role: "user", content: "秘密の鍵を読んで" }],
    });
    assert.match(secretReply, /見ていない|読まない|秘密/);
    assert.equal(JSON.stringify(anthropic.calls).includes("SUPERSECRETVALUE"), false);

    assert.equal(cursor.calls.length, 0);
    const draftReply = await chat(app.url, {
      sessionId,
      messages: [{ role: "user", content: "ホームの文言を直して。Cursorに頼んで" }],
    });
    assert.match(draftReply, /依頼はこの内/);
    assert.match(draftReply, /容でいい/);
    assert.match(draftReply, /"type":"approval"/);
    assert.equal(cursor.calls.length, 0);

    const buttonOnly = await launch(app.url, { sessionId, buttonApproved: true, phrase: "" });
    assert.equal(buttonOnly.status, 403);
    const phraseOnly = await launch(app.url, { sessionId, buttonApproved: false, phrase: "それでいい" });
    assert.equal(phraseOnly.status, 403);
    assert.equal(cursor.calls.length, 0);

    await fetch(`${app.url}/api/cursor/draft`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ sessionId, text: "ホームの今日あと、の文言を揃える。ボタンの位置は変えない。" }),
    });
    const approved = await launch(app.url, { sessionId, buttonApproved: true, phrase: "それでいい。" });
    assert.equal(approved.status, 200);
    assert.equal(approved.json.url, "https://cursor.com/agents/bc-test");
    assert.equal(cursor.calls.length, 1);
    assert.equal(cursor.calls[0].url, "/v1/agents");
    assert.match(cursor.calls[0].body.prompt.text, /ボタンの位置は変えない/);
    assert.equal(cursor.calls[0].body.repos[0].url, "https://github.com/naruto-aii/AYG");
    assert.equal(cursor.calls[0].body.workOnCurrentBranch, false);
    const decoded = Buffer.from(cursor.calls[0].auth.replace("Basic ", ""), "base64").toString();
    assert.equal(decoded, `${CURSOR_KEY}:`);
    assert.equal(JSON.stringify(approved.json).includes(CURSOR_KEY), false);

    const again = await launch(app.url, { sessionId, buttonApproved: true, phrase: "それでいい" });
    assert.equal(again.status, 403);
    assert.equal(cursor.calls.length, 1);

    const minutes = await fetch(`${app.url}/api/minutes`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        sessionId,
        elapsedSec: 90,
        transcript: [
          { role: "user", text: "ホームの文言を直して。Cursorに頼んで" },
          { role: "assistant", text: "依頼はこの内容でいい？" },
        ],
      }),
    }).then((res) => res.json());
    assert.match(minutes.markdown, /https:\/\/cursor.com\/agents\/bc-test/);
    assert.match(minutes.markdown, /決まったこと/);
    assert.ok(minutes.requests.length === 1);

    const savingSession = "session-saving";
    await chat(app.url, {
      sessionId: savingSession,
      model: "claude-sonnet-5-5",
      messages: [{ role: "user", content: "長い話" }],
    });
    await chat(app.url, {
      sessionId: savingSession,
      model: "claude-sonnet-5-5",
      messages: [
        { role: "user", content: "長い話" },
        { role: "assistant", content: "まだ話すね。" },
        { role: "user", content: "次" },
      ],
    });
    const saved = anthropic.calls.at(-1).body;
    assert.equal(saved.model, "claude-haiku-5-5");
    assert.equal(saved.max_tokens, 80);
    assert.deepEqual(saved.tools.map((tool) => tool.name), ["draft_cursor_request"]);
    assert.match(saved.messages.at(-1).content, /節約中/);
  } finally {
    app.server.close();
    anthropic.server.close();
    cursor.server.close();
  }
});

async function chat(url, payload) {
  const response = await fetch(`${url}/api/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ model: "claude-haiku-5-5", ...payload }),
  });
  return response.text();
}

async function launch(url, payload) {
  const response = await fetch(`${url}/api/cursor/launch`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  return { status: response.status, json: await response.json() };
}
