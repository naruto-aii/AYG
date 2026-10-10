import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleAnalyzeMealPhoto } from "./analyze-meal-photo/handler.ts";
import { handleCookCoach } from "./cook-coach/handler.ts";
import { handleLookupFoodText } from "./lookup-food-text/handler.ts";
import {
  aiDataConsentRequiredMessage,
  aiDataConsentVersion,
} from "./_shared/ai_data_consent.ts";

function post(body: unknown): Request {
  return new Request("https://example.test/ai", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

const jpeg = btoa(String.fromCharCode(0xff, 0xd8, 0xff));

Deno.test("photo and lookup do not call the model without consent; cook needs only Plus", async () => {
  let photoProvider = 0;
  let lookupComplete = 0;
  let lookupCache = 0;
  let cookModel = 0;
  let cookCache = 0;

  const photo = await handleAnalyzeMealPhoto(post({
    image_base64: jpeg,
    dish_name: "カレー",
    amount: "1皿",
  }), {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-08T03:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(false),
    usageRows: () => Promise.resolve([]),
    insertUsage: () => Promise.resolve("usage-1"),
    providerFor: () => {
      photoProvider += 1;
      throw new Error("provider");
    },
    log: () => {},
  });
  const lookup = await handleLookupFoodText(post({ query: "牛丼" }), {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-08T03:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(false),
    usage: () => Promise.resolve({ dayCount: 0, monthCount: 0, monthSpendJpy: 0 }),
    readCache: () => {
      lookupCache += 1;
      return Promise.resolve(null);
    },
    writeCache: () => Promise.resolve(),
    insertUsage: () => Promise.resolve("usage-1"),
    complete: () => {
      lookupComplete += 1;
      return Promise.reject(new Error("model"));
    },
    log: () => {},
  });
  const cook = await handleCookCoach(post({
    ingredients: ["卵"],
    slot: "dinner",
    target_kcal: 650,
    target_protein_g: 32,
    target_fat_g: 18,
    target_carb_g: 75,
  }), {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-08T09:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    loadRecipes: () => Promise.resolve([]),
    dailyCount: () => Promise.resolve(0),
    insertUsage: () => Promise.resolve("usage-1"),
    lookupFoods: () => Promise.resolve([]),
    model: () => {
      cookModel += 1;
      throw new Error("model");
    },
    readCache: () => {
      cookCache += 1;
      return Promise.resolve(null);
    },
    log: () => {},
  });

  // 自炊コーチは外部へ送らないので同意を求めない。レシピが無いときは 503 になる。
  assertEquals(cook.status, 503);
  assertEquals((await cook.json()).code, "recipes_unavailable");
  const cookNotPlus = await handleCookCoach(post({
    ingredients: ["卵"],
    slot: "dinner",
    target_kcal: 650,
    target_protein_g: 32,
    target_fat_g: 18,
    target_carb_g: 75,
  }), {
    env: {},
    now: () => new Date("2026-10-08T09:00:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(false),
    loadRecipes: () => Promise.resolve([]),
    dailyCount: () => Promise.resolve(0),
    insertUsage: () => Promise.resolve("usage-1"),
    lookupFoods: () => Promise.resolve([]),
    model: () => {
      cookModel += 1;
      throw new Error("model");
    },
    log: () => {},
  });
  assertEquals(cookNotPlus.status, 403);
  assertEquals((await cookNotPlus.json()).code, "not_plus");

  for (const response of [photo, lookup]) {
    assertEquals(response.status, 403);
    const body = await response.json();
    assertEquals(body.ok, false);
    assertEquals(body.code, "consent_required");
    assertEquals(body.message, aiDataConsentRequiredMessage);
  }
  assertEquals(photoProvider, 0);
  assertEquals(lookupComplete, 0);
  assertEquals(lookupCache, 0);
  assertEquals(cookModel, 0);
  assertEquals(cookCache, 0); // レシピが無いので、キャッシュも読まない
  assertEquals(aiDataConsentVersion, "2026-10-10");
});
