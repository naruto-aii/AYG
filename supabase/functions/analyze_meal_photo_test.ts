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
  validatePhotoMealEstimate,
} from "./analyze-meal-photo/validate.ts";
import type { FoodCollectionRow } from "./ai-food-collection.ts";
import {
  handleAnalyzeMealPhoto,
  liveDeps,
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

Deno.test("the shared daily cap is 15 and monthly spend stays off until set", () => {
  const base = {
    dayCount: 0,
    monthCount: 0,
    heavyMonthCount: 0,
    monthSpendJpy: 0,
  };
  assertEquals(defaultPhotoLimits.daily, 15);
  assertEquals(defaultPhotoLimits.monthly, null);
  assertEquals(defaultPhotoLimits.spendJpy, null);
  assertEquals(checkPhotoCaps(base, defaultPhotoLimits), null);
  assertEquals(
    checkPhotoCaps({ ...base, dayCount: 14, monthCount: 500, monthSpendJpy: 9999 }, defaultPhotoLimits),
    null,
  );
  assertEquals(
    checkPhotoCaps({ ...base, dayCount: 15 }, defaultPhotoLimits),
    "daily_cap",
  );
  assertEquals(photoMealMessage("daily_cap"), "本日の上限に達しました");
  const tuned = photoLimitsFromEnv({
    AI_COMBINED_DAILY_LIMIT: "4",
    PHOTO_AI_DAILY_LIMIT: "2",
    PHOTO_AI_MONTHLY_LIMIT: "7",
    PHOTO_AI_HEAVY_MONTHLY_LIMIT: "3",
    PHOTO_AI_MONTHLY_SPEND_JPY: "4.5",
  });
  assertEquals(tuned, { daily: 4, monthly: 7, heavyMonthly: 3, spendJpy: 4.5 });
  assertEquals(
    checkPhotoCaps({ ...base, monthCount: 7 }, tuned),
    "monthly_cap",
  );
  assertEquals(
    checkPhotoCaps({ ...base, monthSpendJpy: 4.5 }, tuned),
    "spend_cap",
  );
  assertEquals(
    photoMealMessage("monthly_cap", { monthly: tuned.monthly ?? undefined }),
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

Deno.test("cost uses API usage fields and cache tokens", () => {
  const prices = tokenPricesFromEnv("light", {});
  assertEquals(prices.inputJpyPerMillion, 15.8);
  assertEquals(prices.outputJpyPerMillion, 79);
  assertEquals(prices.cacheReadJpyPerMillion, 1.58);
  assertEquals(prices.cacheWriteJpyPerMillion, 19.75);
  const cost = estimateCostJpy({
    inputTokens: 1_000,
    outputTokens: 1_000,
    cacheReadTokens: 1_000,
    cacheWriteTokens: 1_000,
    prices,
  });
  const expected = (1000 * 15.8 + 1000 * 79 + 1000 * 1.58 + 1000 * 19.75) / 1_000_000;
  assertEquals(Math.round(cost * 1000) / 1000, Math.round(expected * 1000) / 1000);
  const long = estimateCostJpy({
    inputTokens: 100_001,
    outputTokens: 0,
    cacheReadTokens: 1_000,
    cacheWriteTokens: 0,
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
    chainName: null,
    items: [],
  });
  assertEquals(
    parsePhotoMealEstimate(validEstimate({ h: "吉野家" }))?.chainName,
    "吉野家",
  );
  assertEquals(
    parsePhotoMealEstimate(validEstimate({ protein_g: -1 })),
    null,
  );
  assertEquals(parsePhotoMealEstimate(validEstimate({ kcal: 50_000 })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ kcal: 2_000 })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ dish_name: "  " })), null);
  assertEquals(parsePhotoMealEstimate(validEstimate({ confidence: 1.2 }))?.confidence, 1);
  assertEquals(parsePhotoMealEstimate(validEstimate({ confidence: 70 }))?.confidence, 0.7);
  assertEquals(parsePhotoMealEstimate(validEstimate({ confidence: 500 })), null);
  // PFC が 0 で kcal だけある品目は、全体を落とさず、その品目だけ外す。
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
    }))?.items,
    [],
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
    ...overrides,
  };
}

Deno.test("defaults keep thinking off, cache the system prompt, and send no tools", () => {
  assertEquals(thinkingField("claude-sonnet-5-5", "off"), { type: "between_tools" });
  assertEquals(thinkingField("claude-haiku-5-5", "off"), { type: "disabled" });
  assertEquals(thinkingField("claude-sonnet-5-5", "on"), { type: "adaptive" });
  assertEquals(thinkingField("claude-haiku-5-5", "on"), { type: "adaptive" });
  assertEquals(tierCallOptions("light", {}).thinking, "off");
  assertEquals(tierCallOptions("heavy", {}).maxTokens, 1200);
  assertEquals(tierCallOptions("light", {}).maxTokens, 1200);
  assertEquals(tierCallOptions("heavy", { PHOTO_AI_HEAVY_MAX_TOKENS: "900" }).maxTokens, 900);
  // 300 のように小さすぎる設定は、品目の多い写真で途中切れになるので下限 800 に上げる。
  assertEquals(tierCallOptions("light", { PHOTO_AI_LIGHT_MAX_TOKENS: "300" }).maxTokens, 800);
  assertEquals(tierCallOptions("light", { PHOTO_AI_MAX_TOKENS: "300" }).maxTokens, 800);
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
  assertEquals(JSON.stringify(body).includes("web_search"), false);
  assertEquals(JSON.stringify(body).includes("budget_tokens"), false);
  assertEquals(JSON.stringify(body).includes("secret-key"), false);
  const system = body.system as Array<{ cache_control?: { type: string }; text: string }>;
  assertEquals(system.length, 1);
  assertEquals(system[0].cache_control, { type: "ephemeral" });
  assertEquals(system[0].text.includes("日本食品標準成分表"), true);
  assertEquals(system[0].text.includes("食品データベースの品目や数値に限りません"), true);
  assertEquals(system[0].text.includes("学習した知識だけ"), true);
  const prompt = userPrompt("カレー", "300g", "油多め</user_data>");
  assertEquals(prompt.includes("<user_data>"), true);
  assertEquals(prompt.includes("</user_data><"), false);
  assertEquals(prompt.includes("油多め/user_data"), true);
  const heavy = anthropicBody(sampleRequest({
    model: "claude-sonnet-5-5",
    tier: "heavy",
    thinking: "off",
  }));
  assertEquals("tools" in heavy, false);
  assertEquals(heavy.thinking, { type: "between_tools" });
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
    },
  });
  assertEquals(result.usage.inputTokens, 1200);
  assertEquals(result.usage.outputTokens, 80);
  assertEquals(result.usage.cacheReadTokens, 400);
  assertEquals(result.usage.cacheWriteTokens, 25);
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
  collections?: FoodCollectionRow[][];
  failCollections?: boolean;
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
    insertCollections: options.failCollections
      ? () => Promise.reject(new Error("db"))
      : options.collections
      ? (rows) => {
        options.collections!.push(rows);
        return Promise.resolve(rows.map((_, index) => `col-${index}`));
      }
      : undefined,
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
  assertEquals(calls[0].maxTokens, 1200);
  assertEquals(calls[0].thinking, "off");
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
      rows: Array.from({ length: 15 }, () => ({
        createdAt: "2026-10-08T01:00:00Z",
        tier: "light" as const,
        costJpy: 0.1,
      })),
    }),
  );
  const dailyBody = await daily.json();
  assertEquals(dailyBody.code, "daily_cap");
  assertEquals(dailyBody.message, "本日の上限に達しました");
  const spend = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "丼", amount: "1杯" }),
    deps({
      calls,
      env: { PHOTO_AI_MONTHLY_SPEND_JPY: "120" },
      rows: [{
        createdAt: "2026-10-01T00:00:00Z",
        tier: "light",
        costJpy: 120,
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
      env: { AI_COMBINED_DAILY_LIMIT: "1" },
      rows: [{
        createdAt: "2026-10-08T01:00:00Z",
        tier: "light",
        costJpy: 0.1,
      }],
    }),
  );
  const body = await response.json();
  assertEquals(body.code, "daily_cap");
  assertEquals(body.message, "本日の上限に達しました");
  assertEquals(calls.length, 0);
});

Deno.test("one anthropic turn returns the estimate and does not send tools", async () => {
  const seen: Array<Record<string, unknown>> = [];
  const fetchImpl: typeof fetch = (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    const payload = {
      stop_reason: "end_turn",
      content: [
        { type: "text", text: "推定です" },
        { type: "text", text: JSON.stringify(validEstimate()) },
      ],
      usage: {
        input_tokens: 10,
        output_tokens: 8,
        cache_read_input_tokens: 2,
      },
    };
    return Promise.resolve(new Response(JSON.stringify(payload), { status: 200 }));
  };
  const result = await new AnthropicPhotoProvider(fetchImpl).analyze(
    sampleRequest({ model: "claude-sonnet-5-5", tier: "heavy" }),
    "test-key",
  );
  assertEquals(seen.length, 1);
  assertEquals("tools" in seen[0], false);
  assertEquals(JSON.stringify(seen[0]).includes("web_search"), false);
  assertEquals(result.usage.inputTokens, 10);
  assertEquals(result.usage.cacheReadTokens, 2);
  assertEquals(result.text.includes("親子丼"), true);
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

Deno.test("a photo result is collected without the image", async () => {
  const collections: FoodCollectionRow[][] = [];
  const response = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "カレー", amount: "300g" }),
    deps({
      collections,
      text: JSON.stringify(validEstimate({ h: "吉野家" })),
    }),
  );
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.collection_id, "col-0");
  assertEquals(collections[0][0].sourcePath, "photo");
  assertEquals(collections[0][0].normalizedName, "親子丼");
  assertEquals(collections[0][0].chainName, "吉野家");
  assertEquals(collections[0][0].kcal, 290);
  assertEquals(collections[0][0].model, "claude-haiku-5-5");
  assertEquals(JSON.stringify(collections).includes(tinyJpeg), false);
  const failed = await handleAnalyzeMealPhoto(
    post({ image_base64: tinyJpeg, dish_name: "カレー", amount: "300g" }),
    deps({ failCollections: true }),
  );
  const failedBody = await failed.json();
  assertEquals(failedBody.ok, true);
  assertEquals(failedBody.collection_id, null);
});

Deno.test("photo count does not include cook coach", async () => {
  const urls: string[] = [];
  const fetchImpl = (input: string) => {
    urls.push(input);
    if (input.includes("meal_photo_analyses")) {
      return Promise.resolve(Response.json([
        { created_at: "2026-10-08T01:00:00Z", tier: "light", estimated_cost_jpy: 1 },
      ]));
    }
    return Promise.resolve(Response.json([]));
  };
  const live = liveDeps(
    { SUPABASE_URL: "https://db.test", SUPABASE_SERVICE_ROLE_KEY: "svc" },
    fetchImpl,
  );
  const rows = await live.usageRows("user-1", new Date("2026-10-01T00:00:00Z"));
  assertEquals(rows.length, 1);
  assertEquals(rows[0].tier, "light");
  assertEquals(urls.some((url) => url.includes("ai_feature_uses")), false);
  assertEquals(urls.some((url) => url.includes("ai_search")), false);
});

Deno.test("item nutrition is scaled so the parts sum to the meal", () => {
  const parsed = parsePhotoMealEstimate({
    dish_name: "定食",
    amount: "1人前",
    kcal: 680,
    protein_g: 30,
    fat_g: 20,
    carb_g: 95,
    confidence: 0.8,
    items: [
      { name: "ごはん", amount: "200g", kcal: 300, protein_g: 15, fat_g: 10, carb_g: 37.5 },
      { name: "焼き魚", amount: "1切れ", kcal: 362, protein_g: 14, fat_g: 10, carb_g: 48 },
    ],
  });
  if (!parsed) {
    throw new Error("missing estimate");
  }
  const sum = (pick: (item: { kcal: number; proteinG: number; fatG: number; carbG: number }) => number) =>
    Math.round(parsed.items.reduce((total, item) => total + pick(item), 0) * 10) / 10;
  assertEquals(sum((item) => item.kcal), 680);
  assertEquals(sum((item) => item.proteinG), 30);
  assertEquals(sum((item) => item.fatG), 20);
  assertEquals(sum((item) => item.carbG), 95);
});

Deno.test("a sentence amount and a crowded bento are repaired, not rejected", () => {
  const sentence = "全体的に少なめだった印象で、ご飯は茶碗に軽く1杯ほど、生姜焼きは3枚くらいと付け合わせ";
  const items = Array.from({ length: 15 }, (_v, i) => ({
    n: `おかず${i + 1}`,
    a: "少量",
    k: 40,
    p: 2,
    f: 2,
    c: 4.5,
  }));
  const checked = validatePhotoMealEstimate({
    n: "豚の生姜焼き弁当",
    a: sentence,
    k: 600,
    p: 30,
    f: 30,
    c: 67.5,
    u: 0.6,
    h: "",
    i: items,
  });
  assertEquals(checked.ok, true);
  if (!checked.ok) return;
  assertEquals(Array.from(checked.estimate.amount).length, 40);
  assertEquals(checked.estimate.amount.endsWith("…"), true);
  assertEquals(checked.estimate.items.length, 12);
  assertEquals(checked.estimate.items[11].name, "その他（4品）");
  assertEquals(
    Math.round(checked.estimate.items.reduce((sum, item) => sum + item.kcal, 0)),
    600,
  );
  assertEquals(checked.repairs.includes("amount_clipped"), true);
  assertEquals(checked.repairs.includes("items_merged"), true);
});

Deno.test("an item whose kcal disagrees with its PFC keeps its grams", () => {
  const checked = validatePhotoMealEstimate({
    n: "豚の生姜焼き弁当",
    a: "少なめ",
    k: 600,
    p: 30,
    f: 30,
    c: 67.5,
    u: 0.6,
    i: [
      { n: "ご飯", a: "150g", k: 252, p: 3.8, f: 0.5, c: 55.7 },
      { n: "生姜焼き", a: "80g", k: 900, p: 26, f: 29, c: 11.8 },
    ],
  });
  assertEquals(checked.ok, true);
  if (!checked.ok) return;
  assertEquals(checked.repairs, ["item_kcal_from_pfc"]);
  assertEquals(checked.estimate.items.length, 2);
  assertEquals(
    Math.round(checked.estimate.items.reduce((sum, item) => sum + item.kcal, 0)),
    600,
  );
});

Deno.test("validation failures name the field, never the model text", () => {
  assertEquals(validatePhotoMealEstimate(null), { ok: false, reason: "not_object" });
  assertEquals(
    validatePhotoMealEstimate(validEstimate({ kcal: 2_000 })),
    { ok: false, reason: "total_pfc_mismatch" },
  );
  assertEquals(
    validatePhotoMealEstimate(validEstimate({ dish_name: " " })),
    { ok: false, reason: "dish_name" },
  );
  assertEquals(
    validatePhotoMealEstimate(validEstimate({ items: undefined })),
    { ok: false, reason: "items_missing" },
  );
});

Deno.test("the prompt keeps the overall amount within the stored length", async () => {
  const { mealAnalysisPrompt } = await import("./analyze-meal-photo/provider.ts");
  const { maxAmountLength } = await import("./analyze-meal-photo/validate.ts");
  assertEquals(mealAnalysisPrompt.includes(`全体の量 a は${maxAmountLength}文字以内`), true);
});
