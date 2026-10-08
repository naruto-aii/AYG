import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { downscaleJpeg } from "./analyze-meal-photo/image.ts";
import { photoMealMessage } from "./analyze-meal-photo/messages.ts";
import {
  checkPhotoCaps,
  defaultPhotoLimits,
  estimateCostJpy,
  photoLimitsFromEnv,
  routePhotoModel,
  summarizeUsage,
  tierCallOptions,
  tokenPricesFromEnv,
  tokyoDateKey,
  tokyoMonthStartUtc,
  type UsageRow,
} from "./analyze-meal-photo/policy.ts";
import {
  anthropicBody,
  AnthropicPhotoProvider,
  createPhotoAiProvider,
  readAnthropicResult,
  thinkingField,
  userPrompt,
} from "./analyze-meal-photo/provider.ts";
import {
  jpegBytesFromBase64,
  mealEstimateSchema,
  parsePhotoMealEstimate,
} from "./analyze-meal-photo/validate.ts";
import {
  handleAnalyzeMealPhoto,
  type AnalyzeDeps,
  type PhotoEnv,
  type UsageInsert,
} from "./analyze-meal-photo/handler.ts";
import type { PhotoAiRequest } from "./analyze-meal-photo/provider.ts";

const tinyJpeg = "/9j/2Q==";

function validEstimate(overrides: Record<string, unknown> = {}) {
  return {
    dish_name: "親子丼",
    amount: "1杯",
    kcal: 290,
    protein_g: 20,
    fat_g: 10,
    carb_g: 30,
    confidence: 0.7,
    items: [],
    ...overrides,
  };
}

Deno.test("all three inputs use the light model", () => {
  assertEquals(
    routePhotoModel({
      hasName: true,
      hasAmount: true,
      heavyMonthCount: 0,
      heavyMonthlyLimit: 20,
    }),
    { kind: "model", tier: "light" },
  );
});

Deno.test("a missing name or amount uses the heavy model", () => {
  for (const input of [
    { hasName: false, hasAmount: true },
    { hasName: true, hasAmount: false },
    { hasName: false, hasAmount: false },
  ]) {
    assertEquals(
      routePhotoModel({
        ...input,
        heavyMonthCount: 19,
        heavyMonthlyLimit: 20,
      }),
      { kind: "model", tier: "heavy" },
    );
  }
});

Deno.test("after 20 heavy uses, a missing field does not call the heavy model", () => {
  assertEquals(
    routePhotoModel({
      hasName: false,
      hasAmount: true,
      heavyMonthCount: 20,
      heavyMonthlyLimit: 20,
    }),
    { kind: "need_details" },
  );
  assertEquals(
    routePhotoModel({
      hasName: true,
      hasAmount: true,
      heavyMonthCount: 20,
      heavyMonthlyLimit: 20,
    }),
    { kind: "model", tier: "light" },
  );
});

Deno.test("placeholder cap defaults are env-overridable and not a fixed product decision", () => {
  const base = {
    dayCount: 0,
    monthCount: 0,
    heavyMonthCount: 0,
    monthSpendJpy: 0,
  };
  assertEquals(checkPhotoCaps(base, defaultPhotoLimits), null);
  assertEquals(
    checkPhotoCaps({ ...base, dayCount: defaultPhotoLimits.daily }, defaultPhotoLimits),
    "daily_cap",
  );
  assertEquals(
    checkPhotoCaps({ ...base, monthCount: defaultPhotoLimits.monthly }, defaultPhotoLimits),
    "monthly_cap",
  );
  assertEquals(
    checkPhotoCaps({
      ...base,
      monthSpendJpy: defaultPhotoLimits.spendJpy,
    }, defaultPhotoLimits),
    "spend_cap",
  );
  const tuned = photoLimitsFromEnv({
    PHOTO_AI_DAILY_LIMIT: "2",
    PHOTO_AI_MONTHLY_LIMIT: "7",
    PHOTO_AI_HEAVY_MONTHLY_LIMIT: "3",
    PHOTO_AI_MONTHLY_SPEND_JPY: "4.5",
  });
  assertEquals(tuned, { daily: 2, monthly: 7, heavyMonthly: 3, spendJpy: 4.5 });
  assertEquals(
    photoMealMessage("daily_cap", tuned),
    "きょうの写真での登録は、2回までです。手入力で記録できます。",
  );
  assertEquals(
    photoMealMessage("monthly_cap", tuned),
    "今月の写真での登録は、7回までです。手入力で記録できます。",
  );
});

Deno.test("tokyo day rolls at 15:00 UTC", () => {
  const before = new Date("2026-10-07T14:59:00Z");
  const after = new Date("2026-10-07T15:00:00Z");
  assertEquals(tokyoDateKey(before), "2026-10-07");
  assertEquals(tokyoDateKey(after), "2026-10-08");
  assertEquals(
    tokyoMonthStartUtc(after).toISOString(),
    "2026-09-30T15:00:00.000Z",
  );
  const rows: UsageRow[] = [
    { createdAt: before.toISOString(), tier: "heavy", costJpy: 2 },
    { createdAt: after.toISOString(), tier: "light", costJpy: 0.5 },
  ];
  assertEquals(summarizeUsage(rows, after), {
    dayCount: 1,
    monthCount: 2,
    heavyMonthCount: 1,
    monthSpendJpy: 2.5,
  });
});

Deno.test("cost uses API usage fields, cache tokens, and web search", () => {
  const prices = tokenPricesFromEnv("light", {});
  assertEquals(prices.inputJpyPerMillion, 15.8);
  assertEquals(prices.outputJpyPerMillion, 79);
  assertEquals(prices.cacheReadJpyPerMillion, 1.58);
  assertEquals(prices.cacheWriteJpyPerMillion, 19.75);
  assertEquals(prices.webSearchJpy, 1.58);
  const cost = estimateCostJpy({
    inputTokens: 1_000,
    outputTokens: 1_000,
    cacheReadTokens: 1_000,
    cacheWriteTokens: 1_000,
    webSearchRequests: 1,
    prices,
  });
  const expected = (1000 * 15.8 + 1000 * 79 + 1000 * 1.58 + 1000 * 19.75) / 1_000_000 + 1.58;
  assertEquals(Math.round(cost * 1000) / 1000, Math.round(expected * 1000) / 1000);
  const long = estimateCostJpy({
    inputTokens: 100_001,
    outputTokens: 0,
    cacheReadTokens: 1_000,
    cacheWriteTokens: 0,
    webSearchRequests: 0,
    prices,
  });
  const longExpected = (100_001 * 15.8 * 5 + 1_000 * 1.58) / 1_000_000;
  assertEquals(Math.round(long * 1000) / 1000, Math.round(longExpected * 1000) / 1000);
  const heavy = tokenPricesFromEnv("heavy", {});
  assertEquals(heavy.inputJpyPerMillion, 316);
  assertEquals(heavy.cacheReadJpyPerMillion, 15.8);
  assertEquals(heavy.cacheWriteJpyPerMillion, 395);
});

Deno.test("json validation rejects negative, absurd, and inconsistent values", () => {
  assertEquals(parsePhotoMealEstimate(validEstimate()), {
    dishName: "親子丼",
    amount: "1杯",
    kcal: 290,
    proteinG: 20,
    fatG: 10,
    carbG: 30,
    confidence: 0.7,
    items: [],
  });
  assertEquals(
    parsePhotoMealEstimate(validEstimate({ protein_g: -1 })),
    null,
  );
  assertEquals(parsePhotoMealEstimate(validEstimate({ kcal: 50_000 })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ kcal: 2_000 })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ dish_name: "  " })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ confidence: 1.2 })), null);
  assertEquals(
    parsePhotoMealEstimate(validEstimate({
      items: [{
        name: "ご飯",
        amount: "150g",
        kcal: 500,
        protein_g: 0,
        fat_g: 0,
        carb_g: 0,
      }],
    })),
    null,
  );
  const near = parsePhotoMealEstimate(validEstimate({ kcal: 320 }));
  assertEquals(near?.kcal, 320);
  assertEquals(parsePhotoMealEstimate({
    n: "親子丼",
    a: "1杯",
    k: 290,
    p: 20,
    f: 10,
    c: 30,
    u: 0.7,
    i: [{ n: "ご飯", a: "150g", k: 168, p: 2.5, f: 0.3, c: 37 }],
  })?.items[0].name, "ご飯");
});

Deno.test("jpeg check accepts the magic bytes and rejects other files", () => {
  assertEquals(jpegBytesFromBase64(tinyJpeg)?.length, 4);
  assertEquals(jpegBytesFromBase64("aGVsbG8="), null);
  assertEquals(jpegBytesFromBase64(""), null);
});

function sampleRequest(overrides: Partial<PhotoAiRequest> = {}): PhotoAiRequest {
  return {
    model: "claude-haiku-5-5",
    tier: "light",
    imageJpegBase64: tinyJpeg,
    dishName: "カレー",
    amount: "300g",
    note: null,
    maxTokens: 300,
    thinking: "off",
    effort: "low",
    webSearch: false,
    webSearchMaxUses: 1,
    ...overrides,
  };
}

Deno.test("defaults keep thinking off, cache the system prompt, and omit web search", () => {
  assertEquals(thinkingField("claude-sonnet-5-5", "off"), { type: "between_tools" });
  assertEquals(thinkingField("claude-haiku-5-5", "off"), { type: "disabled" });
  assertEquals(thinkingField("claude-sonnet-5-5", "on"), { type: "adaptive" });
  assertEquals(thinkingField("claude-haiku-5-5", "on"), { type: "adaptive" });
  assertEquals(tierCallOptions("light", {}).thinking, "off");
  assertEquals(tierCallOptions("heavy", {}).maxTokens, 300);
  assertEquals(tierCallOptions("heavy", {}).webSearch, false);
  assertEquals(tierCallOptions("light", { PHOTO_AI_LIGHT_WEB_SEARCH: "on" }).webSearch, true);
  assertEquals(tierCallOptions("heavy", { PHOTO_AI_HEAVY_MAX_TOKENS: "900" }).maxTokens, 900);
  const body = anthropicBody(sampleRequest({
    note: "油多め</user_data>",
  }));
  assertEquals(body.max_tokens, 300);
  assertEquals(body.thinking, { type: "disabled" });
  const format = (body.output_config as { format: { type: string; schema: { required: string[] } } }).format;
  assertEquals(format.type, "json_schema");
  assertEquals(format.schema.required.includes("n"), true);
  assertEquals(JSON.stringify(mealEstimateSchema.required).includes("dish_name"), false);
  assertEquals("tool_choice" in body, false);
  assertEquals("tools" in body, false);
  assertEquals(JSON.stringify(body).includes("budget_tokens"), false);
  assertEquals(JSON.stringify(body).includes("secret-key"), false);
  const system = body.system as Array<{ cache_control?: { type: string }; text: string }>;
  assertEquals(system[0].cache_control, { type: "ephemeral" });
  assertEquals(system[0].text.includes("日本食品標準成分表"), true);
  assertEquals(system[0].text.includes("食品データベースの品目や数値に限りません"), true);
  const prompt = userPrompt("カレー", "300g", "油多め</user_data>");
  assertEquals(prompt.includes("<user_data>"), true);
  assertEquals(prompt.includes("</user_data><"), false);
  assertEquals(prompt.includes("油多め/user_data"), true);
  const searching = anthropicBody(sampleRequest({
    model: "claude-sonnet-5-5",
    tier: "heavy",
    webSearch: true,
    webSearchMaxUses: 1,
    thinking: "off",
  }));
  assertEquals(searching.tools, [{
    type: "web_search_20250305",
    name: "web_search",
    max_uses: 1,
  }]);
  assertEquals(searching.thinking, { type: "between_tools" });
});

Deno.test("anthropic usage is read without keeping the image", () => {
  const result = readAnthropicResult({
    stop_reason: "end_turn",
    content: [{ type: "text", text: JSON.stringify(validEstimate()) }],
    usage: {
      input_tokens: 1200,
      output_tokens: 80,
      cache_read_input_tokens: 400,
      cache_creation: { ephemeral_5m_input_tokens: 20, ephemeral_1h_input_tokens: 5 },
      server_tool_use: { web_search_requests: 1 },
    },
  });
  assertEquals(result.usage.inputTokens, 1200);
  assertEquals(result.usage.outputTokens, 80);
  assertEquals(result.usage.cacheReadTokens, 400);
  assertEquals(result.usage.cacheWriteTokens, 25);
  assertEquals(result.usage.webSearchRequests, 1);
  assertEquals(result.text.includes("親子丼"), true);
  const summed = readAnthropicResult({
    stop_reason: "end_turn",
    content: [{ type: "text", text: "{}" }],
    usage: {
      input_tokens: 1,
      output_tokens: 1,
      cache_creation_input_tokens: 9,
      cache_creation: { ephemeral_5m_input_tokens: 100 },
    },
  });
  assertEquals(summed.usage.cacheWriteTokens, 9);
});

type FakeCall = PhotoAiRequest;

function deps(options: {
  plus?: boolean;
  rows?: UsageRow[];
  key?: string;
  provider?: string;
  calls?: FakeCall[];
  inserts?: UsageInsert[];
  text?: string;
  failCall?: boolean;
  env?: PhotoEnv;
}): AnalyzeDeps {
  const calls = options.calls ?? [];
  const inserts = options.inserts ?? [];
  return {
    env: {
      ANTHROPIC_API_KEY: options.key ?? "test-key",
      PHOTO_AI_PROVIDER: options.provider ?? "anthropic",
      ...options.env,
    },
    now: () => new Date("2026-10-08T03:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(options.plus ?? true),
    usageRows: () => Promise.resolve(options.rows ?? []),
    insertUsage: (row) => {
      inserts.push(row);
      return Promise.resolve("usage-1");
    },
    providerFor: (name) => {
      if ((options.provider ?? "anthropic") !== "anthropic") {
        return createPhotoAiProvider(name);
      }
      return {
      id: "anthropic",
      analyze: (request: PhotoAiRequest) => {
        calls.push(request);
        if (options.failCall) {
          return Promise.reject(new Error("network"));
        }
        return Promise.resolve({
          text: options.text ?? JSON.stringify(validEstimate()),
          usage: {
            inputTokens: 1000,
            outputTokens: 40,
            cacheReadTokens: 0,
            cacheWriteTokens: 0,
            webSearchRequests: 0,
          },
        });
      },
    };
    },
    log: () => {},
  };
}

function post(body: Record<string, unknown>): Request {
  return new Request("https://example.test/analyze-meal-photo", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: JSON.stringify(body),
  });
}

Deno.test("a complete request calls the light model and logs one row", async () => {
  const calls: FakeCall[] = [];
  const inserts: UsageInsert[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "カレー", amount: "300g" }),
    deps({ calls, inserts }),
  );
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.ok, true);
  assertEquals(body.usage_id, "usage-1");
  assertEquals(body.estimate.dish_name, "親子丼");
  assertEquals(calls.length, 1);
  assertEquals(calls[0].model, "claude-haiku-5-5");
  assertEquals(calls[0].tier, "light");
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].success, true);
  assertEquals(inserts[0].hadName, true);
  assertEquals(inserts[0].hadAmount, true);
  assertEquals(inserts[0].hadNote, false);
  assertEquals(calls[0].note, null);
  assertEquals(calls[0].maxTokens, 300);
  assertEquals(calls[0].thinking, "off");
  assertEquals(calls[0].webSearch, false);
  assertEquals(JSON.stringify(inserts[0]).includes(tinyJpeg), false);
});

Deno.test("a note does not change routing and is not stored", async () => {
  const withNote: FakeCall[] = [];
  const noted: UsageInsert[] = [];
  await handleAnalyzeMealPhoto(
    post({
      image_base64: tinyJpeg,
      dish_name: "カレー",
      amount: "300g",
      note: "油多め",
    }),
    deps({ calls: withNote, inserts: noted }),
  );
  assertEquals(withNote[0].tier, "light");
  assertEquals(withNote[0].note, "油多め");
  assertEquals(noted[0].hadNote, true);
  assertEquals(JSON.stringify(noted[0]).includes("油多め"), false);

  const missing: FakeCall[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, note: "揚げ物" }),
    deps({ calls: missing }),
  );
  assertEquals(response.status, 200);
  assertEquals(missing[0].tier, "heavy");
  assertEquals(missing[0].dishName, null);
  assertEquals(missing[0].note, "揚げ物");
});

Deno.test("a photo without a name calls the heavy model", async () => {
  const calls: FakeCall[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "  ", amount: "1杯" }),
    deps({ calls }),
  );
  assertEquals(response.status, 200);
  assertEquals(calls[0].model, "claude-sonnet-5-5");
  assertEquals(calls[0].tier, "heavy");
  assertEquals(calls[0].dishName, null);
});

Deno.test("the heavy monthly cap asks for a name and amount and does not call", async () => {
  const calls: FakeCall[] = [];
  const inserts: UsageInsert[] = [];
  const rows: UsageRow[] = Array.from({ length: 20 }, () => ({
    createdAt: "2026-10-02T00:00:00Z",
    tier: "heavy" as const,
    costJpy: 1,
  }));
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg }),
    deps({ calls, inserts, rows }),
  );
  const body = await response.json();
  assertEquals(response.status, 429);
  assertEquals(body.code, "need_details");
  assertEquals(body.message, "料理名と量を入れると、引き続き写真で登録できます。");
  assertEquals(calls.length, 0);
  assertEquals(inserts.length, 0);
});

Deno.test("caps and a missing key do not call the model", async () => {
  const calls: FakeCall[] = [];
  const daily = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({
      calls,
      rows: Array.from({ length: 10 }, () => ({
        createdAt: "2026-10-08T01:00:00Z",
        tier: "light" as const,
        costJpy: 0.1,
      })),
    }),
  );
  assertEquals((await daily.json()).code, "daily_cap");
  const spend = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({
      calls,
      rows: [{
        createdAt: "2026-10-01T00:00:00Z",
        tier: "light",
        costJpy: defaultPhotoLimits.spendJpy,
      }],
    }),
  );
  assertEquals((await spend.json()).code, "spend_cap");
  const missing = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({ calls, key: "  " }),
  );
  const missingBody = await missing.json();
  assertEquals(missing.status, 503);
  assertEquals(missingBody.message.includes("手入力"), true);
  assertEquals(calls.length, 0);
});

Deno.test("plus is checked on the server and a bad estimate is not returned", async () => {
  const unpaid = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({ plus: false }),
  );
  assertEquals((await unpaid.json()).code, "not_plus");
  const inserts: UsageInsert[] = [];
  const bad = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({ inserts, text: JSON.stringify(validEstimate({ kcal: -5 })) }),
  );
  assertEquals((await bad.json()).code, "invalid_result");
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].success, false);
});

Deno.test("configured caps replace the placeholder defaults", async () => {
  const calls: FakeCall[] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({
      calls,
      env: { PHOTO_AI_DAILY_LIMIT: "1" },
      rows: [{
        createdAt: "2026-10-08T01:00:00Z",
        tier: "light",
        costJpy: 0.1,
      }],
    }),
  );
  const body = await response.json();
  assertEquals(body.code, "daily_cap");
  assertEquals(body.message, "きょうの写真での登録は、1回までです。手入力で記録できます。");
  assertEquals(calls.length, 0);
});

Deno.test("pause_turn continues and web search usage is summed", async () => {
  let calls = 0;
  const seen: Array<Record<string, unknown>> = [];
  const fetchImpl: typeof fetch = (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    calls += 1;
    const payload = calls === 1
      ? {
        stop_reason: "pause_turn",
        content: [{
          type: "server_tool_use",
          id: "srvtoolu_1",
          name: "web_search",
          input: { query: "親子丼 栄養" },
        }],
        usage: {
          input_tokens: 10,
          output_tokens: 4,
          server_tool_use: { web_search_requests: 1 },
        },
      }
      : {
        stop_reason: "end_turn",
        content: [
          { type: "text", text: "公式サイトでは" },
          { type: "text", text: JSON.stringify(validEstimate()) },
        ],
        usage: { input_tokens: 3, output_tokens: 8 },
      };
    return Promise.resolve(new Response(JSON.stringify(payload), { status: 200 }));
  };
  const result = await new AnthropicPhotoProvider(fetchImpl).analyze(
    sampleRequest({ webSearch: true, model: "claude-sonnet-5-5", tier: "heavy" }),
    "test-key",
  );
  assertEquals(calls, 2);
  assertEquals(result.usage.inputTokens, 13);
  assertEquals(result.usage.webSearchRequests, 1);
  assertEquals(result.text.includes("親子丼"), true);
  const second = seen[1].messages as Array<{ role: string; content: unknown }>;
  assertEquals(second[1].role, "assistant");
  assertEquals(JSON.stringify(second[1].content).includes("srvtoolu_1"), true);
  assertEquals(seen[0].tools != null, true);
});

Deno.test("a wide jpeg is shrunk to the tier max edge", async () => {
  const api = await import("npm:jpeg-js@0.4.4");
  const width = 8;
  const height = 4;
  const data = new Uint8Array(width * height * 4);
  for (let i = 0; i < data.length; i += 4) {
    data[i] = 200;
    data[i + 1] = 80;
    data[i + 2] = 40;
    data[i + 3] = 255;
  }
  const encoded = api.encode({ data, width, height }, 80);
  const scaled = await downscaleJpeg(encoded.data, 4);
  const decoded = api.decode(scaled, { useTArray: true });
  assertEquals(Math.max(decoded.width, decoded.height) <= 4, true);
  const unchanged = await downscaleJpeg(encoded.data, 1024);
  assertEquals(unchanged, encoded.data);
});

Deno.test("an unwired provider fails closed in Japanese", async () => {
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({ provider: "gemini" }),
  );
  const body = await response.json();
  assertEquals(response.status, 503);
  assertEquals(body.code, "provider_unwired");
  assertEquals(body.message.includes("手入力"), true);
});
