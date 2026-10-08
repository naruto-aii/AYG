import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { checkGate, GateCheckError, gateRetryDelayMs, gateRowsExist } from "./_shared/gate_check.ts";
import { hasAiDataConsent } from "./_shared/ai_data_consent.ts";
import { handleAnalyzeMealPhoto, liveDeps as photoLiveDeps } from "./analyze-meal-photo/handler.ts";
import { handleCookCoach, liveDeps as cookLiveDeps } from "./cook-coach/handler.ts";
import { handleLookupFoodText, liveDeps as lookupLiveDeps } from "./lookup-food-text/handler.ts";

const now = new Date("2026-10-09T03:00:00Z");
const env = {
  ANTHROPIC_API_KEY: "test-key",
  PHOTO_AI_PROVIDER: "anthropic",
  SUPABASE_URL: "https://example.test",
  SUPABASE_SERVICE_ROLE_KEY: "service-test",
  SUPABASE_ANON_KEY: "anon-test",
};

function post(body: unknown): Request {
  return new Request("https://example.test/ai", { method: "POST", body: JSON.stringify(body) });
}

// 1回目は失敗、2回目からは value を返す。always なら毎回失敗。
function flaky(value: boolean, failures: number) {
  const state = { calls: 0 };
  const check = () => {
    state.calls += 1;
    if (state.calls <= failures) {
      return Promise.reject(new GateCheckError(state.calls === 1 ? 401 : 503));
    }
    return Promise.resolve(value);
  };
  return { state, check };
}

function sleeper() {
  const waits: number[] = [];
  return { waits, sleep: (ms: number) => { waits.push(ms); return Promise.resolve(); } };
}

async function codeOf(response: Response): Promise<string> {
  const body = await response.json();
  return body.code;
}

Deno.test("checkGate retries one transient failure after a short wait", async () => {
  const s = sleeper();
  const once = flaky(true, 1);
  assertEquals(await checkGate(once.check, { sleep: s.sleep }), "yes");
  assertEquals(once.state.calls, 2);
  assertEquals(s.waits, [gateRetryDelayMs]);

  const twice = flaky(true, 2);
  assertEquals(await checkGate(twice.check, { sleep: s.sleep }), "unavailable");
  assertEquals(twice.state.calls, 2);

  const network = { calls: 0 };
  assertEquals(
    await checkGate(() => {
      network.calls += 1;
      return Promise.reject(new TypeError("network"));
    }, { sleep: s.sleep }),
    "unavailable",
  );
  assertEquals(network.calls, 2);
});

Deno.test("checkGate returns no at once when the row is really missing", async () => {
  const s = sleeper();
  const missing = flaky(false, 0);
  assertEquals(await checkGate(missing.check, { sleep: s.sleep }), "no");
  assertEquals(missing.state.calls, 1);
  assertEquals(s.waits, []);
});

Deno.test("gateRowsExist treats 401, 5xx and broken bodies as failures, not as missing rows", () => {
  for (const status of [401, 403, 500, 502, 503]) {
    let thrown = false;
    try {
      gateRowsExist({ ok: false, status, body: { message: "x" } });
    } catch (error) {
      thrown = error instanceof GateCheckError && error.status === status;
    }
    assertEquals(thrown, true, `status ${status}`);
  }
  let broken = false;
  try {
    gateRowsExist({ ok: true, status: 200, body: null });
  } catch {
    broken = true;
  }
  assertEquals(broken, true);
  assertEquals(gateRowsExist({ ok: true, status: 200, body: [] }), false);
  assertEquals(gateRowsExist({ ok: true, status: 200, body: [{ user_id: "u" }] }), true);
});

Deno.test("consent lookup throws on a failed query and returns false only for a real empty result", async () => {
  const respond = (status: number, body: unknown) => () =>
    Promise.resolve(new Response(JSON.stringify(body), { status }));
  const base = { base: "https://example.test", serviceKey: "service-test", userId: "user-1" };
  await assertRejects(() => hasAiDataConsent({ ...base, fetchImpl: respond(401, { message: "jwt" }) }), GateCheckError);
  await assertRejects(() => hasAiDataConsent({ ...base, fetchImpl: respond(503, {}) }), GateCheckError);
  await assertRejects(() => hasAiDataConsent({ ...base, base: "", fetchImpl: respond(200, []) }), GateCheckError);
  assertEquals(await hasAiDataConsent({ ...base, fetchImpl: respond(200, []) }), false);
  assertEquals(await hasAiDataConsent({ ...base, fetchImpl: respond(200, [{ user_id: "user-1" }]) }), true);
});

Deno.test("live Plus checks of all three functions throw on 401 or 5xx and answer false only for an empty result", async () => {
  for (const make of [lookupLiveDeps, photoLiveDeps, cookLiveDeps]) {
    for (const status of [401, 500, 503]) {
      const deps = make(env, () => Promise.resolve(new Response(JSON.stringify({ message: "x" }), { status })));
      await assertRejects(() => deps.isPlus("user-1", now), GateCheckError);
    }
    const empty = make(env, () => Promise.resolve(new Response("[]", { status: 200 })));
    assertEquals(await empty.isPlus("user-1", now), false);
    const plus = make(env, () => Promise.resolve(new Response('[{"user_id":"user-1"}]', { status: 200 })));
    assertEquals(await plus.isPlus("user-1", now), true);
    const network = make(env, () => Promise.reject(new TypeError("network")));
    await assertRejects(() => network.isPlus("user-1", now));
  }
});

function lookupDeps(over: Record<string, unknown>) {
  const counts = { model: 0 };
  const deps = {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => now,
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(true),
    // 確認を通ったら日次上限で止め、モデルは呼ばない。
    usage: () => Promise.resolve({ dayCount: 9999, monthCount: 0, monthSpendJpy: 0 }),
    readCache: () => Promise.resolve(null),
    writeCache: () => Promise.resolve(),
    insertUsage: () => Promise.resolve("usage-1"),
    complete: () => {
      counts.model += 1;
      return Promise.reject(new Error("model"));
    },
    log: () => {},
    sleep: () => Promise.resolve(),
    ...over,
  };
  return { deps, counts };
}

Deno.test("lookup: a transient Plus or consent failure is retried once, then becomes 503 provider_error, never not_plus", async () => {
  const once = flaky(true, 1);
  const passed = lookupDeps({ isPlus: once.check });
  const ok = await handleLookupFoodText(post({ query: "牛丼" }), passed.deps as never);
  assertEquals([ok.status, await codeOf(ok)], [429, "daily_cap"]);
  assertEquals(once.state.calls, 2);

  const down = flaky(true, 2);
  const consentCalls = { n: 0 };
  const failed = lookupDeps({
    isPlus: down.check,
    hasConsent: () => {
      consentCalls.n += 1;
      return Promise.resolve(true);
    },
  });
  const unavailable = await handleLookupFoodText(post({ query: "牛丼" }), failed.deps as never);
  assertEquals([unavailable.status, await codeOf(unavailable)], [503, "provider_error"]);
  assertEquals(consentCalls.n, 0);
  assertEquals(failed.counts.model, 0);

  const notPlus = flaky(false, 0);
  const denied = await handleLookupFoodText(post({ query: "牛丼" }), lookupDeps({ isPlus: notPlus.check }).deps as never);
  assertEquals([denied.status, await codeOf(denied)], [403, "not_plus"]);
  assertEquals(notPlus.state.calls, 1);

  const consentDown = flaky(true, 2);
  const consentFailed = await handleLookupFoodText(post({ query: "牛丼" }), lookupDeps({ hasConsent: consentDown.check }).deps as never);
  assertEquals([consentFailed.status, await codeOf(consentFailed)], [503, "provider_error"]);
  const consentOnce = flaky(true, 1);
  const consentRetried = await handleLookupFoodText(post({ query: "牛丼" }), lookupDeps({ hasConsent: consentOnce.check }).deps as never);
  assertEquals(await codeOf(consentRetried), "daily_cap");
  const noConsent = await handleLookupFoodText(post({ query: "牛丼" }), lookupDeps({ hasConsent: () => Promise.resolve(false) }).deps as never);
  assertEquals([noConsent.status, await codeOf(noConsent)], [403, "consent_required"]);
});

function photoDeps(over: Record<string, unknown>) {
  const counts = { provider: 0 };
  const rows = Array.from({ length: 200 }, () => ({ createdAt: now.toISOString(), tier: "light", costJpy: 0 }));
  const deps = {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => now,
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(true),
    // 確認を通ったら日次上限で止め、モデルは呼ばない。
    usageRows: () => Promise.resolve(rows),
    insertUsage: () => Promise.resolve("usage-1"),
    providerFor: () => {
      counts.provider += 1;
      throw new Error("provider");
    },
    log: () => {},
    sleep: () => Promise.resolve(),
    ...over,
  };
  return { deps, counts };
}

const photoBody = { image_base64: btoa(String.fromCharCode(0xff, 0xd8, 0xff)), dish_name: "カレー", amount: "1皿" };

Deno.test("photo: a transient Plus or consent failure is retried once, then becomes 503 provider_error, never not_plus", async () => {
  const once = flaky(true, 1);
  const ok = await handleAnalyzeMealPhoto(post(photoBody), photoDeps({ isPlus: once.check }).deps as never);
  assertEquals([ok.status, await codeOf(ok)], [429, "daily_cap"]);
  assertEquals(once.state.calls, 2);

  const down = flaky(true, 2);
  const failed = photoDeps({ isPlus: down.check });
  const unavailable = await handleAnalyzeMealPhoto(post(photoBody), failed.deps as never);
  assertEquals([unavailable.status, await codeOf(unavailable)], [503, "provider_error"]);
  assertEquals(failed.counts.provider, 0);

  const notPlus = flaky(false, 0);
  const denied = await handleAnalyzeMealPhoto(post(photoBody), photoDeps({ isPlus: notPlus.check }).deps as never);
  assertEquals([denied.status, await codeOf(denied)], [403, "not_plus"]);
  assertEquals(notPlus.state.calls, 1);

  const consentDown = flaky(true, 2);
  const consentFailed = await handleAnalyzeMealPhoto(post(photoBody), photoDeps({ hasConsent: consentDown.check }).deps as never);
  assertEquals([consentFailed.status, await codeOf(consentFailed)], [503, "provider_error"]);
  const noConsent = await handleAnalyzeMealPhoto(post(photoBody), photoDeps({ hasConsent: () => Promise.resolve(false) }).deps as never);
  assertEquals([noConsent.status, await codeOf(noConsent)], [403, "consent_required"]);
});

function cookDeps(over: Record<string, unknown>) {
  const counts = { recipes: 0 };
  const deps = {
    env: {},
    now: () => now,
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    // 確認を通ったらレシピ読み込みで止める（空なら recipes_unavailable）。
    loadRecipes: () => {
      counts.recipes += 1;
      return Promise.resolve([]);
    },
    dailyCount: () => Promise.resolve(0),
    insertUsage: () => Promise.resolve("usage-1"),
    lookupFoods: () => Promise.resolve([]),
    model: () => ({ complete: () => Promise.reject(new Error("model")) }),
    log: () => {},
    sleep: () => Promise.resolve(),
    ...over,
  };
  return { deps, counts };
}

const cookBody = {
  ingredients: ["卵"],
  slot: "dinner",
  target_kcal: 650,
  target_protein_g: 32,
  target_fat_g: 18,
  target_carb_g: 75,
};

Deno.test("cook: a transient Plus failure is retried once, then becomes 503 provider_error, never not_plus", async () => {
  const once = flaky(true, 1);
  const passed = cookDeps({ isPlus: once.check });
  const ok = await handleCookCoach(post(cookBody), passed.deps as never);
  assertEquals(await codeOf(ok), "recipes_unavailable");
  assertEquals([once.state.calls, passed.counts.recipes], [2, 1]);

  const down = flaky(true, 2);
  const failed = cookDeps({ isPlus: down.check });
  const unavailable = await handleCookCoach(post(cookBody), failed.deps as never);
  const body = await unavailable.json();
  assertEquals([unavailable.status, body.code], [503, "provider_error"]);
  assertEquals(body.message.includes("しばらくしてから"), true);
  assertEquals(failed.counts.recipes, 0);

  const notPlus = flaky(false, 0);
  const denied = await handleCookCoach(post(cookBody), cookDeps({ isPlus: notPlus.check }).deps as never);
  assertEquals([denied.status, await codeOf(denied)], [403, "not_plus"]);
  assertEquals(notPlus.state.calls, 1);
});
