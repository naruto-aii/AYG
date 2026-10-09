// 自炊コーチの網羅採点（28通りの食材 × 残り kcal 150〜1200 の11段階 = 308件）。
//   deno run -A supabase/functions/cook_coach_grid_eval.ts [--json]
import { totalCookingMinutes } from "./cook-coach/plan.ts";
import { cookRecipes } from "./cook-coach/recipes.ts";
import { selectCookPlans, type CookRecipe } from "./cook-coach/select.ts";
import type { MeasuredDish } from "./cook-coach/match.ts";

export const gridCombos: string[][] = [
  ["納豆", "ごはん"], ["鶏むね肉", "ごはん"], ["ごはん"], ["納豆"], ["卵", "ごはん"], ["卵"],
  ["豚こま切れ", "ごはん"], ["鶏もも肉", "ごはん"], ["鮭", "ごはん"], ["木綿豆腐", "ごはん"], ["木綿豆腐"],
  ["鶏むね肉"], ["鶏むね肉", "ブロッコリー"], ["キャベツ"], ["キャベツ", "卵"], ["うどん"], ["うどん", "卵"],
  ["パスタ", "ベーコン"], ["じゃがいも", "玉ねぎ"], ["鶏もも肉", "玉ねぎ"], ["納豆", "卵", "ごはん"],
  ["豚こま切れ", "キャベツ"], ["鮭"], ["牛乳"], ["トマト", "卵"], ["ほうれん草", "ごはん"],
  ["鶏むね肉", "豚こま切れ", "卵", "ごはん", "玉ねぎ", "キャベツ"], ["ひき肉", "玉ねぎ", "ごはん"],
];
export const gridKcals = [150, 255, 360, 465, 570, 675, 780, 885, 990, 1095, 1200];

export function gridTarget(kcal: number) {
  return {
    kcal,
    proteinG: Math.round(kcal * 0.2 / 4),
    fatG: Math.round(kcal * 0.25 / 9),
    carbG: Math.round(kcal * 0.55 / 4),
  };
}
export function gridSlot(kcal: number) {
  return kcal <= 255 ? "snack" : kcal <= 465 ? "breakfast" : kcal <= 780 ? "lunch" : "dinner";
}

const pfcOk = (a: number, t: number) => Math.abs(a - t) <= Math.abs(t) * 0.15 + 0.05;
const kcalOk = (a: number, t: number) => Math.abs(a - t) <= t * 0.1 + 0.51;
function trivial(plan: MeasuredDish): boolean {
  const parts = plan.name.split("、").filter((n) => n !== "ごはんの温め");
  return parts.length === 0;
}
function realDish(plan: MeasuredDish): boolean {
  const minutes = totalCookingMinutes(plan.steps.join("\n"));
  return !trivial(plan) && plan.steps.length >= 1 && minutes >= 5 && minutes <= 30;
}

export function runGrid(recipes: CookRecipe[] = cookRecipes) {
  const rows = [];
  for (const ingredients of gridCombos) {
    for (const kcal of gridKcals) {
      const target = gridTarget(kcal);
      const slot = gridSlot(kcal);
      const r = selectCookPlans(recipes, { ingredients, slot, target });
      const plans = [r.a, r.b].filter((p): p is MeasuredDish => p !== null);
      rows.push({
        id: `${ingredients.join("+")}/${kcal}`,
        zero: plans.length === 0,
        two: r.a !== null && r.b !== null && r.a.name !== r.b.name,
        plans: plans.map((p) => ({
          name: p.name,
          totals: p.totals,
          kcal: kcalOk(p.totals.kcal, kcal),
          pfc: pfcOk(p.totals.proteinG, target.proteinG) && pfcOk(p.totals.fatG, target.fatG) && pfcOk(p.totals.carbG, target.carbG),
          p: pfcOk(p.totals.proteinG, target.proteinG), f: pfcOk(p.totals.fatG, target.fatG), c: pfcOk(p.totals.carbG, target.carbG),
          real: realDish(p),
        })),
        trivialA: r.a ? trivial(r.a) : false,
        omitNote: r.omitNote,
      });
    }
  }
  const n = rows.length;
  const plans = rows.flatMap((r) => r.plans);
  const pct = (x: number, d: number) => `${x}/${d} (${(100 * x / Math.max(1, d)).toFixed(1)}%)`;
  const summary = {
    cases: n,
    zero: pct(rows.filter((r) => r.zero).length, n),
    twoDistinct: pct(rows.filter((r) => r.two).length, n),
    plans: plans.length,
    kcal10: pct(plans.filter((p) => p.kcal).length, plans.length),
    p15only: pct(plans.filter((p) => p.p).length, plans.length),
    pc15: pct(plans.filter((p) => p.p && p.c).length, plans.length),
    pfc15: pct(plans.filter((p) => p.pfc).length, plans.length),
    p15: pct(plans.filter((p) => p.p).length, plans.length),
    f15: pct(plans.filter((p) => p.f).length, plans.length),
    c15: pct(plans.filter((p) => p.c).length, plans.length),
    allOk: pct(plans.filter((p) => p.kcal && p.pfc && p.real).length, plans.length),
    realDish: pct(plans.filter((p) => p.real).length, plans.length),
    trivialA: pct(rows.filter((r) => r.trivialA).length, n),
  };
  return { rows, summary };
}

if (import.meta.main) {
  const { rows, summary } = runGrid();
  if (Deno.args.includes("--json")) {
    console.log(JSON.stringify(rows, null, 1));
  } else {
    for (const r of rows) {
      const bad = r.zero || !r.two || r.trivialA || r.plans.some((p) => !p.kcal || !p.pfc || !p.real);
      if (bad) console.log(r.id, r.zero ? "ZERO" : "", r.two ? "" : "ONE", JSON.stringify(r.plans.map((p) => [p.name, p.totals, p.kcal ? "" : "K", p.p ? "" : "P", p.f ? "" : "F", p.c ? "" : "C", p.real ? "" : "NOTREAL"])));
    }
  }
  console.error(JSON.stringify(summary, null, 1));
}
