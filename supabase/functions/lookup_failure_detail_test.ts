// AIで探すの失敗理由と max_tokens。本物の AI は呼ばず、fetch をモックする。
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleLookupFoodText, type LookupDeps, type UsageInsert } from "./lookup-food-text/handler.ts";
import { textLookupLimitsFromEnv } from "./lookup-food-text/policy.ts";
import { callLookupModel, describeLookupFailure, LookupCallError } from "./lookup-food-text/provider.ts";

const usage = { input_tokens: 900, output_tokens: 800, cache_read_input_tokens: 0 };

function fakeFetch(status: number, body: unknown, seen?: Array<Record<string, unknown>>) {
  return (_url: string, init?: RequestInit) => {
    seen?.push(JSON.parse(String(init?.body ?? "{}")));
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  };
}

async function failureOf(promise: Promise<unknown>): Promise<LookupCallError> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof LookupCallError) return error;
    throw error;
  }
  throw new Error("expected LookupCallError");
}

Deno.test("max_tokens defaults to 800 and a smaller env value is raised to 800", () => {
  assertEquals(textLookupLimitsFromEnv({}).maxTokens, 800);
  assertEquals(textLookupLimitsFromEnv({ TEXT_AI_MAX_TOKENS: "300" }).maxTokens, 800);
  assertEquals(textLookupLimitsFromEnv({ TEXT_AI_MAX_TOKENS: "1500" }).maxTokens, 1500);
});

Deno.test("the request sends the raised max_tokens", async () => {
  const seen: Array<Record<string, unknown>> = [];
  const result = await callLookupModel({
    model: "claude-haiku-5-5",
    maxTokens: textLookupLimitsFromEnv({}).maxTokens,
    query: "牛丼",
    apiKey: "test-key",
    fetchImpl: fakeFetch(200, {
      stop_reason: "end_turn",
      content: [{ type: "text", text: '{"i":[]}' }],
      usage,
    }, seen),
  });
  assertEquals(seen[0].max_tokens, 800);
  assertEquals(result.usage.outputTokens, 800);
});

Deno.test("a cut-off answer is reported as max_tokens with its usage", async () => {
  const error = await failureOf(callLookupModel({
    model: "claude-haiku-5-5",
    maxTokens: 800,
    query: "牛丼",
    apiKey: "test-key",
    fetchImpl: fakeFetch(200, {
      stop_reason: "max_tokens",
      content: [{ type: "text", text: '{"i":[{"n":"牛' }],
      usage,
    }),
  }));
  assertEquals(error.failure.reason, "max_tokens");
  assertEquals(error.failure.stopReason, "max_tokens");
  assertEquals(error.failure.usage?.outputTokens, 800);
});

Deno.test("http, network, broken body and empty text each name their reason", async () => {
  const http = await failureOf(callLookupModel({
    model: "m",
    maxTokens: 800,
    query: "q",
    apiKey: "k",
    fetchImpl: fakeFetch(529, { error: { type: "overloaded_error", message: "Overloaded" } }),
  }));
  assertEquals([http.failure.reason, http.failure.status, http.failure.errorType], ["http", 529, "overloaded_error"]);
  const network = await failureOf(callLookupModel({
    model: "m",
    maxTokens: 800,
    query: "q",
    apiKey: "k",
    fetchImpl: () => Promise.reject(new Error("down")),
  }));
  assertEquals(network.failure.reason, "network");
  const broken = await failureOf(callLookupModel({
    model: "m",
    maxTokens: 800,
    query: "q",
    apiKey: "k",
    fetchImpl: () => Promise.resolve(new Response("not json", { status: 200 })),
  }));
  assertEquals(broken.failure.reason, "bad_json");
  const empty = await failureOf(callLookupModel({
    model: "m",
    maxTokens: 800,
    query: "q",
    apiKey: "k",
    fetchImpl: fakeFetch(200, { stop_reason: "end_turn", content: [], usage }),
  }));
  assertEquals(empty.failure.reason, "empty_text");
  const noKey = await failureOf(callLookupModel({
    model: "m",
    maxTokens: 800,
    query: "q",
    apiKey: " ",
    fetchImpl: fakeFetch(200, {}),
  }));
  assertEquals(noKey.failure.reason, "missing_key");
});

function depsFailing(error: Error, logs: string[], inserts: UsageInsert[]): LookupDeps {
  return {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-08T03:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    usage: () => Promise.resolve({ dayCount: 0, monthCount: 0, monthSpendJpy: 0 }),
    readCache: () => Promise.resolve(null),
    writeCache: () => Promise.resolve(),
    insertUsage: (row) => {
      inserts.push(row);
      return Promise.resolve("usage-1");
    },
    complete: () => Promise.reject(error),
    log: (message) => logs.push(message),
  };
}

function post(query: string): Request {
  return new Request("https://example.test/lookup-food-text", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: JSON.stringify({ query }),
  });
}

Deno.test("a cut-off answer still answers provider_error, but the log names the cause and the cost is kept", async () => {
  const logs: string[] = [];
  const inserts: UsageInsert[] = [];
  const response = await handleLookupFoodText(
    post("吉野家 牛丼 大盛"),
    depsFailing(
      new LookupCallError({
        reason: "max_tokens",
        status: 200,
        stopReason: "max_tokens",
        usage: { inputTokens: 900, outputTokens: 800, cacheReadTokens: 0, cacheWriteTokens: 0 },
      }),
      logs,
      inserts,
    ),
  );
  const body = await response.json();
  assertEquals([response.status, body.code], [503, "provider_error"]);
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].errorCode, "provider_error");
  assertEquals(inserts[0].outputTokens, 800);
  assertEquals(inserts[0].estimatedCostJpy > 0, true);
  const line = logs.find((log) => log.startsWith("lookup-food-text provider failed:"));
  assertEquals(
    line,
    "lookup-food-text provider failed: reason=max_tokens status=200 type=- stop=max_tokens model=claude-haiku-5-5 max_tokens=800 in=900 out=800",
  );
  assertEquals(logs.join("\n").includes("吉野家"), false);
  assertEquals(logs.join("\n").includes("test-key"), false);
});

Deno.test("describeLookupFailure keeps the message short and on one line", () => {
  const text = describeLookupFailure(
    new LookupCallError({ reason: "http", status: 400, errorType: "invalid_request_error", errorMessage: "bad" }).failure,
    { model: "m", maxTokens: 800 },
  );
  assertEquals(text, "reason=http status=400 type=invalid_request_error stop=- model=m max_tokens=800 in=0 out=0 message=bad");
});
