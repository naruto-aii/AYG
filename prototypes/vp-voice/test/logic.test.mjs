import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { isApprovalPhrase } from "../web/approve.js";
import {
  BUDGET_JPY,
  DEFAULT_MODEL,
  cappedMeetingYen,
  designedMeetingYen,
} from "../web/cost.js";
import { pullSentences } from "../web/speech.js";
import { compressMessages } from "../relay/history.mjs";
import { createRepo, isDenied, redact } from "../relay/repo.mjs";

test("30分の想定はHaikuだけ予算内", () => {
  const haiku = designedMeetingYen(DEFAULT_MODEL);
  const haikuCap = cappedMeetingYen(DEFAULT_MODEL);
  assert.ok(haiku < BUDGET_JPY, `designed ${haiku}`);
  assert.ok(haikuCap < BUDGET_JPY, `capped ${haikuCap}`);
  assert.ok(designedMeetingYen("claude-sonnet-5-5") > BUDGET_JPY);
  assert.ok(cappedMeetingYen("claude-haiku-4-5") > BUDGET_JPY);
  assert.ok(cappedMeetingYen("claude-sonnet-5-5") > BUDGET_JPY);
});

test("承認の一言だけ通す", () => {
  assert.equal(isApprovalPhrase("それでいい。"), true);
  assert.equal(isApprovalPhrase("  それでお願いします "), true);
  assert.equal(isApprovalPhrase("それでいい感じに直して"), false);
  assert.equal(isApprovalPhrase("やっぱりやめて"), false);
});

test("文の区切りで読み上げを分けられる", () => {
  const first = pullSentences("うん。まだ続く", false);
  assert.deepEqual(first.sentences, ["うん。"]);
  assert.equal(first.rest, "まだ続く");
  const flushed = pullSentences(first.rest, true);
  assert.deepEqual(flushed.sentences, ["まだ続く"]);
});

test("古い会話は要約に潰す", () => {
  const messages = [];
  for (let index = 0; index < 4; index += 1) {
    messages.push({ role: "user", content: `質問${index}は長い文章です` });
    messages.push({ role: "assistant", content: `返事${index}` });
  }
  messages.push({ role: "user", content: "最後の質問" });
  const compact = compressMessages(messages);
  assert.ok(compact.length < messages.length);
  assert.equal(compact.at(-1).content, "最後の質問");
  assert.match(compact[0].content, /要約/);
});

test("秘密ファイルは読まず、値も残さない", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "vp-repo-"));
  await fs.writeFile(path.join(root, "README.md"), "カロナビは食事の記録アプリ");
  await fs.writeFile(path.join(root, ".env"), "ANTHROPIC_API_KEY=SUPERSECRETVALUE\n");
  await fs.mkdir(path.join(root, "tool"));
  await fs.writeFile(path.join(root, "tool", "dart_defines.local.json"), '{"X":"LOCALSECRET"}');
  await fs.writeFile(path.join(root, "notes.md"), "token=abcdef password=hunter2");
  const repo = createRepo(root, {
    async readFile(file) {
      return fs.readFile(file, "utf8");
    },
    async readdir(dir) {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      return entries.map((ent) => ({
        name: ent.name,
        isDirectory: () => ent.isDirectory(),
        isFile: () => ent.isFile(),
      }));
    },
  });
  assert.equal(isDenied(".env"), true);
  assert.equal(isDenied("tool/dart_defines.local.json"), true);
  assert.match(await repo.read(".env"), /読まない/);
  assert.match(await repo.read("tool/dart_defines.local.json"), /読まない/);
  const notes = await repo.read("notes.md");
  assert.match(notes, /token=\[redacted\]/);
  assert.doesNotMatch(notes, /hunter2/);
  const found = await repo.search("カロナビ");
  assert.match(found, /README.md/);
  assert.doesNotMatch(found, /SUPERSECRETVALUE/);
  assert.match(redact("sk-ant-abcdefghij"), /\[redacted\]/);
});
