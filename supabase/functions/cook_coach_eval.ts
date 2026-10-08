// 自炊コーチのローカル採点。CI はここをモック無し・ネットワーク無しで回す。
// デプロイ済み関数へ当てるときは --live と COOK_EVAL_CALL_CAP が必須。
//
//   deno run -A supabase/functions/cook_coach_eval.ts
//   COOK_EVAL_CALL_CAP=5 COOK_EVAL_URL=https://example/functions/v1/cook-coach \
//     COOK_EVAL_TOKEN=... deno run -A supabase/functions/cook_coach_eval.ts --live

import {
  bestMeasured,
  gramsAreRealistic,
  isSeasoning,
  normalizeFoodName,
  withinTolerance,
  type FoodRow,
  type Macros,
  type MeasuredDish,
} from "./cook-coach/match.ts";
import { finalizePair, foodKey, nameMismatch, stepIssues, totalCookingMinutes } from "./cook-coach/plan.ts";
import type { AiDish } from "./cook-coach/match.ts";

export type EvalScenario = {
  id: string;
  slot: "breakfast" | "lunch" | "dinner" | "snack";
  ingredients: string[];
  target: Macros;
  note: string;
  avoid: string[];
  expectClose: boolean;
};

export const evalScenarios: EvalScenario[] = [
  { id: "dinner-chicken-rice", slot: "dinner", ingredients: ["鶏むね肉", "ごはん"], target: { kcal: 650, proteinG: 32, fatG: 18, carbG: 75 }, note: "20分", avoid: [], expectClose: true },
  { id: "lunch-chicken-onion", slot: "lunch", ingredients: ["鶏むね肉", "ごはん", "玉ねぎ"], target: { kcal: 550, proteinG: 28, fatG: 15, carbG: 65 }, note: "", avoid: [], expectClose: true },
  { id: "breakfast-egg-rice", slot: "breakfast", ingredients: ["卵", "ごはん"], target: { kcal: 450, proteinG: 18, fatG: 12, carbG: 55 }, note: "15分", avoid: [], expectClose: true },
  { id: "snack-egg", slot: "snack", ingredients: ["卵"], target: { kcal: 150, proteinG: 12, fatG: 10, carbG: 2 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-rice-needs-protein", slot: "dinner", ingredients: ["ごはん"], target: { kcal: 500, proteinG: 35, fatG: 12, carbG: 55 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-small-rice-egg", slot: "dinner", ingredients: ["ごはん", "卵"], target: { kcal: 180, proteinG: 12, fatG: 5, carbG: 22 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-large", slot: "dinner", ingredients: ["鶏むね肉", "ごはん", "卵"], target: { kcal: 1200, proteinG: 70, fatG: 30, carbG: 140 }, note: "30分", avoid: [], expectClose: true },
  { id: "dinner-high-protein-low-fat", slot: "dinner", ingredients: ["鶏むね肉", "ブロッコリー"], target: { kcal: 400, proteinG: 40, fatG: 8, carbG: 20 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-low-carb", slot: "dinner", ingredients: ["鶏むね肉", "卵", "ブロッコリー"], target: { kcal: 420, proteinG: 40, fatG: 22, carbG: 8 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-only-egg-rice", slot: "dinner", ingredients: ["卵", "ごはん"], target: { kcal: 600, proteinG: 30, fatG: 18, carbG: 70 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-many", slot: "dinner", ingredients: ["鶏むね肉", "豚こま切れ", "卵", "木綿豆腐", "ごはん", "玉ねぎ", "にんじん", "キャベツ"], target: { kcal: 800, proteinG: 45, fatG: 25, carbG: 80 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-dont-mix", slot: "dinner", ingredients: ["鶏むね肉", "チョコレート"], target: { kcal: 500, proteinG: 30, fatG: 15, carbG: 40 }, note: "", avoid: [], expectClose: true },
  { id: "breakfast-tofu-rice", slot: "breakfast", ingredients: ["木綿豆腐", "ごはん"], target: { kcal: 400, proteinG: 20, fatG: 10, carbG: 50 }, note: "15分", avoid: [], expectClose: true },
  { id: "lunch-salmon-cabbage", slot: "lunch", ingredients: ["鮭", "キャベツ"], target: { kcal: 500, proteinG: 30, fatG: 15, carbG: 40 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-pork-veg", slot: "dinner", ingredients: ["豚こま切れ", "玉ねぎ", "キャベツ"], target: { kcal: 650, proteinG: 28, fatG: 22, carbG: 70 }, note: "", avoid: [], expectClose: true },
  { id: "snack-potato", slot: "snack", ingredients: ["じゃがいも"], target: { kcal: 160, proteinG: 5, fatG: 3, carbG: 25 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-protein-deficit", slot: "dinner", ingredients: ["ごはん", "キャベツ"], target: { kcal: 550, proteinG: 40, fatG: 10, carbG: 60 }, note: "", avoid: [], expectClose: true },
  { id: "snack-rice-too-small", slot: "snack", ingredients: ["ごはん"], target: { kcal: 150, proteinG: 6, fatG: 3, carbG: 20 }, note: "", avoid: [], expectClose: true },
  { id: "lunch-egg-tomato-rice", slot: "lunch", ingredients: ["卵", "トマト", "ごはん"], target: { kcal: 480, proteinG: 20, fatG: 14, carbG: 55 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-chicken-spinach", slot: "dinner", ingredients: ["鶏むね肉", "ほうれん草", "ごはん"], target: { kcal: 620, proteinG: 35, fatG: 15, carbG: 70 }, note: "20分", avoid: [], expectClose: true },
  { id: "breakfast-natto", slot: "breakfast", ingredients: ["納豆", "ごはん", "卵"], target: { kcal: 420, proteinG: 22, fatG: 14, carbG: 50 }, note: "", avoid: [], expectClose: true },
  { id: "lunch-pork-rice", slot: "lunch", ingredients: ["豚こま切れ", "ごはん"], target: { kcal: 600, proteinG: 25, fatG: 20, carbG: 70 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-chicken-potato", slot: "dinner", ingredients: ["鶏むね肉", "じゃがいも", "玉ねぎ"], target: { kcal: 580, proteinG: 32, fatG: 16, carbG: 55 }, note: "", avoid: [], expectClose: true },
  { id: "snack-milk", slot: "snack", ingredients: ["牛乳"], target: { kcal: 160, proteinG: 8, fatG: 8, carbG: 12 }, note: "", avoid: [], expectClose: true },
  { id: "breakfast-egg-needs-carb", slot: "breakfast", ingredients: ["卵"], target: { kcal: 350, proteinG: 20, fatG: 15, carbG: 30 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-tofu-egg-cabbage", slot: "dinner", ingredients: ["木綿豆腐", "卵", "キャベツ"], target: { kcal: 480, proteinG: 30, fatG: 18, carbG: 25 }, note: "", avoid: [], expectClose: true },
  { id: "lunch-salmon-rice", slot: "lunch", ingredients: ["鮭", "ごはん", "ほうれん草"], target: { kcal: 520, proteinG: 32, fatG: 14, carbG: 50 }, note: "", avoid: [], expectClose: true },
  { id: "snack-cabbage", slot: "snack", ingredients: ["キャベツ", "卵"], target: { kcal: 180, proteinG: 10, fatG: 8, carbG: 12 }, note: "10分", avoid: [], expectClose: true },
  { id: "dinner-avoid-oil", slot: "dinner", ingredients: ["鶏むね肉", "ごはん", "卵"], target: { kcal: 550, proteinG: 35, fatG: 12, carbG: 60 }, note: "", avoid: ["サラダ油"], expectClose: true },
  { id: "breakfast-onion-egg", slot: "breakfast", ingredients: ["玉ねぎ", "卵", "ごはん"], target: { kcal: 380, proteinG: 16, fatG: 12, carbG: 48 }, note: "", avoid: [], expectClose: true },
  { id: "dinner-protein-impossible", slot: "dinner", ingredients: ["卵"], target: { kcal: 150, proteinG: 80, fatG: 5, carbG: 5 }, note: "", avoid: [], expectClose: false },
  { id: "dinner-rare-dropped", slot: "dinner", ingredients: ["鶏むね肉", "ごはん", "トリュフ"], target: { kcal: 600, proteinG: 30, fatG: 16, carbG: 70 }, note: "", avoid: [], expectClose: true },
];

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

export function evalFoods(): FoodRow[] {
  return [
    food("1", "鶏むね肉", 108, 24, 1.5, 0),
    food("2", "ごはん", 168, 2.5, 0.3, 37.1),
    food("3", "サラダ油", 921, 0, 100, 0),
    food("4", "卵", 151, 12.3, 10.3, 0.3),
    food("5", "ブロッコリー", 33, 4.3, 0.4, 5.2),
    food("6", "玉ねぎ", 37, 1, 0.1, 8.8),
    food("7", "じゃがいも", 76, 1.6, 0.1, 17.6),
    food("8", "キャベツ", 23, 1.3, 0.2, 5.2),
    food("9", "木綿豆腐", 73, 6.6, 4.2, 2),
    food("10", "鮭", 133, 22.3, 4.1, 0.1),
    food("11", "豚こま切れ", 221, 18.2, 16, 0.2),
    food("12", "しょうゆ", 71, 8, 0, 8),
    food("13", "みりん", 241, 0.1, 0, 43),
    food("14", "砂糖", 386, 0, 0, 100),
    food("15", "塩", 0, 0, 0, 0),
    food("16", "納豆", 190, 16.5, 10, 12),
    food("17", "牛乳", 67, 3.3, 3.8, 4.8),
    food("18", "ほうれん草", 20, 2.2, 0.4, 3.1),
    food("19", "トマト", 19, 0.7, 0.1, 4.7),
    food("20", "にんじん", 37, 0.6, 0.1, 9.3),
    food("21", "もやし", 14, 1.7, 0.1, 2.6),
    food("22", "ねぎ", 28, 1.2, 0.1, 6.5),
  ];
}

function naiveDish(names: string[]): AiDish {
  return {
    name: "家庭の一品",
    steps: ["材料を切る", "フライパンで4分焼く", "塩1gを振る"],
    extras: [],
    ingredients: names.map((name) => ({ name, grams: 80, kcal: 80, proteinG: 5, fatG: 3, carbG: 8 })),
  };
}

export function planScenario(scenario: EvalScenario, foods: FoodRow[] = evalFoods()): { a: MeasuredDish; b: MeasuredDish } {
  const names = scenario.ingredients.filter((name) => !scenario.avoid.includes(name));
  const ai = naiveDish(names);
  return finalizePair({
    onHand: bestMeasured(ai, foods, scenario.target, undefined, scenario.note, scenario.avoid),
    extra: bestMeasured({ ...ai, extras: ["卵"] }, foods, scenario.target, undefined, scenario.note, scenario.avoid),
    foods,
    target: scenario.target,
    avoid: scenario.avoid,
    slot: scenario.slot,
    note: scenario.note,
    userIngredients: scenario.ingredients,
  });
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export function scoreDish(dish: MeasuredDish, target: Macros, slot: string, note = ""): string[] {
  const reasons: string[] = [];
  const kcal = dish.ingredients.reduce((sum, item) => sum + item.kcal, 0);
  const protein = round1(dish.ingredients.reduce((sum, item) => sum + item.proteinG, 0));
  const fat = round1(dish.ingredients.reduce((sum, item) => sum + item.fatG, 0));
  const carb = round1(dish.ingredients.reduce((sum, item) => sum + item.carbG, 0));
  if (dish.totals.kcal !== kcal || dish.totals.proteinG !== protein || dish.totals.fatG !== fat || dish.totals.carbG !== carb) {
    reasons.push("row sums differ from totals");
  }
  if (dish.gap.kcal !== Math.round(target.kcal - dish.totals.kcal)) {
    reasons.push("kcal gap disagrees with the rows");
  }
  if (dish.within !== withinTolerance(target, dish.totals)) {
    reasons.push("in-range flag disagrees with the numbers");
  }
  if (!dish.within && dish.gapReason.length < 8) {
    reasons.push("missing an honest gap reason");
  }
  if (dish.within && dish.gapReason !== "") {
    reasons.push("gap reason while marked in range");
  }
  if (dish.ingredients.some((item) => !gramsAreRealistic(item.name, item.grams))) {
    reasons.push(`unrealistic grams: ${dish.ingredients.map((item) => `${item.name}${item.grams}`).join(",")}`);
  }
  if (nameMismatch(dish.name, dish.ingredients)) {
    reasons.push(`name mismatch: ${dish.name}`);
  }
  const steps = stepIssues(dish.steps, dish.ingredients, dish.name, note);
  const craftCodes = new Set(["raw", "short", "list_name", "long"]);
  const craft = steps.filter((code) => craftCodes.has(code));
  const rest = steps.filter((code) => !craftCodes.has(code));
  if (craft.includes("raw")) {
    reasons.push("not a cooked or seasoned dish");
  }
  if (craft.includes("short") || totalCookingMinutes(dish.steps.join("\n")) < 5) {
    reasons.push("under 5 min");
  }
  if (craft.includes("long")) {
    reasons.push("over the time limit");
  }
  if (craft.includes("list_name")) {
    reasons.push(`name is an ingredient list: ${dish.name}`);
  }
  if (rest.length > 0) {
    reasons.push(`steps: ${rest.join(",")}`);
  }
  if (slot === "snack" && dish.name.includes("丼")) {
    reasons.push("snack is a rice bowl");
  }
  const seasoned = dish.ingredients.some((item) => item.grams >= 1 && isSeasoning(item.name));
  if (!seasoned) {
    reasons.push("no seasoning");
  }
  if ((slot === "lunch" || slot === "dinner") && dish.within && target.kcal >= 400) {
    const proteinFood = dish.ingredients.some((item) =>
      /肉|鶏|豚|牛|鮭|魚|卵|豆腐|納豆/.test(item.name)
    );
    if (!proteinFood) {
      reasons.push("meal has no protein");
    }
    const volume = dish.ingredients.some((item) =>
      /キャベツ|玉ねぎ|トマト|ブロッコリー|ほうれん草|ねぎ|にんじん|もやし|じゃがいも|豆腐|卵|ごはん|ご飯/.test(item.name)
    );
    if (target.carbG > 15 && !volume) {
      reasons.push("meal has no volume");
    }
  }
  return reasons;
}

export type EvalReport = {
  scenarios: number;
  failed: Array<{ id: string; reasons: string[] }>;
};

export function runLocalEval(foods: FoodRow[] = evalFoods()): EvalReport {
  const failed: EvalReport["failed"] = [];
  for (const scenario of evalScenarios) {
    const pair = planScenario(scenario, foods);
    const reasons = [
      ...scoreDish(pair.a, scenario.target, scenario.slot, scenario.note).map((reason) => `A ${reason}`),
      ...scoreDish(pair.b, scenario.target, scenario.slot, scenario.note).map((reason) => `B ${reason}`),
    ];
    if (scenario.expectClose && !pair.b.within) {
      reasons.push(`B did not close: ${pair.b.gapReason}`);
    }
    if (!scenario.expectClose && pair.b.gapReason.length < 8 && !pair.b.within) {
      reasons.push("B missed without a reason");
    }
    if (pair.a.name === pair.b.name && foodKey(pair.a) === foodKey(pair.b)) {
      reasons.push("patterns are not different");
    }
    const added = pair.b.ingredients.filter((item) => item.extra);
    if (added.length > 2) {
      reasons.push(`B added ${added.length} foods`);
    }
    if (scenario.ingredients.some((name) => name.includes("チョコ") || name.includes("トリュフ"))) {
      const banned = scenario.ingredients.filter((name) => name.includes("チョコ") || name.includes("トリュフ"));
      for (const dish of [pair.a, pair.b]) {
        if (dish.ingredients.some((item) => banned.some((name) => item.name.includes(name)))) {
          reasons.push("incompatible food stayed in the dish");
        }
        if (!dish.omitNote) {
          reasons.push("missing omit note");
        }
      }
    }
    if (reasons.length > 0) {
      failed.push({ id: scenario.id, reasons });
    }
  }
  return { scenarios: evalScenarios.length, failed };
}

function printLocal(): number {
  const report = runLocalEval();
  console.log(JSON.stringify({ scenarios: report.scenarios, failed: report.failed.length }, null, 2));
  for (const row of report.failed) {
    console.log(`FAIL ${row.id}`);
    for (const reason of row.reasons) {
      console.log(`  ${reason}`);
    }
  }
  return report.failed.length === 0 ? 0 : 1;
}

async function runLive(): Promise<number> {
  const cap = Number(Deno.env.get("COOK_EVAL_CALL_CAP") ?? "0");
  const url = Deno.env.get("COOK_EVAL_URL") ?? "";
  const token = Deno.env.get("COOK_EVAL_TOKEN") ?? "";
  if (!Number.isInteger(cap) || cap < 1) {
    console.error("Set COOK_EVAL_CALL_CAP to a positive integer. This harness will not call the network without a cap.");
    return 1;
  }
  if (!url || !token) {
    console.error("Set COOK_EVAL_URL and COOK_EVAL_TOKEN.");
    return 1;
  }
  let calls = 0;
  const failed: EvalReport["failed"] = [];
  for (const scenario of evalScenarios) {
    if (calls >= cap) {
      console.log(`stopped at COOK_EVAL_CALL_CAP=${cap}`);
      break;
    }
    calls += 1;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        ingredients: scenario.ingredients,
        slot: scenario.slot,
        target_kcal: scenario.target.kcal,
        target_protein_g: scenario.target.proteinG,
        target_fat_g: scenario.target.fatG,
        target_carb_g: scenario.target.carbG,
        note: scenario.note,
        avoid: scenario.avoid,
      }),
    });
    const body = await response.json();
    if (!body.ok || !Array.isArray(body.patterns)) {
      failed.push({ id: scenario.id, reasons: [`HTTP ${response.status} ${body.message ?? ""}`] });
      continue;
    }
    console.log(`${scenario.id} cached=${body.cached} retried=${body.retried}`);
  }
  console.log(JSON.stringify({ calls, failed: failed.length }));
  return failed.length === 0 ? 0 : 1;
}

if (import.meta.main) {
  const code = Deno.args.includes("--live") ? await runLive() : printLocal();
  Deno.exit(code);
}
