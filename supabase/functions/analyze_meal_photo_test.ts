import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  checkPhotoCaps,
  defaultPhotoLimits,
  estimateCostJpy,
  routePhotoModel,
  summarizeUsage,
  tokyoDateKey,
  tokyoMonthStartUtc,
  type UsageRow,
} from "./analyze-meal-photo/policy.ts";
import {
  anthropicBody,
  createPhotoAiProvider,
  readAnthropicResult,
  thinkingField,
} from "./analyze-meal-photo/provider.ts";
import {
  jpegBytesFromBase64,
  parsePhotoMealEstimate,
} from "./analyze-meal-photo/validate.ts";
import {
  handleAnalyzeMealPhoto,
  type AnalyzeDeps,
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

Deno.test("caps stop at 10 a day, 120 a month, and the spend ceiling", () => {
  const base = {
    dayCount: 0,
    monthCount: 0,
    heavyMonthCount: 0,
    monthSpendJpy: 0,
  };
  assertEquals(checkPhotoCaps(base, defaultPhotoLimits), null);
  assertEquals(
    checkPhotoCaps({ ...base, dayCount: 10 }, defaultPhotoLimits),
    "daily_cap",
  );
  assertEquals(
    checkPhotoCaps({ ...base, monthCount: 120 }, defaultPhotoLimits),
    "monthly_cap",
  );
  assertEquals(
    checkPhotoCaps({ ...base, monthSpendJpy: 120 }, defaultPhotoLimits),
    "spend_cap",
  );
  assertEquals(
    checkPhotoCaps({ ...base, monthSpendJpy: 119.99 }, defaultPhotoLimits),
    null,
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

Deno.test("cost uses token counts and per-million prices", () => {
  const cost = estimateCostJpy({
    inputTokens: 1_000,
    outputTokens: 1_000,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    prices: {
      inputJpyPerMillion: 16,
      outputJpyPerMillion: 80,
      cacheReadRatio: 0.1,
      cacheWriteRatio: 1.25,
      longPromptMultiplier: 5,
    },
  });
  assertEquals(cost, 0.096);
  const long = estimateCostJpy({
    inputTokens: 100_001,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    prices: {
      inputJpyPerMillion: 16,
      outputJpyPerMillion: 80,
      cacheReadRatio: 0.1,
      cacheWriteRatio: 1.25,
      longPromptMultiplier: 5,
    },
  });
  assertEquals(Math.round(long * 1000) / 1000, Math.round((100_001 * 80) / 1_000_000 * 1000) / 1000);
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
});

Deno.test("jpeg check accepts the magic bytes and rejects other files", () => {
  assertEquals(jpegBytesFromBase64(tinyJpeg)?.length, 4);
  assertEquals(jpegBytesFromBase64("aGVsbG8="), null);
  assertEquals(jpegBytesFromBase64(""), null);
});

Deno.test("sonnet 5.5 does not force a tool and does not disable thinking outright", () => {
  assertEquals(thinkingField("claude-sonnet-5-5"), { type: "between_tools" });
  assertEquals(thinkingField("claude-haiku-5-5"), { type: "disabled" });
  const body = anthropicBody({
    model: "claude-haiku-5-5",
    tier: "light",
    imageJpegBase64: tinyJpeg,
    dishName: "カレー",
    amount: "300g",
  });
  assertEquals(body.model, "claude-haiku-5-5");
  const format = (body.output_config as { format: { type: string } }).format;
  assertEquals(format.type, "json_schema");
  assertEquals("tool_choice" in body, false);
  assertEquals(JSON.stringify(body).includes("secret-key"), false);
});

Deno.test("anthropic usage is read without keeping the image", () => {
  const result = readAnthropicResult({
    stop_reason: "end_turn",
    content: [{ type: "text", text: JSON.stringify(validEstimate()) }],
    usage: { input_tokens: 1200, output_tokens: 80 },
  });
  assertEquals(result.usage.inputTokens, 1200);
  assertEquals(result.usage.outputTokens, 80);
  assertEquals(result.text.includes("親子丼"), true);
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
}): AnalyzeDeps {
  const calls = options.calls ?? [];
  const inserts = options.inserts ?? [];
  return {
    env: {
      ANTHROPIC_API_KEY: options.key ?? "test-key",
      PHOTO_AI_PROVIDER: options.provider ?? "anthropic",
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
  assertEquals(JSON.stringify(inserts[0]).includes(tinyJpeg), false);
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
