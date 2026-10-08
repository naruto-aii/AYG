import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { downscaleJpeg, imageTokensForPixels } from "./analyze-meal-photo/image.ts";
import {
  estimateCostJpy,
  tierCallOptions,
  tokenPricesFromEnv,
  type TokenPrices,
} from "./analyze-meal-photo/policy.ts";
import { mealAnalysisPrompt, userPrompt } from "./analyze-meal-photo/provider.ts";
import { lookupPrompt, lookupUserPrompt } from "./lookup-food-text/provider.ts";

// ライブのトークナイザは呼ばない。ASCII は約4文字で1、それ以外は1文字で1。
function approxTextTokens(text: string): number {
  let tokens = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    tokens += code <= 0x7f ? 0.25 : 1;
  }
  return Math.ceil(tokens);
}

function yen(args: {
  tier: "light" | "heavy";
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  prices?: TokenPrices;
}): number {
  return estimateCostJpy({
    inputTokens: args.inputTokens,
    outputTokens: args.outputTokens,
    cacheReadTokens: args.cacheReadTokens,
    cacheWriteTokens: args.cacheWriteTokens,
    prices: args.prices ?? tokenPricesFromEnv(args.tier, {}),
  });
}

Deno.test("resized pixels and yen per path stay within the measured figures", async () => {
  const api = await import("npm:jpeg-js@0.4.4");
  const width = 1600;
  const height = 1200;
  const data = new Uint8Array(width * height * 4);
  data.fill(40);
  const encoded = api.encode({ data, width, height }, 80);
  const at1024 = await downscaleJpeg(encoded.data, 1024);
  const decoded1024 = api.decode(at1024, { useTArray: true, formatAsRGBA: true });
  assertEquals(decoded1024.width, 1024);
  assertEquals(decoded1024.height, 768);
  assertEquals(imageTokensForPixels(decoded1024.width, decoded1024.height), 1049);
  const at768 = await downscaleJpeg(encoded.data, 768);
  const decoded768 = api.decode(at768, { useTArray: true, formatAsRGBA: true });
  assertEquals(decoded768.width, 768);
  assertEquals(decoded768.height, 576);
  assertEquals(imageTokensForPixels(decoded768.width, decoded768.height), 590);
  assertEquals(tierCallOptions("light", {}).imageMaxEdge, 1024);
  assertEquals(tierCallOptions("light", {}).maxTokens, 300);
  assertEquals(tierCallOptions("light", {}).thinking, "off");
  assertEquals(
    tierCallOptions("light", { PHOTO_AI_LIGHT_IMAGE_MAX_EDGE: "768" }).imageMaxEdge,
    768,
  );

  const systemTokens = approxTextTokens(mealAnalysisPrompt);
  const userTokens = approxTextTokens(userPrompt("親子丼", "1杯", null));
  const lookupSystemTokens = approxTextTokens(lookupPrompt);
  const lookupUserTokens = approxTextTokens(lookupUserPrompt("吉野家 牛丼 大盛"));
  const outputTokens = 120;
  const imageTokens = 1049;
  const imageTokensSmall = 590;
  assertEquals(systemTokens, 651);
  assertEquals(userTokens, 42);
  assertEquals(lookupSystemTokens, 646);
  assertEquals(lookupUserTokens, 40);

  const lightWrite = yen({
    tier: "light",
    inputTokens: imageTokens + userTokens,
    outputTokens,
    cacheReadTokens: 0,
    cacheWriteTokens: systemTokens,
  });
  const lightRead = yen({
    tier: "light",
    inputTokens: imageTokens + userTokens,
    outputTokens,
    cacheReadTokens: systemTokens,
    cacheWriteTokens: 0,
  });
  const heavyWrite = yen({
    tier: "heavy",
    inputTokens: imageTokens + userTokens,
    outputTokens,
    cacheReadTokens: 0,
    cacheWriteTokens: systemTokens,
  });
  const heavyRead = yen({
    tier: "heavy",
    inputTokens: imageTokens + userTokens,
    outputTokens,
    cacheReadTokens: systemTokens,
    cacheWriteTokens: 0,
  });
  const lightWrite768 = yen({
    tier: "light",
    inputTokens: imageTokensSmall + userTokens,
    outputTokens,
    cacheReadTokens: 0,
    cacheWriteTokens: systemTokens,
  });
  const textWrite = yen({
    tier: "light",
    inputTokens: lookupUserTokens,
    outputTokens,
    cacheReadTokens: 0,
    cacheWriteTokens: lookupSystemTokens,
  });
  const textRead = yen({
    tier: "light",
    inputTokens: lookupUserTokens,
    outputTokens,
    cacheReadTokens: lookupSystemTokens,
    cacheWriteTokens: 0,
  });
  const round6 = (value: number) => Math.round(value * 1_000_000) / 1_000_000;
  assertEquals(round6(lightWrite), 0.039575);
  assertEquals(round6(lightRead), 0.027746);
  assertEquals(round6(heavyWrite), 0.791501);
  assertEquals(round6(heavyRead), 0.544642);
  assertEquals(round6(lightWrite768), 0.032323);
  assertEquals(round6(textWrite), 0.022871);
  assertEquals(round6(textRead), 0.011133);
  assertEquals(yen({
    tier: "light",
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
  }), 0);
  const ceiling = 300;
  assertEquals(round6(yen({
    tier: "light",
    inputTokens: imageTokens + userTokens,
    outputTokens: ceiling,
    cacheReadTokens: 0,
    cacheWriteTokens: systemTokens,
  })), 0.053795);
  assertEquals(round6(yen({
    tier: "heavy",
    inputTokens: imageTokens + userTokens,
    outputTokens: ceiling,
    cacheReadTokens: 0,
    cacheWriteTokens: systemTokens,
  })), 1.075901);
  assertEquals(round6(yen({
    tier: "light",
    inputTokens: lookupUserTokens,
    outputTokens: ceiling,
    cacheReadTokens: 0,
    cacheWriteTokens: lookupSystemTokens,
  })), 0.037091);
});
