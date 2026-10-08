import { assertEquals } from "jsr:@std/assert@1";

import { cookRequestBody } from "./cook-coach/model.ts";
import {
  aiDailyLimitDefault,
  cookCacheKey,
  cookCacheMaterial,
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
import { assemblyIssues, needsModelRetry, stepIssues } from "./cook-coach/plan.ts";
import { explainRejectedTarget } from "./cook-coach/handler.ts";
import {
  cookOutputSchema,
  cookRetryPrompt,
  cookSystemPrompt,
  cookUserPrompt,
  parseCookModel,
} from "./cook-coach/prompt.ts";
import {
  lightInputUsdPerMillionDefault,
  lightOutputUsdPerMillionDefault,
  lightCacheReadUsdPerMillionDefault,
  lightCacheWriteUsdPerMillionDefault,
} from "./analyze-meal-photo/policy.ts";

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
      expectHit: false,
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
  assertEquals(oil != null && oil.grams >= 1, true);
  assertGapReported(finished, target);
  assertEquals(finished.within, true, JSON.stringify({
    totals: finished.totals,
    gap: finished.gap,
    grams: finished.ingredients.map((item) => [item.name, item.grams, item.kcal]),
  }));
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

Deno.test("handler returns db nutrition without a second model call", async () => {
  const harness = deps({ replies: [modelText(999, 0)] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 1);
  assertEquals(body.retried, false);
  assertEquals(body.patterns[0].ingredients[0].source, "db");
  assertEquals(body.patterns[0].ingredients[0].kcal, 108);
  assertEquals(body.patterns[0].kcal, 108);
  assertEquals(body.patterns[0].gap_kcal, 0);
});

Deno.test("handler retries once when the gap stays outside tolerance", async () => {
  const fixed = {
    a: {
      n: "合いびき肉の炒め",
      s: [
        "合いびき肉80gをほぐす",
        "フライパンを中火にし、4分炒める",
        "中まで火を通して器に盛る",
      ],
      i: [{ n: "合いびき肉", g: 80, k: 200, p: 16, f: 14, c: 0 }],
    },
    b: {
      n: "豆腐炒め",
      s: ["肉と豆腐を中まで加熱する", "器に盛る"],
      x: ["豆腐"],
      i: [
        { n: "合いびき肉", g: 80, k: 180, p: 14, f: 12, c: 0 },
        { n: "豆腐", g: 80, k: 20, p: 2, f: 1, c: 1 },
      ],
    },
  };
  const off = {
    a: {
      n: "塩鶏",
      s: [
        "ブロッコリー80gを小房に分ける",
        "フライパンを中火にし、4分炒める",
        "器に盛る",
      ],
      i: [{ n: "ブロッコリー", g: 80, k: 26, p: 3, f: 0.3, c: 4 }],
    },
    b: {
      n: "豆腐の塩鶏",
      s: [
        "ブロッコリー80gと豆腐80gを切る",
        "フライパンを中火にし、4分炒める",
        "器に盛る",
      ],
      x: ["豆腐"],
      i: [
        { n: "ブロッコリー", g: 80, k: 26, p: 3, f: 0.3, c: 4 },
        { n: "豆腐", g: 80, k: 40, p: 4, f: 2, c: 1 },
      ],
    },
  };
  const harness = deps({
    foods: [],
    replies: [JSON.stringify(off), JSON.stringify(fixed)],
  });
  const response = await handleCookCoach(request({
    ingredients: ["鶏むね肉"],
    slot: "dinner",
    target_kcal: 200,
    target_protein_g: 16,
    target_fat_g: 13,
    target_carb_g: 1,
  }), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 2);
  assertEquals(body.retried, true);
  assertEquals(body.calls.length, 2);
  assertEquals(body.patterns[0].name, "合いびき肉の炒め");
  assertEquals(body.patterns[0].ingredients[0].source, "ai");
  assertEquals(body.patterns[0].kcal, 200);
});

Deno.test("raw ingredient lists are regenerated once and not returned", async () => {
  const raw = {
    a: {
      n: "ごはん、木綿豆腐、トマト",
      s: ["ごはんを盛る", "木綿豆腐を切る", "トマトをスライスしてのせる"],
      i: [
        { n: "ごはん", g: 150, k: 250, p: 4, f: 1, c: 55 },
        { n: "木綿豆腐", g: 150, k: 110, p: 10, f: 6, c: 3 },
        { n: "トマト", g: 80, k: 15, p: 1, f: 0, c: 4 },
      ],
    },
    b: {
      n: "ごはんと木綿豆腐",
      s: ["ごはんを盛る", "木綿豆腐をのせる", "そのまま出す"],
      x: ["卵"],
      i: [
        { n: "ごはん", g: 150, k: 250, p: 4, f: 1, c: 55 },
        { n: "木綿豆腐", g: 100, k: 73, p: 7, f: 4, c: 2 },
      ],
    },
  };
  const cooked = {
    a: {
      n: "木綿豆腐とトマトの炒め丼",
      s: [
        "木綿豆腐150gとトマト80gを切る",
        "フライパンを中火にし、サラダ油5gで5分炒める",
        "しょうゆ8gを絡めて、ごはん150gにのせる",
      ],
      i: [
        { n: "ごはん", g: 150, k: 252, p: 4, f: 1, c: 56 },
        { n: "木綿豆腐", g: 150, k: 110, p: 10, f: 6, c: 3 },
        { n: "トマト", g: 80, k: 15, p: 1, f: 0, c: 4 },
        { n: "サラダ油", g: 5, k: 46, p: 0, f: 5, c: 0 },
        { n: "しょうゆ", g: 8, k: 6, p: 1, f: 0, c: 1 },
      ],
    },
    b: {
      n: "木綿豆腐と卵の炒め",
      s: [
        "木綿豆腐100gを切って卵1個を溶く",
        "フライパンを中火にし、5分炒める",
        "塩1gを振って火を止める",
      ],
      x: ["卵"],
      i: [
        { n: "木綿豆腐", g: 100, k: 73, p: 7, f: 4, c: 2 },
        { n: "卵", g: 50, k: 76, p: 6, f: 5, c: 0 },
        { n: "塩", g: 1, k: 0, p: 0, f: 0, c: 0 },
      ],
    },
  };
  const harness = deps({
    foods: [],
    replies: [JSON.stringify(raw), JSON.stringify(cooked)],
  });
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
  assertEquals(harness.calls.length, 2);
  assertEquals(body.retried, true);
  const names = body.patterns.map((pattern: { name: string; steps: string[] }) => pattern.name);
  assertEquals(names.some((name: string) => name.includes("、")), false);
  for (const pattern of body.patterns) {
    assertEquals(assemblyIssues(pattern.name, pattern.steps, pattern.ingredients.map((item: { name: string; grams: number }) => ({
      name: item.name,
      grams: item.grams,
    }))), []);
  }
});

Deno.test("deep frying is regenerated once and not returned", async () => {
  const fried = {
    a: {
      n: "鶏の天ぷら",
      s: ["衣をつけて揚げる"],
      i: [{ n: "鶏むね肉", g: 100, k: 108, p: 24, f: 1.5, c: 0 }],
    },
    b: {
      n: "豆腐の天ぷら",
      s: ["油で揚げる"],
      x: ["豆腐"],
      i: [
        { n: "鶏むね肉", g: 100, k: 108, p: 24, f: 1.5, c: 0 },
        { n: "豆腐", g: 80, k: 40, p: 4, f: 2, c: 1 },
      ],
    },
  };
  const harness = deps({ replies: [JSON.stringify(fried), modelText(999, 0)] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(harness.calls.length, 2);
  assertEquals(body.patterns.some((pattern: { name: string }) => pattern.name.includes("天ぷら")), false);
  assertEquals(body.patterns[0].name, "塩鶏");
});

Deno.test("the same ingredients and rounded targets do not call the model again", async () => {
  const cache = new Map<string, Record<string, unknown>>();
  const harness = deps({ replies: [modelText(999, 0)] });
  harness.deps.readCache = (key) => Promise.resolve(cache.get(key) ?? null);
  harness.deps.writeCache = (key, body) => {
    cache.set(key, body);
    return Promise.resolve();
  };
  const first = await handleCookCoach(request(onTarget), harness.deps);
  assertEquals(first.status, 200);
  const near = {
    ...onTarget,
    target_kcal: 112,
  };
  const second = await handleCookCoach(request(near), harness.deps);
  const body = await second.json();
  assertEquals(harness.calls.length, 1);
  assertEquals(body.cached, true);
  assertEquals(body.input_tokens, 0);
  assertEquals(body.patterns[0].kcal, 108);
  const other = await handleCookCoach(request({
    ...onTarget,
    ingredients: ["鶏むね肉", "玉ねぎ"],
  }), harness.deps);
  assertEquals(other.status, 200);
  assertEquals(harness.calls.length, 2);
});

Deno.test("rounded cache keys match across a 10 kcal band", async () => {
  const left = cookCacheMaterial({
    ingredients: ["卵", "鶏むね肉"],
    slot: "dinner",
    targetKcal: 648,
    targetProteinG: 31.4,
    targetFatG: 10,
    targetCarbG: 40,
    note: "20分",
    avoid: ["えび", "卵"],
  });
  const right = cookCacheMaterial({
    ingredients: ["鶏むね肉", "卵"],
    slot: "dinner",
    targetKcal: 652,
    targetProteinG: 31,
    targetFatG: 10.4,
    targetCarbG: 40,
    note: "20分",
    avoid: ["卵", "えび"],
  });
  assertEquals(left, right);
  assertEquals((await cookCacheKey(left)).length, 64);
});

Deno.test("a third model call is not made when the retry is still off", async () => {
  const harness = deps({
    foods: [],
    replies: [modelText(10, 10), modelText(10, 10)],
  });
  const response = await handleCookCoach(request({
    ingredients: ["鶏むね肉"],
    slot: "lunch",
    target_kcal: 600,
    target_protein_g: 40,
    target_fat_g: 20,
    target_carb_g: 70,
  }), harness.deps);
  const body = await response.json();
  assertEquals(harness.calls.length, 2);
  assertEquals(body.ok, true);
  assertEquals(body.patterns[0].within_tolerance, false);
  assertEquals(body.patterns[0].gap_kcal > 0, true);
});

Deno.test("daily cap is shared and says 本日の上限に達しました", async () => {
  assertEquals(aiDailyLimitDefault, 15);
  const harness = deps({ used: 15, replies: [] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  const body = await response.json();
  assertEquals(response.status, 429);
  assertEquals(body.code, "daily_cap");
  assertEquals(body.message, "本日の上限に達しました");
  assertEquals(harness.calls.length, 0);
});

Deno.test("plus is required", async () => {
  const harness = deps({ plus: false, replies: [] });
  const response = await handleCookCoach(request(onTarget), harness.deps);
  assertEquals(response.status, 403);
  assertEquals(harness.calls.length, 0);
});

Deno.test("model request disables thinking and caches the system prompt", () => {
  const body = cookRequestBody({
    model: "claude-haiku-5-5",
    maxTokens: 900,
    userText: "x",
  });
  assertEquals(body.thinking, { type: "disabled" });
  const system = body.system as Array<Record<string, unknown>>;
  assertEquals(system[0].cache_control, { type: "ephemeral" });
  assertEquals(system[0].text, cookSystemPrompt);
});

const sampleUser = cookUserPrompt({
  ingredients: ["鶏むね肉", "玉ねぎ", "にんじん", "ごはん", "卵"],
  slotLabel: "夕食",
  targetKcal: 650,
  targetProteinG: 32,
  targetFatG: 18,
  targetCarbG: 75,
  note: "20分",
  avoid: [],
});

const sampleOutput = JSON.stringify({
  a: {
    n: "鶏肉と野菜の煮物",
    s: [
      "鶏肉は一口大に切り、中まで火を通す",
      "玉ねぎとにんじんを薄切りにする",
      "鍋で鶏肉を炒めてから野菜を加える",
      "水としょうゆを入れて10分煮る",
      "ごはんと卵焼きを添える",
    ],
    i: [
      { n: "鶏むね肉", g: 120, k: 130, p: 28, f: 2, c: 0 },
      { n: "玉ねぎ", g: 80, k: 30, p: 1, f: 0, c: 7 },
      { n: "にんじん", g: 50, k: 18, p: 0, f: 0, c: 4 },
      { n: "ごはん", g: 150, k: 234, p: 4, f: 1, c: 55 },
      { n: "卵", g: 50, k: 76, p: 6, f: 5, c: 0 },
      { n: "しょうゆ", g: 8, k: 6, p: 1, f: 0, c: 1 },
    ],
  },
  b: {
    n: "鶏肉のトマト煮",
    x: ["トマト", "オリーブ油"],
    s: [
      "鶏肉は中まで火を通す",
      "玉ねぎを炒める",
      "トマトを崩して加える",
      "10分煮て塩で味を整える",
      "ごはんにのせる",
    ],
    i: [
      { n: "鶏むね肉", g: 110, k: 119, p: 26, f: 2, c: 0 },
      { n: "玉ねぎ", g: 60, k: 22, p: 1, f: 0, c: 5 },
      { n: "ごはん", g: 160, k: 250, p: 4, f: 1, c: 59 },
      { n: "トマト", g: 80, k: 15, p: 1, f: 0, c: 3 },
      { n: "オリーブ油", g: 5, k: 46, p: 0, f: 5, c: 0 },
    ],
  },
});

function estimateClaudeTokens(text: string): number {
  let tokens = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    if (code <= 0x7f) {
      tokens += 0.28;
    } else {
      tokens += 1.6;
    }
  }
  return Math.ceil(tokens);
}

function jpy(args: {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
}): number {
  const rate = 150;
  const million = 1_000_000;
  return (
    (args.input * lightInputUsdPerMillionDefault * rate) / million +
    (args.output * lightOutputUsdPerMillionDefault * rate) / million +
    (args.cacheRead * lightCacheReadUsdPerMillionDefault * rate) / million +
    (args.cacheWrite * lightCacheWriteUsdPerMillionDefault * rate) / million
  );
}

Deno.test("local eval scores every scenario without a network call", () => {
  const report = runLocalEval();
  assertEquals(report.scenarios >= 30, true);
  assertEquals(report.failed, []);
});

Deno.test("adding one or two foods closes a protein gap, and an impossible target says why", () => {
  const protein = evalScenarios.find((item) => item.id === "dinner-rice-needs-protein");
  if (!protein) {
    throw new Error("missing scenario");
  }
  const closed = planScenario(protein);
  assertEquals(closed.a.within, false);
  assertEquals(closed.a.gapReason.includes("たんぱく質"), true);
  assertEquals(closed.b.within, true);
  assertEquals(closed.b.ingredients.filter((item) => item.extra).length <= 2, true);
  assertGapReported(closed.b, protein.target);
  const impossible = evalScenarios.find((item) => item.id === "dinner-protein-impossible");
  if (!impossible) {
    throw new Error("missing scenario");
  }
  const missed = planScenario(impossible);
  assertEquals(missed.b.within, false);
  assertEquals(missed.b.gapReason.includes("たんぱく質"), true);
  assertGapReported(missed.a, impossible.target);
  assertGapReported(missed.b, impossible.target);
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
  const eggs = pair.a.ingredients.filter((item) => item.name.includes("卵"));
  assertEquals(eggs.length > 0, true);
  assertEquals(eggs.every((item) => item.grams % 50 === 0 && item.grams >= 50 && item.grams <= 200), true);
  const dinner = planScenario(evalScenarios.find((item) => item.id === "dinner-chicken-rice")!);
  const oil = dinner.a.ingredients.find((item) => item.name.includes("油"));
  const rice = dinner.a.ingredients.find((item) => item.name === "ごはん");
  const chicken = dinner.a.ingredients.find((item) => item.name.includes("鶏"));
  assertEquals(oil != null && oil.grams <= 15 && oil.grams >= 1, true);
  assertEquals(rice != null && rice.grams >= 100 && rice.grams <= 300, true);
  assertEquals(chicken != null && chicken.grams >= 60 && chicken.grams <= 250, true);
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
  assertEquals(harness.calls.length <= 2, true);
});

Deno.test("a realistic run stays under 0.3 JPY even with the retry", () => {
  const schema = JSON.stringify(cookOutputSchema);
  const requestBody = JSON.stringify(cookRequestBody({
    model: "claude-haiku-5-5",
    maxTokens: 900,
    userText: sampleUser,
  }));
  const systemTokens = estimateClaudeTokens(cookSystemPrompt);
  const schemaTokens = estimateClaudeTokens(schema);
  const userTokens = estimateClaudeTokens(sampleUser);
  const outputTokens = estimateClaudeTokens(sampleOutput);
  const parsed = parseCookModel(JSON.parse(sampleOutput));
  if (!parsed) {
    throw new Error("sample output did not parse");
  }
  const retryUser = cookRetryPrompt({
    first: sampleUser,
    dishes: [
      bestMeasured(parsed.a, [], {
        kcal: 650,
        proteinG: 32,
        fatG: 18,
        carbG: 75,
      }),
      bestMeasured(parsed.b, [], {
        kcal: 650,
        proteinG: 32,
        fatG: 18,
        carbG: 75,
      }),
    ],
  });
  const retryUserTokens = estimateClaudeTokens(retryUser);
  const overhead = estimateClaudeTokens(requestBody) - systemTokens - userTokens - schemaTokens;
  const fixedInput = Math.max(0, overhead) + schemaTokens;
  const first = jpy({
    input: fixedInput + userTokens,
    output: outputTokens,
    cacheRead: 0,
    cacheWrite: systemTokens,
  });
  const second = jpy({
    input: fixedInput + retryUserTokens,
    output: outputTokens,
    cacheRead: systemTokens,
    cacheWrite: 0,
  });
  const withRetry = first + second;
  const average = first + 0.25 * second;
  console.log(JSON.stringify({
    systemTokens,
    schemaTokens,
    userTokens,
    outputTokens,
    retryUserTokens,
    firstJpy: Number(first.toFixed(4)),
    withRetryJpy: Number(withRetry.toFixed(4)),
    averageJpy: Number(average.toFixed(4)),
    usdJpy: 150,
    inputUsdPerMillion: lightInputUsdPerMillionDefault,
    outputUsdPerMillion: lightOutputUsdPerMillionDefault,
  }));
  assertEquals(first < 0.3, true);
  assertEquals(withRetry < 0.3, true);
  assertEquals(average < 0.3, true);
});
