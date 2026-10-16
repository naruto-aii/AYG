import http from "node:http";

export function sse(res, events) {
  res.writeHead(200, { "content-type": "text/event-stream" });
  for (const event of events) res.write(`data: ${JSON.stringify(event)}\n\n`);
  res.end();
}

export function textTurn(text, usage = {}) {
  return [
    {
      type: "message_start",
      message: {
        usage: {
          input_tokens: usage.input ?? 100,
          output_tokens: 0,
          cache_read_input_tokens: usage.cacheRead ?? 0,
          cache_creation_input_tokens: usage.cacheWrite ?? 0,
        },
      },
    },
    { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
    { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: text.slice(0, 6) } },
    { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: text.slice(6) } },
    { type: "content_block_stop", index: 0 },
    {
      type: "message_delta",
      delta: { stop_reason: "end_turn" },
      usage: { output_tokens: usage.output ?? 20 },
    },
    { type: "message_stop" },
  ];
}

export function toolTurn(name, input) {
  return [
    { type: "message_start", message: { usage: { input_tokens: 80, output_tokens: 0 } } },
    {
      type: "content_block_start",
      index: 0,
      content_block: { type: "tool_use", id: "toolu_test", name, input: {} },
    },
    {
      type: "content_block_delta",
      index: 0,
      delta: { type: "input_json_delta", partial_json: JSON.stringify(input) },
    },
    { type: "content_block_stop", index: 0 },
    { type: "message_delta", delta: { stop_reason: "tool_use" }, usage: { output_tokens: 12 } },
    { type: "message_stop" },
  ];
}

function readBody(req) {
  return new Promise((resolve) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
    });
    req.on("end", () => resolve(raw));
  });
}

export function listen(handler) {
  const server = http.createServer(handler);
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve({ server, url: `http://127.0.0.1:${port}` });
    });
  });
}

export async function startAnthropic() {
  const calls = [];
  const { server, url } = await listen(async (req, res) => {
    const json = JSON.parse((await readBody(req)) || "{}");
    calls.push({ key: req.headers["x-api-key"], body: json });
    const system = JSON.stringify(json.system || "");
    if (system.includes("議事録")) {
      sse(res, textTurn('{"points":["食事の記録"],"decisions":["今日あとに揃える"],"todos":["結果を見る"]}'));
      return;
    }
    const last = json.messages.at(-1);
    if (Array.isArray(last?.content)) {
      const blob = JSON.stringify(last.content);
      if (blob.includes("下書き")) {
        sse(res, textTurn("依頼はこの内容でいい？"));
        return;
      }
      if (blob.includes("読まない")) {
        sse(res, textTurn("見ていないよ。"));
        return;
      }
      sse(res, textTurn("カロナビは、食事と運動と体重を記録するアプリだよ。"));
      return;
    }
    const user = String(last?.content || "");
    if (/Cursor|頼ん/.test(user)) {
      sse(res, toolTurn("draft_cursor_request", { instruction: "ホームの今日あと、の文言を揃える" }));
      return;
    }
    if (/秘密/.test(user)) {
      sse(res, toolTurn("read_repo", { path: ".env" }));
      return;
    }
    if (/リポジトリ|何をして/.test(user)) {
      sse(res, toolTurn("read_repo", { path: "README.md" }));
      return;
    }
    const output = /長い/.test(user) ? 100000 : 20;
    sse(res, textTurn(/長い/.test(user) ? "まだ話すね。" : "うん、聞いてるよ。", { output }));
  });
  return { server, url, calls };
}

export async function startCursor() {
  const calls = [];
  const { server, url } = await listen(async (req, res) => {
    const body = JSON.parse((await readBody(req)) || "{}");
    calls.push({ auth: req.headers.authorization || "", body, url: req.url });
    res.writeHead(200, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        agent: {
          id: "bc-test",
          url: "https://cursor.com/agents/bc-test",
          status: "ACTIVE",
        },
        run: { id: "run-test", status: "CREATING" },
      }),
    );
  });
  return { server, url, calls };
}
