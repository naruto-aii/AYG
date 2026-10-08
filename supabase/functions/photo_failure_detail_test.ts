// 写真で登録の失敗の理由と、縦長の写真がそのままの形で送られることを確かめる。
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleAnalyzeMealPhoto, type AnalyzeDeps, type UsageInsert } from "./analyze-meal-photo/handler.ts";
import {
  AnthropicPhotoProvider,
  describePhotoFailure,
  PhotoAiCallError,
  readAnthropicResult,
} from "./analyze-meal-photo/provider.ts";
import { bytesToBase64, jpegBase64WithinEdge } from "./analyze-meal-photo/image.ts";
import { jpegBytesFromBase64 } from "./analyze-meal-photo/validate.ts";
import { tierCallOptions } from "./analyze-meal-photo/policy.ts";

const secretKey = "sk-test-secret-value";

async function jpeg(width: number, height: number): Promise<Uint8Array> {
  const api = await import("npm:jpeg-js@0.4.4");
  const data = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      // 上半分は赤、下半分は青。上下が切れたり回ったりすると色の配置が変わる。
      data[i] = y < height / 2 ? 220 : 20;
      data[i + 1] = 20;
      data[i + 2] = y < height / 2 ? 20 : 220;
      data[i + 3] = 255;
    }
  }
  return api.encode({ data, width, height }, 80).data;
}

async function decode(bytes: Uint8Array) {
  const api = await import("npm:jpeg-js@0.4.4");
  return api.decode(bytes, { useTArray: true, formatAsRGBA: true });
}

type Sent = { body: Record<string, unknown> };

function fakeFetch(sent: Sent[], status: number, body: unknown) {
  return (_url: string, init?: RequestInit) => {
    sent.push({ body: JSON.parse(String(init?.body)) });
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  };
}

function bentoDeps(
  fetchImpl: ReturnType<typeof fakeFetch>,
  inserts: UsageInsert[],
  logs: string[],
): AnalyzeDeps {
  return {
    env: { ANTHROPIC_API_KEY: secretKey, PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-08T23:29:40Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(true),
    usageRows: () => Promise.resolve([]),
    insertUsage: (row) => {
      inserts.push(row);
      return Promise.resolve("usage-1");
    },
    providerFor: () => new AnthropicPhotoProvider(fetchImpl),
    log: (line) => logs.push(line),
  };
}

function post(body: Record<string, unknown>): Request {
  return new Request("https://example.test/analyze-meal-photo", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: JSON.stringify(body),
  });
}

// 社長の実機と同じ入力。量は数字でない文。
const bentoInput = { dish_name: "豚の生姜焼き弁当", amount: "全体的に少なめだった印象" };

Deno.test("a reply cut off at max_tokens is logged with its reason and real token cost", async () => {
  const portrait = bytesToBase64(await jpeg(768, 1024));
  const sent: Sent[] = [];
  const inserts: UsageInsert[] = [];
  const logs: string[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: portrait, ...bentoInput }),
    bentoDeps(fakeFetch(sent, 200, {
      content: [{ type: "text", text: '{"n":"豚の生姜焼き弁当","a":"少なめ","k":6' }],
      stop_reason: "max_tokens",
      usage: { input_tokens: 1700, output_tokens: 1200 },
    }), inserts, logs),
  );
  assertEquals(response.status, 503);
  assertEquals((await response.json()).code, "provider_error");
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].success, false);
  assertEquals(inserts[0].errorCode, "provider_error");
  assertEquals(inserts[0].inputTokens, 1700);
  assertEquals(inserts[0].outputTokens, 1200);
  assertEquals(inserts[0].estimatedCostJpy > 0, true);
  const line = logs.find((l) => l.startsWith("analyze-meal-photo provider failed"));
  assertEquals(line?.includes("reason=max_tokens"), true);
  assertEquals(line?.includes("stop=max_tokens"), true);
  assertEquals(line?.includes("model=claude-haiku-5-5"), true);
  assertEquals(line?.includes("tier=light"), true);
  assertEquals(line?.includes("max_tokens=1200"), true);
  for (const text of logs) {
    assertEquals(text.includes(secretKey), false);
    assertEquals(text.includes(portrait.slice(0, 40)), false);
    assertEquals(text.includes("生姜焼き"), false);
  }
  // 送った上限は 1200。量が文でも light に回る。
  assertEquals(sent[0].body.max_tokens, 1200);
  assertEquals(sent[0].body.model, "claude-haiku-5-5");
});

Deno.test("an Anthropic error reply is logged with status and error type, without the key", async () => {
  const sent: Sent[] = [];
  const inserts: UsageInsert[] = [];
  const logs: string[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: bytesToBase64(await jpeg(768, 1024)), ...bentoInput }),
    bentoDeps(fakeFetch(sent, 400, {
      type: "error",
      error: { type: "invalid_request_error", message: "messages.0.content.0.image: bad\nimage" },
    }), inserts, logs),
  );
  assertEquals(response.status, 503);
  assertEquals(inserts[0].inputTokens, 0);
  const line = logs.find((l) => l.startsWith("analyze-meal-photo provider failed")) ?? "";
  assertEquals(line.includes("reason=http"), true);
  assertEquals(line.includes("status=400"), true);
  assertEquals(line.includes("type=invalid_request_error"), true);
  assertEquals(line.includes("message=messages.0.content.0.image: bad image"), true);
  assertEquals(line.includes("\n"), false);
  assertEquals(line.includes(secretKey), false);
});

Deno.test("failure reasons cover network, bad json, empty text and keep the old no-arg form", async () => {
  const network = new AnthropicPhotoProvider(() => Promise.reject(new Error("offline")));
  const request = {
    model: "claude-haiku-5-5",
    tier: "light" as const,
    imageJpegBase64: "/9j/2Q==",
    dishName: null,
    amount: null,
    note: null,
    maxTokens: 1200,
    thinking: "off" as const,
    effort: "low",
  };
  try {
    await network.analyze(request, "k");
    throw new Error("should fail");
  } catch (error) {
    assertEquals(error instanceof PhotoAiCallError, true);
    assertEquals((error as PhotoAiCallError).failure.reason, "network");
  }
  const badJson = new AnthropicPhotoProvider(() => Promise.resolve(new Response("<html>", { status: 200 })));
  try {
    await badJson.analyze(request, "k");
    throw new Error("should fail");
  } catch (error) {
    assertEquals((error as PhotoAiCallError).failure.reason, "bad_json");
  }
  try {
    readAnthropicResult({ content: [], stop_reason: "end_turn", usage: { output_tokens: 3 } });
    throw new Error("should fail");
  } catch (error) {
    assertEquals((error as PhotoAiCallError).failure.reason, "empty_text");
    assertEquals((error as PhotoAiCallError).failure.usage?.outputTokens, 3);
  }
  assertEquals(new PhotoAiCallError().failure.reason, "bad_shape");
  assertEquals(
    describePhotoFailure(new PhotoAiCallError({ reason: "network" }).failure, {
      model: "m",
      tier: "heavy",
      maxTokens: 1200,
      imageBytes: 2048,
    }),
    "reason=network status=- type=- stop=- model=m tier=heavy max_tokens=1200 in=0 out=0 image_kb=2",
  );
});

Deno.test("a portrait photo reaches the model whole and upright: 768x1024 is sent unchanged", async () => {
  const bytes = await jpeg(768, 1024);
  const base64 = bytesToBase64(bytes);
  assertEquals(jpegBytesFromBase64(base64) != null, true);
  const edge = tierCallOptions("light", {}).imageMaxEdge;
  assertEquals(await jpegBase64WithinEdge(base64, edge), base64);
  const sent: Sent[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: base64, ...bentoInput }),
    bentoDeps(fakeFetch(sent, 200, {
      content: [{
        type: "text",
        text: JSON.stringify({ n: "豚の生姜焼き弁当", a: "少なめ", k: 600, p: 25, f: 20, c: 80, u: 0.6, h: "", i: [] }),
      }],
      stop_reason: "end_turn",
      usage: { input_tokens: 1700, output_tokens: 120 },
    }), [], []),
  );
  assertEquals(response.status, 200);
  const content = (sent[0].body.messages as Array<{ content: Array<Record<string, unknown>> }>)[0].content;
  const source = content[0].source as { media_type: string; data: string };
  assertEquals(source.media_type, "image/jpeg");
  assertEquals(source.data, base64);
  const seen = await decode(jpegBytesFromBase64(source.data)!);
  assertEquals([seen.width, seen.height], [768, 1024]);
});

Deno.test("a larger portrait photo is shrunk without cropping or turning it", async () => {
  const base64 = bytesToBase64(await jpeg(1536, 2048));
  const out = await jpegBase64WithinEdge(base64, 1024);
  const seen = await decode(jpegBytesFromBase64(out)!);
  assertEquals([seen.width, seen.height], [768, 1024]);
  const top = (10 * seen.width + 384) * 4;
  const bottom = ((seen.height - 10) * seen.width + 384) * 4;
  assertEquals(seen.data[top] > 150 && seen.data[top + 2] < 80, true);
  assertEquals(seen.data[bottom + 2] > 150 && seen.data[bottom] < 80, true);
});
