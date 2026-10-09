import { assert, assertEquals } from "jsr:@std/assert@1";

import { totalCookingMinutes } from "./cook-coach/plan.ts";
import { cookRecipes } from "./cook-coach/recipes.ts";
import { selectCookPlans } from "./cook-coach/select.ts";

const combos = [
  ["鶏むね肉", "ごはん"], ["卵", "ごはん"], ["豚こま切れ", "ごはん"], ["鶏むね肉"], ["卵"], ["木綿豆腐"],
  ["鮭", "ごはん"], ["キャベツ"], ["ごはん"], ["鶏もも肉", "玉ねぎ"], ["納豆", "ごはん"], ["納豆"],
  ["うどん"], ["パスタ", "ベーコン"], ["じゃがいも", "玉ねぎ"],
];
const slots = ["breakfast", "lunch", "dinner", "snack"];
const kcals = [150, 400, 700, 1200];

function targetFor(kcal: number) {
  return {
    kcal,
    proteinG: Math.round(kcal * 0.2 / 4),
    fatG: Math.round(kcal * 0.25 / 9),
    carbG: Math.round(kcal * 0.55 / 4),
  };
}

Deno.test("cook coach sweep: never zero plans, kcal within 10%, plan A is a real dish", () => {
  for (const ingredients of combos) {
    for (const kcal of kcals) {
      for (const slot of slots) {
        const target = targetFor(kcal);
        const result = selectCookPlans(cookRecipes, { ingredients, slot, target });
        const label = `${ingredients.join("+")}/${slot}/${kcal}`;
        assert(result.a !== null || result.b !== null, `zero plans: ${label}`);
        if (result.a) {
          assert(result.a.name !== "ごはんの温め", `trivial plan A: ${label}`);
          assert(!result.a.name.split("、").every((name) => name === "ごはんの温め"), `trivial plan A: ${label}`);
        }
        for (const plan of [result.a, result.b]) {
          if (!plan) continue;
          assert(Math.abs(plan.totals.kcal - kcal) <= kcal * 0.1 + 0.51, `kcal off: ${label} ${plan.totals.kcal}`);
          const minutes = totalCookingMinutes(plan.steps.join("\n"));
          assert(plan.steps.length >= 3 && minutes >= 5 && minutes <= 30, `not a real dish: ${label} ${plan.name}`);
        }
      }
    }
  }
});

Deno.test("cook coach: natto alone gets a natto dish", () => {
  const result = selectCookPlans(cookRecipes, { ingredients: ["納豆"], slot: "dinner", target: targetFor(550) });
  const plan = result.a ?? result.b;
  assert(plan !== null);
  assert(plan!.name.includes("納豆"), plan!.name);
  assertEquals(result.omitNote, "");
});

Deno.test("cook coach: an unusable ingredient still returns plans and says it was not used", () => {
  const result = selectCookPlans(cookRecipes, { ingredients: ["パスタ", "ベーコン"], slot: "snack", target: targetFor(150) });
  assert(result.a !== null || result.b !== null);
  assert(result.omitNote.includes("使っていません"), result.omitNote);
  assert(result.omitNote.includes("パスタ"), result.omitNote);
});

Deno.test("cook coach: two different plans even when only one kind can be made", () => {
  for (const ingredients of [["納豆", "ごはん"], ["ごはん"], ["キャベツ"], ["鶏むね肉", "ごはん"]]) {
    for (const kcal of [465, 780, 1200]) {
      const result = selectCookPlans(cookRecipes, { ingredients, slot: "dinner", target: targetFor(kcal) });
      const label = `${ingredients.join("+")}/${kcal}`;
      assert(result.a !== null && result.b !== null, `one plan: ${label}`);
      assert(result.a!.name !== result.b!.name, `same plan: ${label}`);
    }
  }
  const rice = selectCookPlans(cookRecipes, { ingredients: ["ごはん"], slot: "dinner", target: targetFor(780) });
  assertEquals([rice.aKind, rice.bKind], ["extra", "extra"]);
});
