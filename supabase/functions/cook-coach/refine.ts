// 選んだ献立の分量を、目標の kcal と PFC に寄せる。料理名と作り方の手順はそのまま、
// 手順に書いたグラム数だけ書き換える。調味料は動かさない。
import {
  defaultTolerance,
  explainGap,
  gapScore as gapScoreOf,
  isEgg,
  isMeatFish,
  isOil,
  isPotato,
  isRice,
  isSeasoning,
  isVeg,
  type Macros,
  type MeasuredDish,
  type MeasuredIngredient,
  realisticGramBounds,
  round1,
  withinTolerance,
} from "./match.ts";

type Var = {
  index: number;
  min: number;
  max: number;
  step: number;
  grid?: number[];
};

// 炒め・焼きの油は 2〜12g（大さじ1弱）。脂質の過不足はここで寄せる。
const OIL_MIN = 2;
const OIL_MAX = 12;
const starchWord = /うどん|そば|パスタ|スパゲティ|食パン|中華麺|麺|パン/;

function windowFor(item: MeasuredIngredient): Var | null {
  const name = item.name;
  const orig = item.grams;
  if (!(orig > 0)) {
    return null;
  }
  if (isEgg(name)) {
    const grid = [50, 100, 150, 200].filter((g) => g >= orig * 0.5 - 1e-6 && g <= orig * 2 + 1e-6);
    return grid.length > 1 ? { index: -1, min: grid[0], max: grid.at(-1)!, step: 50, grid } : null;
  }
  if (isOil(name)) {
    // 0 にはしない（手順で油を使うため）。現実的な上限は match の分量と同じ。
    const real = realisticGramBounds(name, orig);
    return {
      index: -1,
      min: Math.max(real.min, Math.min(orig, OIL_MIN)),
      max: Math.min(real.max, Math.max(orig, OIL_MAX)),
      step: 1,
    };
  }
  if (isSeasoning(name)) {
    return null;
  }
  const real = realisticGramBounds(name, orig);
  let low = 0.7;
  let high = 1.5;
  if (isRice(name) || starchWord.test(name)) {
    low = 0.35;
    high = 2.2;
  } else if (isMeatFish(name) || name.includes("豆腐") || name.includes("納豆") || name.includes("厚揚げ")) {
    low = 0.45;
    high = 1.9;
  } else if (isPotato(name) || isVeg(name)) {
    low = 0.6;
    high = 1.6;
  }
  const min = Math.max(real.min, Math.round(orig * low));
  const max = Math.min(real.max, Math.round(orig * high));
  if (max <= min) {
    return null;
  }
  return { index: -1, min, max, step: orig >= 40 ? 5 : 1 };
}

function rate(item: MeasuredIngredient): Macros {
  const g = item.grams > 0 ? item.grams : 1;
  return {
    kcal: item.kcal / g,
    proteinG: item.proteinG / g,
    fatG: item.fatG / g,
    carbG: item.carbG / g,
  };
}

function axis(actual: number, goal: number, ratio: number): number {
  return (actual - goal) / Math.max(1, Math.abs(goal) * ratio);
}

function excess(x: number): number {
  const ax = Math.abs(x);
  return ax > 1 ? ax - 1 : 0;
}

function closeness(x: number): number {
  const ax = Math.abs(x);
  return ax <= 1 ? ax : 0;
}

// 小さいほどよい。並びは kcal、たんぱく質、炭水化物、脂質のバンド外超過、そのあと各項目のバンド内の近さ。
// 超過が 0 ならその項目は許容内（kcal は ±10%、P/C/F は ±15%）。
// 上位の超過は下位のどれよりも先に比べるので、下位を合わせるために上位をバンドの外へ出さない。
// バンド内の近さは、すべての超過が同じときだけ使う。
export function portionRank(target: Macros, actual: Macros): number[] {
  const axes = [
    axis(actual.kcal, target.kcal, 0.1),
    axis(actual.proteinG, target.proteinG, 0.15),
    axis(actual.carbG, target.carbG, 0.15),
    axis(actual.fatG, target.fatG, 0.15),
  ];
  return [...axes.map(excess), ...axes.map(closeness)];
}

export function portionPrefers(target: Macros, left: Macros, right: Macros): boolean {
  return rankBetter(portionRank(target, left), portionRank(target, right));
}

function rankBetter(left: number[], right: number[]): boolean {
  const n = Math.max(left.length, right.length);
  for (let i = 0; i < n; i++) {
    const delta = (left[i] ?? 0) - (right[i] ?? 0);
    if (delta < -1e-9) {
      return true;
    }
    if (delta > 1e-9) {
      return false;
    }
  }
  return false;
}

export function refineMeal(meal: MeasuredDish, target: Macros): MeasuredDish {
  const items = meal.ingredients;
  const rates = items.map(rate);
  const grams = items.map((item) => item.grams);
  const vars: Var[] = [];
  items.forEach((item, index) => {
    const w = windowFor(item);
    if (w) {
      vars.push({ ...w, index });
    }
  });
  if (vars.length === 0) {
    return meal;
  }
  const totals = (gs: number[]): Macros => {
    const out = { kcal: 0, proteinG: 0, fatG: 0, carbG: 0 };
    gs.forEach((g, i) => {
      out.kcal += rates[i].kcal * g;
      out.proteinG += rates[i].proteinG * g;
      out.fatG += rates[i].fatG * g;
      out.carbG += rates[i].carbG * g;
    });
    return out;
  };
  // 元の分量から離れすぎないよう、わずかに罰する。
  const drift = (gs: number[]) =>
    vars.reduce((sum, v) => {
      const d = (gs[v.index] - items[v.index].grams) / Math.max(1, items[v.index].grams);
      return sum + d * d * 0.05;
    }, 0);
  const score = (gs: number[]) => [...portionRank(target, totals(gs)), drift(gs)];
  let best = score(grams);
  for (let pass = 0; pass < 25; pass++) {
    let improved = false;
    for (const v of vars) {
      const current = grams[v.index];
      const candidates = v.grid ?? (() => {
        const out: number[] = [];
        for (const mult of [1, 2, 4, 8]) {
          out.push(current - v.step * mult, current + v.step * mult);
        }
        return out;
      })();
      for (const raw of candidates) {
        const value = Math.min(v.max, Math.max(v.min, raw));
        if (value === current) {
          continue;
        }
        grams[v.index] = value;
        const s = score(grams);
        if (rankBetter(s, best)) {
          best = s;
          improved = true;
          break;
        }
        grams[v.index] = current;
      }
    }
    if (!improved) {
      break;
    }
  }
  let steps = meal.steps;
  const ingredients = items.map((item, i) => {
    const g = grams[i];
    if (g === item.grams) {
      return item;
    }
    const r = rates[i];
    steps = steps.map((step) => step.replaceAll(`${item.name}${item.grams}g`, `${item.name}${g}g`));
    return {
      ...item,
      grams: g,
      kcal: Math.round(r.kcal * g),
      proteinG: round1(r.proteinG * g),
      fatG: round1(r.fatG * g),
      carbG: round1(r.carbG * g),
    };
  });
  if (ingredients.every((item, i) => item === items[i])) {
    return meal;
  }
  const sum = {
    kcal: ingredients.reduce((s, item) => s + item.kcal, 0),
    proteinG: round1(ingredients.reduce((s, item) => s + item.proteinG, 0)),
    fatG: round1(ingredients.reduce((s, item) => s + item.fatG, 0)),
    carbG: round1(ingredients.reduce((s, item) => s + item.carbG, 0)),
  };
  const refined: MeasuredDish = {
    ...meal,
    steps,
    ingredients,
    totals: sum,
    gap: {
      kcal: Math.round(target.kcal - sum.kcal),
      proteinG: round1(target.proteinG - sum.proteinG),
      fatG: round1(target.fatG - sum.fatG),
      carbG: round1(target.carbG - sum.carbG),
    },
    within: withinTolerance(target, sum, defaultTolerance),
    score: 0,
    gapReason: "",
  };
  refined.score = gapScoreOf(target, sum);
  refined.gapReason = refined.within ? "" : explainGap(target, refined);
  return refined;
}
