import { assertEquals } from "jsr:@std/assert@1";

import {
  aiDailyLimitDefault,
  handleCookCoach,
  type CookDeps,
  type CookModelCall,
} from "./cook-coach/handler.ts";
import {
  bestMeasured,
  gapOf,
  matchFood,
  measureIngredients,
  normalizeFoodName,
  realismIssues,
  techniqueHits,
  withinTolerance,
  type AiDish,
  type FoodRow,
  type Macros,
  type MeasuredDish,
} from "./cook-coach/match.ts";
import { evalScenarios, planScenario, runLocalEval } from "./cook_coach_eval.ts";
import { cookRecipes } from "./cook-coach/recipes.ts";
import { assemblyIssues, needsModelRetry, stepIssues } from "./cook-coach/plan.ts";
import { explainRejectedTarget } from "./cook-coach/handler.ts";

function food(code: string, name: string, kcal: number, proteinG: number, fatG: number, carbG: number): FoodRow {
  return {
    foodCode: code,
    name,
    displayName: name,
    normalizedName: normalizeFoodName(name),
    aliases: [],
    kcal,
    proteinG,
    fatG,
    carbG,
    baseAmount: 100,
  };
}

const chicken = food("11226", "鶏むね肉", 108, 24, 1.5, 0);
chicken.aliases = [{ normalized: normalizeFoodName("鶏むね"), candidate: false }];
const rice = food("1080", "ごはん", 168, 2.5, 0.3, 37.1);
const oil = food("1400", "サラダ油", 921, 0, 100, 0);
const egg = food("1200", "卵", 151, 12.3, 10.3, 0.3);
const broccoli = food("6250", "ブロッコリー", 33, 4.3, 0.4, 5.2);
const onion = food("6200", "玉ねぎ", 37, 1, 0.1, 8.8);
const pantry = [chicken, rice, oil, egg, broccoli, onion];

function assertGapReported(finished: MeasuredDish, target: Macros) {
  const kcal = finished.ingredients.reduce((sum, item) => sum + item.kcal, 0);
  const protein = Math.round(finished.ingredients.reduce((sum, item) => sum + item.proteinG, 0) * 10) / 10;
  const fat = Math.round(finished.ingredients.reduce((sum, item) => sum + item.fatG, 0) * 10) / 10;
  const carb = Math.round(finished.ingredients.reduce((sum, item) => sum + item.carbG, 0) * 10) / 10;
  assertEquals(finished.totals.kcal, kcal);
  assertEquals(finished.totals.proteinG, protein);
  assertEquals(finished.totals.fatG, fat);
  assertEquals(finished.totals.carbG, carb);
  assertEquals(finished.gap.kcal, Math.round(target.kcal - finished.totals.kcal));
  assertEquals(finished.gap.proteinG, Math.round((target.proteinG - finished.totals.proteinG) * 10) / 10);
  assertEquals(finished.gap.fatG, Math.round((target.fatG - finished.totals.fatG) * 10) / 10);
  assertEquals(finished.gap.carbG, Math.round((target.carbG - finished.totals.carbG) * 10) / 10);
  assertEquals(finished.within, withinTolerance(target, finished.totals));
}

function assertHit(finished: MeasuredDish, target: Macros) {
  assertGapReported(finished, target);
  assertEquals(finished.within, true);
  assertEquals(finished.issues, []);
}

function dish(ingredients: AiDish["ingredients"], extras: string[] = []): AiDish {
  return {
    name: extras.length === 0 ? "塩鶏" : "豆腐の塩鶏",
    steps: ["肉の中心まで火を通す", "器に盛る"],
    extras,
    ingredients,
  };
}

function chickenIngredient(kcal = 999): AiDish["ingredients"][number] {
  return { name: "鶏むね肉", grams: 100, kcal, proteinG: 1, fatG: 1, carbG: 1 };
}

function modelText(aKcal: number, bKcal: number): string {
  const body = {
    a: {
      n: "塩鶏",
      s: [
        "鶏むね肉100gを一口大に切る",
        "フライパンを中火にし、両面を4分ずつ焼く",
        "塩を振らず、中まで火を通して器に盛る",
      ],
      i: [{ n: "鶏むね肉", g: 100, k: aKcal, p: 1, f: 1, c: 1 }],
    },
    b: {
      n: "豆腐の塩鶏",
      s: [
        "鶏むね肉100gと豆腐100gを一口大に切る",
        "フライパンを中火にし、両面を4分ずつ焼く",
        "中まで火を通してから器に盛る",
      ],
      x: ["豆腐"],
      i: [
        { n: "鶏むね肉", g: 100, k: aKcal, p: 1, f: 1, c: 1 },
        { n: "豆腐", g: 100, k: bKcal, p: 5, f: 3, c: 2 },
      ],
    },
  };
  return JSON.stringify(body);
}

function deps(options: {
  plus?: boolean;
  used?: number;
  foods?: FoodRow[];
  replies: string[];
}): { deps: CookDeps; calls: string[] } {
  const calls: string[] = [];
  const model: CookModelCall = {
    complete(userText: string) {
      const text = options.replies[calls.length] ?? options.replies.at(-1) ?? "";
      calls.push(userText);
      return Promise.resolve({
        text,
        usage: {
          inputTokens: 100,
          outputTokens: 50,
          cacheReadTokens: calls.length > 1 ? 80 : 0,
          cacheWriteTokens: calls.length === 1 ? 80 : 0,
        },
      });
    },
  };
  const inserted: unknown[] = [];
  return {
    calls,
    deps: {
      env: { AI_DAILY_LIMIT: "15" },
      now: () => new Date("2026-10-08T10:00:00Z"),
      userId: () => Promise.resolve("user-1"),
      isPlus: () => Promise.resolve(options.plus ?? true),
      dailyCount: () => Promise.resolve(options.used ?? 0),
      insertUsage: (row) => {
        inserted.push(row);
        return Promise.resolve("usage-1");
      },
      lookupFoods: () => Promise.resolve(options.foods ?? [chicken]),
      model: () => model,
      loadRecipes: () => Promise.resolve(cookRecipes),
      log: () => {},
    },
  };
}

function request(body: unknown): Request {
  return new Request("https://example.test/cook-coach", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

const onTarget = {
  ingredients: ["鶏むね肉"],
  slot: "dinner",
  target_kcal: 108,
  target_protein_g: 24,
  target_fat_g: 1.5,
  target_carb_g: 0,
};

Deno.test("match uses the nutrition row and ignores the model's kcal", () => {
  const measured = measureIngredients(
    dish([chickenIngredient()]),
    [chicken],
  );
  assertEquals(measured[0].source, "db");
  assertEquals(measured[0].foodCode, "11226");
  assertEquals(measured[0].kcal, 108);
  assertEquals(measured[0].proteinG, 24);
});

Deno.test("an unknown ingredient keeps the model's nutrition and is marked ai", () => {
  const measured = measureIngredients(
    dish([{ name: "自家製つゆ", grams: 20, kcal: 15, proteinG: 1, fatG: 0, carbG: 2 }]),
    [chicken],
  );
  assertEquals(measured[0].source, "ai");
  assertEquals(measured[0].foodCode, null);
  assertEquals(measured[0].kcal, 15);
});

Deno.test("alias 鶏むね matches 鶏むね肉", () => {
  const found = matchFood("鶏むね", [chicken]);
  assertEquals(found?.foodCode, "11226");
});

Deno.test("bounded least squares moves protein and starch in opposite directions", () => {
  const target: Macros = { kcal: 400, proteinG: 40, fatG: 8, carbG: 35 };
  const finished = bestMeasured(
    dish([
      { name: "鶏むね肉", grams: 80, kcal: 86, proteinG: 19, fatG: 1, carbG: 0 },
      { name: "ごはん", grams: 150, kcal: 252, proteinG: 4, fatG: 0.5, carbG: 56 },
      { name: "サラダ油", grams: 5, kcal: 46, proteinG: 0, fatG: 5, carbG: 0 },
    ]),
    [chicken, rice, oil],
    target,
  );
  const chickenGrams = finished.ingredients[0].grams;
  assertEquals(chickenGrams > 88, true);
  assertEquals(finished.ingredients[1].grams < 150, true);
  assertHit(finished, target);
});

Deno.test("target profiles hit tolerance or report the remaining gap", () => {
  const profiles: Array<{ name: string; target: Macros; foods: AiDish["ingredients"]; expectHit: boolean }> = [
    {
      name: "high-protein-low-fat",
      target: { kcal: 400, proteinG: 40, fatG: 8, carbG: 35 },
      foods: [
        { name: "鶏むね肉", grams: 90, kcal: 97, proteinG: 22, fatG: 1.4, carbG: 0 },
        { name: "ごはん", grams: 160, kcal: 269, proteinG: 4, fatG: 0.5, carbG: 59 },
        { name: "サラダ油", grams: 6, kcal: 55, proteinG: 0, fatG: 6, carbG: 0 },
      ],
      expectHit: true,
    },
    {
      name: "low-carb",
      target: { kcal: 420, proteinG: 40, fatG: 22, carbG: 8 },
      foods: [
        { name: "鶏むね肉", grams: 110, kcal: 119, proteinG: 26, fatG: 1.7, carbG: 0 },
        { name: "卵", grams: 50, kcal: 76, proteinG: 6, fatG: 5, carbG: 0.2 },
        { name: "ブロッコリー", grams: 80, kcal: 27, proteinG: 3.5, fatG: 0.3, carbG: 4 },
        { name: "サラダ油", grams: 8, kcal: 74, proteinG: 0, fatG: 8, carbG: 0 },
      ],
      expectHit: true,
    },
    {
      name: "small-remaining",
      target: { kcal: 180, proteinG: 12, fatG: 5, carbG: 22 },
      foods: [
        { name: "ごはん", grams: 140, kcal: 235, proteinG: 3.5, fatG: 0.4, carbG: 52 },
        { name: "卵", grams: 50, kcal: 76, proteinG: 6, fatG: 5, carbG: 0.2 },
      ],
      expectHit: true,
    },
    {
      name: "large-remaining",
      target: { kcal: 750, proteinG: 42, fatG: 18, carbG: 95 },
      foods: [
        { name: "ごはん", grams: 180, kcal: 302, proteinG: 4.5, fatG: 0.5, carbG: 67 },
        { name: "鶏むね肉", grams: 120, kcal: 130, proteinG: 29, fatG: 1.8, carbG: 0 },
        { name: "卵", grams: 50, kcal: 76, proteinG: 6, fatG: 5, carbG: 0.2 },
        { name: "サラダ油", grams: 8, kcal: 74, proteinG: 0, fatG: 8, carbG: 0 },
        { name: "玉ねぎ", grams: 60, kcal: 22, proteinG: 0.6, fatG: 0.1, carbG: 5 },
      ],
      expectHit: true,
    },
    {
      name: "rice-cannot-make-protein",
      target: { kcal: 400, proteinG: 40, fatG: 5, carbG: 40 },
      foods: [
        { name: "ごはん", grams: 180, kcal: 302, proteinG: 4.5, fatG: 0.5, carbG: 67 },
      ],
      expectHit: false,
    },
  ];
  for (const profile of profiles) {
    const finished = bestMeasured(dish(profile.foods), pantry, profile.target);
    assertGapReported(finished, profile.target);
    assertEquals(finished.within, profile.expectHit, profile.name);
  }
});

Deno.test("chicken and rice plus pantry oil move to a 650 kcal dinner", () => {
  const target: Macros = { kcal: 650, proteinG: 32, fatG: 18, carbG: 75 };
  const finished = bestMeasured(
    dish([
      { name: "鶏むね肉", grams: 100, kcal: 999, proteinG: 1, fatG: 1, carbG: 1 },
      { name: "ごはん", grams: 150, kcal: 999, proteinG: 1, fatG: 1, carbG: 1 },
    ]),
    pantry,
    target,
  );
  const rice = finished.ingredients.find((item) => item.name === "ごはん");
  const oil = finished.ingredients.find((item) => item.name.includes("油"));
  assertEquals(rice != null && rice.grams > 150, true);
  assertEquals(oil != null && oil.grams >= 1 && oil.grams <= 10, true);
  assertGapReported(finished, target);
  assertEquals(Math.abs(finished.totals.kcal - target.kcal) <= target.kcal * 0.1 + 0.51, true);
  assertEquals(finished.within, false);
  assertEquals(finished.gapReason.includes("油は10gまで"), true);
});

Deno.test("a dish already inside tolerance is not scaled", () => {
  const target: Macros = { kcal: 108, proteinG: 24, fatG: 1.5, carbG: 0 };
  const finished = bestMeasured(dish([chickenIngredient()]), [chicken], target);
  assertEquals(finished.within, true);
  assertEquals(finished.ingredients[0].grams, 100);
  assertEquals(finished.totals.kcal, 108);
  assertEquals(gapOf(target, finished.totals).kcal, 0);
});

Deno.test("within tolerance uses kcal ±10% and the wider macro band", () => {
  const target: Macros = { kcal: 500, proteinG: 30, fatG: 15, carbG: 60 };
  assertEquals(
    withinTolerance(target, { kcal: 550, proteinG: 35, fatG: 15, carbG: 60 }),
    true,
  );
  assertEquals(
    withinTolerance(target, { kcal: 560, proteinG: 30, fatG: 15, carbG: 60 }),
    false,
  );
  assertEquals(
    withinTolerance(target, { kcal: 500, proteinG: 36, fatG: 15, carbG: 60 }),
    false,
  );
  const largeProtein: Macros = { kcal: 500, proteinG: 40, fatG: 15, carbG: 60 };
  assertEquals(
    withinTolerance(largeProtein, { kcal: 500, proteinG: 46, fatG: 15, carbG: 60 }),
    true,
  );
});

Deno.test("frying pan and aburaage stay, deep fry and truffle do not", () => {
  const home = dish([{ name: "油揚げ", grams: 20, kcal: 70, proteinG: 4, fatG: 6, carbG: 1 }]);
  home.steps = ["フライパンで両面を焼く", "カツオ節をふる"];
  assertEquals(techniqueHits("フライパンでカツオ節をふる"), false);
  assertEquals(realismIssues(home), []);
  const fried = dish([{ name: "鶏むね肉", grams: 100, kcal: 108, proteinG: 24, fatG: 1.5, carbG: 0 }]);
  fried.name = "鶏の天ぷら";
  fried.steps = ["衣をつけて揚げる"];
  assertEquals(realismIssues(fried).includes("technique"), true);
  const rare = dish([{ name: "黒トリュフ", grams: 5, kcal: 1, proteinG: 0, fatG: 0, carbG: 0 }]);
  assertEquals(realismIssues(rare).includes("rare"), true);
  const many = dish(Array.from({ length: 9 }, (_, index) => ({
    name: `野菜${index}`,
    grams: 10,
    kcal: 1,
    proteinG: 0,
    fatG: 0,
    carbG: 0,
  })));
  assertEquals(realismIssues(many).includes("too_many"), true);
  const slow = dish([chickenIngredient()]);
  slow.steps = ["45分煮込む"];
  assertEquals(realismIssues(slow).includes("time"), true);
  assertEquals(realismIssues(slow, "60分かけて").includes("time"), false);
});

Deno.test("raw plating is rejected, and seasoned cold tofu or aemono is allowed", () => {
  const items = [
    { name: "ごはん", grams: 150 },
    { name: "木綿豆腐", grams: 150 },
    { name: "トマト", grams: 80 },
  ];
  const raw = assemblyIssues(
    "ごはん、木綿豆腐、トマト",
    ["ごはんを盛る", "木綿豆腐を切る", "トマトをスライスしてのせる"],
    items,
  );
  assertEquals(raw.includes("raw"), true);
  assertEquals(raw.includes("short"), true);
  assertEquals(raw.includes("list_name"), true);
  const listed = assemblyIssues("ごはんと木綿豆腐とトマト", ["ごはん", "木綿豆腐", "トマト"], items);
  assertEquals(listed.includes("list_name"), true);
  assertEquals(listed.includes("raw"), true);
  const hiyayakkoSteps = [
    "木綿豆腐200gを6等分に切る",
    "しょうゆ8gとねぎとしょうがをのせる",
    "味がなじむまで5分置く",
  ];
  const hiyayakkoItems = [{ name: "木綿豆腐", grams: 200 }, { name: "しょうゆ", grams: 8 }];
  assertEquals(assemblyIssues("冷奴", hiyayakkoSteps, hiyayakkoItems), []);
  assertEquals(stepIssues(hiyayakkoSteps, hiyayakkoItems, "冷奴"), []);
  const plain = assemblyIssues(
    "冷奴",
    ["木綿豆腐を切る", "皿に盛る", "すぐ出す"],
    [{ name: "木綿豆腐", grams: 200 }],
  );
  assertEquals(plain.includes("raw"), true);
  assertEquals(plain.includes("short"), true);
  assertEquals(assemblyIssues("ほうれん草の和え物", [
    "ほうれん草80gを3cmに切る",
    "しょうゆ5gと砂糖3gで和える",
    "味がなじむまで5分置く",
  ], [
    { name: "ほうれん草", grams: 80 },
    { name: "しょうゆ", grams: 5 },
    { name: "砂糖", grams: 3 },
  ]), []);
  const cookedSteps = [
    "鶏むね肉113gを一口大に切る",
    "フライパンを中火にし、サラダ油15gを熱し、鶏むね肉を3分ずつ焼く",
    "しょうゆ10gとみりん13gを加えて1分絡め、中まで火を通す",
    "夕食として、ごはん198gを盛ってのせる",
  ];
  assertEquals(assemblyIssues("鶏むね肉の照り焼き丼", cookedSteps, [
    { name: "鶏むね肉", grams: 113 },
    { name: "ごはん", grams: 198 },
    { name: "しょうゆ", grams: 10 },
    { name: "みりん", grams: 13 },
  ]), []);
  assertEquals(assemblyIssues("牛乳の温め", [
    "牛乳150gを注ぐ",
    "電子レンジで1分温める",
    "すぐ飲む",
  ], [{ name: "牛乳", grams: 150 }]).includes("short"), true);
  const rawMeasured = bestMeasured({
    name: "ごはん、木綿豆腐、トマト",
    steps: ["ごはんを盛る", "木綿豆腐を切る", "トマトをスライスしてのせる"],
    extras: [],
    ingredients: [
      { name: "ごはん", grams: 150, kcal: 250, proteinG: 4, fatG: 1, carbG: 55 },
      { name: "木綿豆腐", grams: 150, kcal: 110, proteinG: 10, fatG: 6, carbG: 3 },
      { name: "トマト", grams: 80, kcal: 15, proteinG: 1, fatG: 0, carbG: 4 },
    ],
  }, [], { kcal: 400, proteinG: 15, fatG: 8, carbG: 60 });
  assertEquals(needsModelRetry([rawMeasured, rawMeasured]), true);
});

Deno.test("handler returns db nutrition and does not call the model", async () => {
  const harness = deps({ replies: [] });
  const response = await handleCookCoach(request({
    ingredients: ["鶏むね肉", "ほうれん草", "ごはん"],
    slot: "dinner",
    target_kcal: 620,
    target_protein_g: 35,
    target_fat_g: 15,
    target_carb_g: 70,
    note: "20分",
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 0);
  assertEquals(body.retried, false);
  assertEquals(body.input_tokens, 0);
  assertEquals(body.patterns.length > 0, true);
  const first = body.patterns[0];
  assertEquals(first.kind, "on_hand");
  assertEquals(first.within_tolerance, true);
  assertEquals(first.name.includes("{"), false);
  assertEquals(first.ingredients.every((item: { source: string; food_code: string }) =>
    item.source === "db" && /^[0-9]{5}$/.test(item.food_code)
  ), true);
  const oil = first.ingredients.find((item: { name: string }) => item.name.includes("油"));
  const rice = first.ingredients.find((item: { name: string }) => item.name === "ごはん");
  const chicken = first.ingredients.find((item: { name: string }) => item.name.includes("鶏"));
  assertEquals(oil != null && oil.grams <= 10 && oil.grams >= 1, true);
  assertEquals(rice != null && rice.grams >= 100 && rice.grams <= 300, true);
  assertEquals(chicken != null && chicken.grams >= 60 && chicken.grams <= 250, true);
});

Deno.test("a protein gap is filled by buying one recipe ingredient", async () => {
  const harness = deps({ replies: [] });
  const response = await handleCookCoach(request({
    ingredients: ["ごはん"],
    slot: "dinner",
    target_kcal: 500,
    target_protein_g: 35,
    target_fat_g: 12,
    target_carb_g: 55,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 0);
  const extra = body.patterns.find((pattern: { kind: string }) => pattern.kind === "extra");
  assertEquals(extra.within_tolerance, true);
  assertEquals(extra.extras.length >= 1 && extra.extras.length <= 2, true);
  assertEquals(extra.ingredients.every((item: { source: string }) => item.source === "db"), true);
});

Deno.test("returned dishes are cooked recipes, not ingredient lists", async () => {
  const harness = deps({ replies: [] });
  const response = await handleCookCoach(request({
    ingredients: ["ごはん", "木綿豆腐", "トマト"],
    slot: "dinner",
    target_kcal: 430,
    target_protein_g: 16,
    target_fat_g: 12,
    target_carb_g: 64,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 0);
  assertEquals(body.patterns.length > 0, true);
  for (const pattern of body.patterns) {
    assertEquals(pattern.name.includes("{"), false);
    assertEquals(pattern.steps.length >= 3 && pattern.steps.length <= 18, true);
    assertEquals(assemblyIssues(pattern.name, pattern.steps, pattern.ingredients.map((item: { name: string; grams: number }) => ({
      name: item.name,
      grams: item.grams,
    }))), []);
    assertEquals(/揚げる|天ぷら|唐揚げ/.test(pattern.name + pattern.steps.join("")), false);
  }
});

Deno.test("deep frying is never returned", async () => {
  const harness = deps({ replies: [modelText(999, 0)] });
  const response = await handleCookCoach(request({
    ingredients: ["鶏むね肉", "ごはん"],
    slot: "dinner",
    target_kcal: 550,
    target_protein_g: 30,
    target_fat_g: 15,
    target_carb_g: 60,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 0);
  assertEquals(body.patterns.some((pattern: { name: string; steps: string[] }) =>
    /揚げる|天ぷら|唐揚げ/.test(pattern.name + pattern.steps.join(""))
  ), false);
});

Deno.test("the same ingredients and rounded targets are served from cache", async () => {
  const cache = new Map<string, Record<string, unknown>>();
  const harness = deps({ replies: [] });
  let inserts = 0;
  harness.deps.insertUsage = () => {
    inserts += 1;
    return Promise.resolve("usage-1");
  };
  harness.deps.readCache = (key) => Promise.resolve(cache.get(key) ?? null);
  harness.deps.writeCache = (key, body) => {
    cache.set(key, body);
    return Promise.resolve();
  };
  const bodyIn = {
    ingredients: ["鶏むね肉", "ほうれん草", "ごはん"],
    slot: "dinner",
    target_kcal: 620,
    target_protein_g: 35,
    target_fat_g: 15,
    target_carb_g: 70,
  };
  const first = await handleCookCoach(request(bodyIn), harness.deps);
  assertEquals(first.status, 200);
  const near = await handleCookCoach(request({ ...bodyIn, target_kcal: 624 }), harness.deps);
  const body = await near.json();
  assertEquals(harness.calls.length, 0);
  assertEquals(body.cached, true);
  assertEquals(body.input_tokens, 0);
  assertEquals(inserts, 0);
  const other = await handleCookCoach(request({
    ...bodyIn,
    ingredients: ["鶏むね肉", "ごはん", "玉ねぎ"],
  }), harness.deps);
  assertEquals(other.status, 200);
  assertEquals(inserts, 0);
});

Deno.test("a zero on-hand input records normalized names and the clock only", async () => {
  const hits: Array<Record<string, unknown>> = [];
  const inserted: unknown[] = [];
  const harness = deps({ replies: [] });
  harness.deps.insertUsage = (row) => {
    inserted.push(row);
    return Promise.resolve("usage-1");
  };
  harness.deps.recordZeroHit = (row) => {
    hits.push(row as unknown as Record<string, unknown>);
    return Promise.resolve();
  };
  const response = await handleCookCoach(request({
    ingredients: ["トリュフ", "ほっけ"],
    slot: "dinner",
    target_kcal: 600,
    target_protein_g: 30,
    target_fat_g: 16,
    target_carb_g: 70,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.patterns.length > 0, true);
  assertEquals(String(body.patterns[0].omit_note).includes("トリュフ"), true);
  assertEquals(body.patterns[0].ingredients.some((item: { name: string }) => item.name.includes("トリュフ")), false);
  assertEquals(inserted.length, 0);
  assertEquals(hits.length, 0);
  const kept = deps({ replies: [] });
  const logged: unknown[] = [];
  kept.deps.recordZeroHit = (row) => {
    logged.push(row);
    return Promise.resolve();
  };
  const hit = await handleCookCoach(request({
    ingredients: ["卵"],
    slot: "snack",
    target_kcal: 150,
    target_protein_g: 12,
    target_fat_g: 10,
    target_carb_g: 2,
  }), kept.deps);
  const hitBody = await hit.json();
  assertEquals(hitBody.patterns[0].kind, "on_hand");
  assertEquals(logged.length, 0);
});

Deno.test("a missing recipe table returns 503 and does not call the model", async () => {
  const harness = deps({ replies: [modelText(108, 0)] });
  harness.deps.loadRecipes = () => Promise.reject(new Error("down"));
  const response = await handleCookCoach(request(onTarget), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 503);
  assertEquals(body.code, "recipes_unavailable");
  assertEquals(harness.calls.length, 0);
});

Deno.test("kcal stays inside 10 percent and a protein miss is explained", async () => {
  const harness = deps({ replies: [] });
  const response = await handleCookCoach(request({
    ingredients: ["卵"],
    slot: "dinner",
    target_kcal: 150,
    target_protein_g: 80,
    target_fat_g: 5,
    target_carb_g: 5,
  }), harness.deps);
  const body = await response.json();
  assertEquals(harness.calls.length, 0);
  assertEquals(body.ok, true);
  assertEquals(body.patterns.length > 0, true);
  const first = body.patterns[0];
  assertEquals(Math.abs(first.kcal - 150) <= 15.51, true);
  assertEquals(first.within_tolerance, false);
  assertEquals(String(first.gap_reason).includes("たんぱく質"), true);
});

Deno.test("cook coach ignores the shared daily cap", async () => {
  assertEquals(aiDailyLimitDefault, 15);
  const harness = deps({ used: 15, replies: [modelText(108, 50)] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.ok, true);
  assertEquals(harness.calls.length, 0);
});

Deno.test("plus is required", async () => {
  const harness = deps({ plus: false, replies: [] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  assertEquals(response.status, 403);
  assertEquals(harness.calls.length, 0);
});

Deno.test("local eval scores every scenario without a network call", () => {
  const report = runLocalEval();
  assertEquals(report.scenarios >= 30, true);
  assertEquals(report.failed, []);
  assertEquals(report.miss.inputs >= 10, true);
  assertEquals(report.miss.onHand + report.miss.extra + report.miss.zero, report.miss.inputs);
  assertEquals(report.miss.zero / report.miss.inputs <= 0.2, true);
  let onHand = 0;
  let zero = 0;
  for (const scenario of evalScenarios) {
    const plan = planScenario(scenario);
    if (plan.a) {
      onHand += 1;
    }
    if (!plan.a && !plan.b) {
      zero += 1;
    }
  }
  assertEquals(zero, 0);
  assertEquals(onHand / evalScenarios.length >= 0.8, true);
});

Deno.test("buying one or two foods fills a protein gap, and an impossible target stays empty", () => {
  const protein = evalScenarios.find((item) => item.id === "dinner-rice-needs-protein");
  if (!protein) {
    throw new Error("missing scenario");
  }
  const closed = planScenario(protein);
  if (!closed.b) {
    throw new Error("missing buy-extra plan");
  }
  assertEquals(closed.b != null && closed.b.within, true);
  assertEquals(closed.b != null && closed.b.extras.length >= 1 && closed.b.extras.length <= 2, true);
  const impossible = evalScenarios.find((item) => item.id === "dinner-protein-impossible");
  if (!impossible) {
    throw new Error("missing scenario");
  }
  const missed = planScenario(impossible);
  const shown = missed.a ?? missed.b;
  if (!shown) {
    throw new Error("missing closest plan");
  }
  assertEquals(Math.abs(shown.totals.kcal - impossible.target.kcal) <= impossible.target.kcal * 0.1 + 0.51, true);
  assertEquals(shown.gapReason.includes("たんぱく質"), true);
});

Deno.test("implausible meat calories are replaced, and eggs stay on a 50g grid", () => {
  const measured = measureIngredients(
    dish([{ name: "鶏むね肉", grams: 100, kcal: 10, proteinG: 1, fatG: 0, carbG: 0 }]),
    [],
  );
  assertEquals(measured[0].source, "ai");
  assertEquals(measured[0].kcal, 108);
  const snack = evalScenarios.find((item) => item.id === "snack-egg");
  if (!snack) {
    throw new Error("missing scenario");
  }
  const pair = planScenario(snack);
  if (!pair.a) {
    throw new Error("missing egg dish");
  }
  const eggs = pair.a.ingredients.filter((item) => item.name.includes("卵"));
  assertEquals(eggs.length > 0, true);
  assertEquals(eggs.every((item) => item.grams % 50 === 0 && item.grams >= 50 && item.grams <= 200), true);
  const dinner = planScenario(evalScenarios.find((item) => item.id === "dinner-chicken-spinach")!);
  if (!dinner.a) {
    throw new Error("missing chicken rice dish");
  }
  const oil = dinner.a.ingredients.find((item) => item.name.includes("油"));
  const rice = dinner.a.ingredients.find((item) => item.name === "ごはん");
  const chicken = dinner.a.ingredients.find((item) => item.name.includes("鶏"));
  assertEquals(oil != null && oil.grams <= 8 && oil.grams >= 1, true);
  assertEquals(dinner.a.ingredients.filter((item) => item.name.includes("油")).every((item) => item.grams <= 8), true);
  assertEquals(rice != null && rice.grams >= 100 && rice.grams <= 300, true);
  assertEquals(chicken != null && chicken.grams >= 60 && chicken.grams <= 250, true);
  assertEquals(dinner.a.steps.some((step) => step.includes("ごはん") && step.includes("塩")), false);
  assertEquals(dinner.a.steps.some((step) => step.includes("塩") && /炒|焼/.test(step)), true);
});

Deno.test("zero remaining does not call the model, and 1200 kcal is accepted", async () => {
  assertEquals(
    explainRejectedTarget({ ingredients: ["卵"], slot: "dinner", target_kcal: 0 })?.message,
    "今日の目標は、もう足りています。",
  );
  const blocked = deps({ replies: [] });
  const none = await handleCookCoach(request({ ...onTarget, target_kcal: 0 }), blocked.deps);
  const noneBody = await none.json();
  assertEquals(none.status, 422);
  assertEquals(noneBody.message, "今日の目標は、もう足りています。");
  assertEquals(blocked.calls.length, 0);
  const small = await handleCookCoach(request({ ...onTarget, target_kcal: 20 }), blocked.deps);
  const smallBody = await small.json();
  assertEquals(smallBody.message, "この食事の目標が少ないため、献立は作れません。");
  assertEquals(blocked.calls.length, 0);
  const harness = deps({ replies: [modelText(108, 0), modelText(108, 0)] });
  const response = await handleCookCoach(request({
    ...onTarget,
    target_kcal: 1200,
    target_protein_g: 70,
    target_fat_g: 30,
    target_carb_g: 140,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.target.kcal, 1200);
  assertEquals(harness.calls.length, 0);
});

Deno.test("ingredient names match only through the synonym table, never by partial match", async () => {
  const { canonicalFood, namesMatch } = await import("./cook-coach/select.ts");
  const different: Array<[string, string]> = [
    ["玉ねぎ", "ねぎ"],
    ["玉ねぎ", "長ねぎ"],
    ["ミニキャロット", "にんじん"],
    ["牛ひき肉", "ひき肉"],
    ["鶏ひき肉", "豚ひき肉"],
    ["ごま油", "ごま"],
    ["絹ごし豆腐", "木綿豆腐"],
    ["玄米ごはん", "ごはん"],
    ["鶏もも肉", "鶏むね肉"],
    ["豚ロース", "豚こま"],
    ["粉チーズ", "チーズ"],
    ["キャベツ", "紫キャベツ"],
    ["卵", "卵豆腐"],
    ["白菜", "白菜キムチ"],
  ];
  for (const [left, right] of different) {
    assertEquals(namesMatch(left, right), false, `${left} / ${right}`);
  }
  const same: Array<[string, string]> = [
    ["豚こま", "豚こま切れ"],
    ["豚こま", "豚肉"],
    ["鶏むね", "鶏むね肉"],
    ["長ねぎ", "ねぎ"],
    ["玉葱", "玉ねぎ"],
    ["ライス", "ごはん"],
    ["顆粒だし", "だし"],
    ["タマネギ", "たまねぎ"],
    ["ミニトマト", "トマト"],
  ];
  for (const [left, right] of same) {
    assertEquals(namesMatch(left, right), true, `${left} / ${right}`);
  }
  assertEquals(canonicalFood("  "), "");
});

Deno.test("no two foods share a synonym", async () => {
  const { cookFoods } = await import("./cook-coach/foods.ts");
  const seen = new Map<string, string>();
  for (const item of cookFoods) {
    for (const name of [item.label, ...item.match]) {
      const key = normalizeFoodName(name);
      const owner = seen.get(key);
      assertEquals(owner == null || owner === item.id, true, `${name}: ${owner} / ${item.id}`);
      seen.set(key, item.id);
    }
  }
});

Deno.test("onion alone does not make long onion on hand, and dashi stays within a home amount per meal", async () => {
  const { selectCookPlans, seasoningOverCap } = await import("./cook-coach/select.ts");
  const pork = selectCookPlans(cookRecipes, {
    ingredients: ["豚こま", "玉ねぎ"],
    slot: "lunch",
    target: { kcal: 600, proteinG: 30, fatG: 18, carbG: 80 },
  });
  assertEquals(pork.a != null, true);
  const longOnion = pork.a!.ingredients.filter((item) => item.name === "ねぎ");
  assertEquals(longOnion.every((item) => item.extra === true), true);
  assertEquals(pork.a!.extras.length, 0);
  const tofu = selectCookPlans(cookRecipes, {
    ingredients: ["木綿豆腐", "卵", "キャベツ"],
    slot: "dinner",
    target: { kcal: 650, proteinG: 40, fatG: 18, carbG: 80 },
  });
  for (const plan of [pork.a, pork.b, tofu.a, tofu.b]) {
    if (!plan) continue;
    const dashi = plan.ingredients.filter((item) => item.name === "顆粒だし").reduce((sum, item) => sum + item.grams, 0);
    assertEquals(dashi <= 6, true, `${plan.name}: ${dashi}g`);
    assertEquals(plan.name.includes("煮込み湯豆腐"), false);
  }
  assertEquals(seasoningOverCap([{ name: "顆粒だし", grams: 4 }, { name: "顆粒だし", grams: 3 }]), true);
  assertEquals(seasoningOverCap([{ name: "顆粒だし", grams: 3 }, { name: "顆粒だし", grams: 3 }]), false);
});

Deno.test("plans do not depend on recipe order, and chicken breast with rice keeps a buy-one plan within tolerance", async () => {
  const { selectCookPlans } = await import("./cook-coach/select.ts");
  const input = {
    ingredients: ["鶏むね肉", "ごはん"],
    slot: "dinner",
    target: { kcal: 650, proteinG: 40, fatG: 18, carbG: 80 },
  };
  const forward = selectCookPlans(cookRecipes, input);
  const reversed = selectCookPlans([...cookRecipes].reverse(), input);
  const rotated = selectCookPlans([...cookRecipes.slice(37), ...cookRecipes.slice(0, 37)], input);
  for (const other of [reversed, rotated]) {
    assertEquals(other.a?.name, forward.a?.name);
    assertEquals(other.b?.name, forward.b?.name);
    assertEquals(other.b?.totals, forward.b?.totals);
  }
  assertEquals(forward.b != null && forward.b.within, true, forward.b?.name);
});

Deno.test("consomme uses the solid bouillon code and food values follow the official table", async () => {
  const { cookFood } = await import("./cook-coach/foods.ts");
  const consomme = cookFood("consomme");
  assertEquals(consomme.code, "17027");
  assertEquals([consomme.kcal, consomme.proteinG, consomme.fatG, consomme.carbG], [233, 7, 4.3, 42.1]);
  assertEquals(cookFood("shiitake").code, "08039");
  assertEquals(cookFood("beef").code, "11047");
  const names = cookRecipes.map((recipe) => recipe.name);
  assertEquals(names.includes("湯豆腐"), true);
  assertEquals(names.some((name) => name.includes("煮込み湯豆腐")), false);
});

Deno.test("chicken breast with rice: plan A no longer overshoots protein by a third or more", async () => {
  const { selectCookPlans } = await import("./cook-coach/select.ts");
  for (const kcal of [550, 700]) {
    const target = { kcal, proteinG: Math.round(kcal * 0.2 / 4), fatG: Math.round(kcal * 0.25 / 9), carbG: Math.round(kcal * 0.55 / 4) };
    const plans = selectCookPlans(cookRecipes, { ingredients: ["鶏むね肉", "ごはん"], slot: "dinner", target });
    const a = plans.a!;
    assertEquals(a != null, true);
    assertEquals(Math.abs(a.totals.kcal - kcal) <= kcal * 0.1, true, `${kcal} ${a.name}`);
    // 以前は鶏むね肉140g固定で +35%（550kcal）と +54%（700kcal）だった。
    assertEquals(a.totals.proteinG <= target.proteinG * 1.2, true, `${kcal} ${a.name} P${a.totals.proteinG}`);
  }
});
