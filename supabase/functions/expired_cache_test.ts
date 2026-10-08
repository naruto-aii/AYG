import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  expiredCacheDeleteLimit,
  expiredCacheDeleteQuery,
  expiredCacheListQuery,
  purgeExpiredCache,
} from "./_shared/expired_cache.ts";
import { handleCookCoach } from "./cook-coach/handler.ts";
import { handleLookupFoodText } from "./lookup-food-text/handler.ts";

const now = new Date("2026-10-08T03:00:00Z");

Deno.test("expired cache lists are bounded and only name expired rows", () => {
  const lookup = expiredCacheListQuery("ai_food_estimate_cache", now);
  const cook = expiredCacheListQuery("cook_coach_cache", now);
  assertEquals(lookup.includes("expires_at=lt."), true);
  assertEquals(lookup.includes(`limit=${expiredCacheDeleteLimit}`), true);
  assertEquals(lookup.includes("expires_at=gt."), false);
  assertEquals(cook.includes("select=cache_key"), true);
  assertEquals(expiredCacheDeleteLimit, 20);
});

Deno.test("purge deletes only the expired keys it listed, and stops at the limit", async () => {
  const expired = Array.from({ length: 25 }, (_, index) => ({
    user_id: "11111111-1111-4111-8111-111111111111",
    query_key: `food-${index}`,
  }));
  const calls: Array<{ url: string; method: string }> = [];
  const deleted = await purgeExpiredCache({
    base: "https://db.test",
    serviceKey: "service",
    table: "ai_food_estimate_cache",
    now,
    fetchImpl: (url, init) => {
      calls.push({ url, method: init?.method ?? "GET" });
      if ((init?.method ?? "GET") === "GET") {
        return Promise.resolve(new Response(JSON.stringify(expired), { status: 200 }));
      }
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  });
  assertEquals(deleted, 20);
  assertEquals(calls[0].url.includes("expires_at=lt."), true);
  assertEquals(calls[0].url.includes("limit=20"), true);
  assertEquals(calls.filter((call) => call.method === "DELETE").length, 20);
  assertEquals(calls.some((call) => call.url.includes("food-20")), false);
  assertEquals(calls.some((call) => call.url.includes("expires_at=gt.")), false);
  const fresh = expiredCacheDeleteQuery("ai_food_estimate_cache", {
    user_id: "not-a-user",
    query_key: "still-fresh",
  });
  assertEquals(fresh, null);
});

Deno.test("cook cache purge deletes a listed expired key and keeps a fresh one untouched", async () => {
  const key = "a".repeat(64);
  const calls: string[] = [];
  const deleted = await purgeExpiredCache({
    base: "https://db.test",
    serviceKey: "service",
    table: "cook_coach_cache",
    now,
    fetchImpl: (url, init) => {
      calls.push(`${init?.method ?? "GET"} ${url}`);
      if ((init?.method ?? "GET") === "GET") {
        return Promise.resolve(new Response(JSON.stringify([
          { cache_key: key },
          { cache_key: "not-expired-shape" },
        ]), { status: 200 }));
      }
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  });
  assertEquals(deleted, 1);
  assertEquals(calls.some((call) => call.includes(`cache_key=eq.${key}`)), true);
  assertEquals(calls.some((call) => call.includes("not-expired-shape")), false);
});

Deno.test("lookup and cook still delete expired cache when Plus is missing", async () => {
  let lookupDeletes = 0;
  let cookDeletes = 0;
  const lookup = await handleLookupFoodText(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ query: "牛丼" }),
    }),
    {
      env: { ANTHROPIC_API_KEY: "test", PHOTO_AI_PROVIDER: "anthropic" },
      now: () => now,
      userId: () => Promise.resolve("user-1"),
      isPlus: () => Promise.resolve(false),
      usage: () => Promise.resolve({ dayCount: 0, monthCount: 0, monthSpendJpy: 0 }),
      readCache: () => Promise.resolve(null),
      writeCache: () => Promise.resolve(),
      insertUsage: () => Promise.resolve(null),
      complete: () => Promise.reject(new Error("should not call")),
      log: () => undefined,
      deleteExpiredCache: () => {
        lookupDeletes += 1;
        return Promise.resolve();
      },
    },
  );
  const cook = await handleCookCoach(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ ingredients: ["卵"] }),
    }),
    {
      env: {},
      now: () => now,
      userId: () => Promise.resolve("user-1"),
      isPlus: () => Promise.resolve(false),
      dailyCount: () => Promise.resolve(0),
      insertUsage: () => Promise.resolve(null),
      lookupFoods: () => Promise.resolve([]),
      model: () => ({ complete: () => Promise.reject(new Error("should not call")) }),
      log: () => undefined,
      deleteExpiredCache: () => {
        cookDeletes += 1;
        return Promise.resolve();
      },
    },
  );
  assertEquals(lookup.status, 403);
  assertEquals((await lookup.json()).code, "not_plus");
  assertEquals(lookupDeletes, 1);
  assertEquals(cook.status, 400);
  assertEquals(cookDeletes, 1);
});
