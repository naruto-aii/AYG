import { isApprovalPhrase } from "../web/approve.js";
import {
  ALLOWED_MODELS,
  BUDGET_JPY,
  DEFAULT_MODEL,
  SAVING_JPY,
  addUsage,
  emptyUsage,
  formatYen,
  yenFromUsage,
} from "../web/cost.js";
import { streamMessage } from "./anthropic.mjs";
import { compressMessages } from "./history.mjs";
import { localMinutes, parseMinutes, renderMinutes } from "./minutes.mjs";
import { DRAFT_TOOL, MINUTES_PROMPT, READ_TOOL, SYSTEM_PROMPT } from "./prompt.mjs";
import { lookupRepo } from "./repo.mjs";

const sessions = new Map();
const REPO_URL = "https://github.com/naruto-aii/AYG";

export function resetSessions() {
  sessions.clear();
}

function sessionFor(id) {
  const key = String(id || "").trim();
  if (!/^[A-Za-z0-9-]{8,80}$/.test(key)) {
    throw new Error("sessionId が不正です");
  }
  if (!sessions.has(key)) {
    sessions.set(key, {
      yen: 0,
      usage: emptyUsage(),
      saving: false,
      draft: null,
      agents: [],
    });
  }
  return sessions.get(key);
}

function publicError(error, secrets) {
  let message = error?.message || "中継で失敗しました";
  for (const secret of secrets) {
    if (secret && secret.length > 3) message = message.split(secret).join("[redacted]");
  }
  return message.slice(0, 300);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "content-type",
      "access-control-allow-methods": "GET,POST,OPTIONS",
    },
  });
}

function basicAuth(key) {
  const bytes = new TextEncoder().encode(`${key}:`);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function readJson(request) {
  const text = await request.text();
  if (text.length > 100_000) throw new Error("送信が大きすぎます");
  return JSON.parse(text || "{}");
}

function usageEvent(session) {
  return {
    type: "usage",
    usage: session.usage,
    yen: Number(session.yen.toFixed(4)),
    yenLabel: formatYen(session.yen),
    saving: session.saving,
    budget: BUDGET_JPY,
  };
}

function noteUsage(session, model, usage) {
  session.usage = addUsage(session.usage, usage);
  session.yen += yenFromUsage(model, usage);
  if (session.yen >= SAVING_JPY) session.saving = true;
}

function buildBody({ model, messages, saving }) {
  const tools = saving ? [DRAFT_TOOL] : [READ_TOOL, DRAFT_TOOL];
  const cachedTools = tools.map((tool, index) =>
    index === tools.length - 1 ? { ...tool, cache_control: { type: "ephemeral" } } : tool,
  );
  const outbound = messages.map((message) => ({ ...message }));
  if (saving) {
    const last = outbound.at(-1);
    last.content = `（節約中。一文だけ。ファイルは開かない。）${last.content}`;
  }
  return {
    model: saving ? DEFAULT_MODEL : model,
    max_tokens: saving ? 80 : 180,
    stream: true,
    thinking: { type: "adaptive" },
    output_config: { effort: "low" },
    system: [
      {
        type: "text",
        text: SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" },
      },
    ],
    tools: cachedTools,
    messages: outbound,
  };
}

export async function launchCursorAgent({ baseUrl, apiKey, instruction }) {
  const response = await fetch(`${baseUrl.replace(/\/$/, "")}/v1/agents`, {
    method: "POST",
    headers: {
      authorization: `Basic ${basicAuth(apiKey)}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      prompt: { text: instruction },
      name: `打ち合わせ: ${instruction.slice(0, 40)}`,
      repos: [{ url: REPO_URL, startingRef: "main" }],
      autoCreatePR: true,
      workOnCurrentBranch: false,
    }),
  });
  const text = await response.text();
  let payload = null;
  try {
    payload = JSON.parse(text);
  } catch {
    payload = null;
  }
  if (!response.ok) {
    const message = payload?.message || payload?.error || `Cursor ${response.status}`;
    throw new Error(String(message).slice(0, 200));
  }
  const url = payload?.agent?.url;
  const id = payload?.agent?.id;
  if (!url) throw new Error("Cursorの応答にエージェントのURLがありません");
  return { id, url };
}

async function chat(request, deps) {
  let body;
  try {
    body = await readJson(request);
  } catch (error) {
    return json({ message: publicError(error, []) }, 400);
  }
  if (!deps.apiKey) {
    return json({ message: "中継に ANTHROPIC_API_KEY がありません" }, 500);
  }
  const model = ALLOWED_MODELS.includes(body.model) ? body.model : DEFAULT_MODEL;
  let messages;
  let session;
  try {
    session = sessionFor(body.sessionId);
    messages = compressMessages(body.messages);
  } catch (error) {
    return json({ message: publicError(error, [deps.apiKey, deps.cursorKey]) }, 400);
  }

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
      };
      try {
        const convo = messages.map((message) => ({ role: message.role, content: message.content }));
        for (let step = 0; step < 3; step += 1) {
          const result = await streamMessage({
            apiKey: deps.apiKey,
            baseUrl: deps.anthropicBase,
            body: buildBody({ model, messages: convo, saving: session.saving }),
            signal: request.signal,
            onText(text) {
              send({ type: "text", text });
            },
          });
          noteUsage(session, session.saving ? DEFAULT_MODEL : model, result.usage);
          send(usageEvent(session));
          const toolUses = result.blocks.filter((block) => block.type === "tool_use");
          if (result.stopReason !== "tool_use" || !toolUses.length) break;
          convo.push({ role: "assistant", content: result.blocks });
          const results = [];
          for (const tool of toolUses) {
            let output = "そのツールは使えない。";
            if (tool.name === "read_repo") {
              if (session.saving) {
                output = "節約中なのでファイルは開かない。";
              } else {
                send({ type: "status", status: "looking" });
                output = await lookupRepo(deps.repo, tool.input);
              }
            } else if (tool.name === "draft_cursor_request") {
              const instruction = String(tool.input?.instruction || "").trim().slice(0, 2000);
              if (!instruction) {
                output = "依頼文が空なので保存していない。";
              } else {
                session.draft = instruction;
                send({ type: "approval", instruction });
                output = "下書きを画面に出した。まだ送っていない。送ったと言ってはいけない。";
              }
            }
            results.push({
              type: "tool_result",
              tool_use_id: tool.id,
              content: output,
            });
          }
          convo.push({ role: "user", content: results });
        }
        send({ type: "done" });
      } catch (error) {
        if (error?.name === "AbortError") return;
        send({ type: "error", message: publicError(error, [deps.apiKey, deps.cursorKey]) });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-cache",
      "access-control-allow-origin": "*",
    },
  });
}

async function updateDraft(request, deps) {
  try {
    const body = await readJson(request);
    const session = sessionFor(body.sessionId);
    const text = String(body.text || "").trim().slice(0, 2000);
    if (!text) return json({ message: "依頼文が空です" }, 400);
    session.draft = text;
    return json({ ok: true });
  } catch (error) {
    return json({ message: publicError(error, [deps.apiKey, deps.cursorKey]) }, 400);
  }
}

async function launch(request, deps) {
  let body;
  try {
    body = await readJson(request);
  } catch (error) {
    return json({ message: publicError(error, []) }, 400);
  }
  let session;
  try {
    session = sessionFor(body.sessionId);
  } catch (error) {
    return json({ message: publicError(error, []) }, 400);
  }
  if (body.buttonApproved !== true || !isApprovalPhrase(body.phrase) || !session.draft) {
    return json({ message: "声の確認と画面の承認が揃うまで送りません" }, 403);
  }
  if (!deps.cursorKey) {
    return json({ message: "中継に CURSOR_API_KEY がありません" }, 500);
  }
  const instruction = session.draft;
  try {
    const agent = await launchCursorAgent({
      baseUrl: deps.cursorBase,
      apiKey: deps.cursorKey,
      instruction,
    });
    session.agents.push({ instruction, url: agent.url, id: agent.id });
    session.draft = null;
    return json({ ok: true, url: agent.url, id: agent.id, instruction });
  } catch (error) {
    return json({ message: publicError(error, [deps.apiKey, deps.cursorKey]) }, 502);
  }
}

async function minutes(request, deps) {
  let body;
  try {
    body = await readJson(request);
  } catch (error) {
    return json({ message: publicError(error, []) }, 400);
  }
  let session;
  try {
    session = sessionFor(body.sessionId);
  } catch (error) {
    return json({ message: publicError(error, []) }, 400);
  }
  const transcript = Array.isArray(body.transcript) ? body.transcript.slice(-40) : [];
  let parsed = null;
  if (deps.apiKey && session.yen < BUDGET_JPY) {
    const dialogue = transcript
      .map((item) => `${item.role === "assistant" ? "VP" : "社長"}: ${String(item.text || "").slice(0, 120)}`)
      .join("\n")
      .slice(0, 2500);
    try {
      const result = await streamMessage({
        apiKey: deps.apiKey,
        baseUrl: deps.anthropicBase,
        body: {
          model: DEFAULT_MODEL,
          max_tokens: 320,
          stream: true,
          thinking: { type: "adaptive" },
          output_config: { effort: "low" },
          system: MINUTES_PROMPT,
          messages: [{ role: "user", content: dialogue || "会話はほとんどなかった。" }],
        },
        signal: request.signal,
      });
      noteUsage(session, DEFAULT_MODEL, result.usage);
      parsed = parseMinutes(result.text);
    } catch {
      parsed = null;
    }
  }
  const local = localMinutes(transcript);
  const points = parsed?.points?.length ? parsed.points : local.points;
  const decisions = parsed?.decisions?.length ? parsed.decisions : local.decisions;
  const todos = parsed?.todos?.length ? parsed.todos : local.todos;
  const requests = session.agents.map((item) => ({ ...item }));
  const markdown = renderMinutes({
    points,
    decisions,
    todos,
    requests,
    yen: session.yen,
    elapsedSec: Number(body.elapsedSec) || 0,
    saving: session.saving,
  });
  return json({
    points,
    decisions,
    todos,
    requests,
    markdown,
    yen: Number(session.yen.toFixed(4)),
    yenLabel: formatYen(session.yen),
    saving: session.saving,
  });
}

export async function handleRequest(request, deps) {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-headers": "content-type",
        "access-control-allow-methods": "GET,POST,OPTIONS",
      },
    });
  }
  if (request.method === "GET" && url.pathname === "/api/health") {
    return json({
      ok: true,
      hasAnthropicKey: Boolean(deps.apiKey),
      hasCursorKey: Boolean(deps.cursorKey),
    });
  }
  if (request.method === "POST" && url.pathname === "/api/chat") return chat(request, deps);
  if (request.method === "POST" && url.pathname === "/api/cursor/draft") return updateDraft(request, deps);
  if (request.method === "POST" && url.pathname === "/api/cursor/launch") return launch(request, deps);
  if (request.method === "POST" && url.pathname === "/api/minutes") return minutes(request, deps);
  return null;
}
