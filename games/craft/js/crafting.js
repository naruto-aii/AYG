import {
  CHARCOAL, COAL, COBBLE, COOKED_MEAT, FURNACE, GLASS, GOLD_INGOT,
  GOLD_ORE, IRON_INGOT, IRON_ORE, LOG, PLANKS, RAW_GOLD, RAW_IRON, RAW_MEAT, SAND,
  SANDSTONE, STICK, STONE, TABLE, TORCH, CHEST, SPRUCE_LOG,
  WOOD_AXE, WOOD_PICK, WOOD_SHOVEL, WOOD_SWORD,
  STONE_AXE, STONE_PICK, STONE_SHOVEL, STONE_SWORD,
  IRON_AXE, IRON_PICK, IRON_SHOVEL, IRON_SWORD,
} from "./blocks.js";

const P = PLANKS;
const S = STICK;
const C = COBBLE;
const I = IRON_INGOT;

function shaped(w, h, cells, out, n = 1) {
  return { w, h, cells, out, n };
}

export const RECIPES = [
  { shapeless: true, input: [LOG], out: PLANKS, n: 4 },
  { shapeless: true, input: [SPRUCE_LOG], out: PLANKS, n: 4 },
  shaped(1, 2, [P, P], STICK, 4),
  shaped(2, 2, [P, P, P, P], TABLE, 1),
  shaped(2, 2, [SAND, SAND, SAND, SAND], SANDSTONE, 1),
  shaped(3, 3, [P, P, P, P, 0, P, P, P, P], CHEST, 1),
  shaped(3, 3, [C, C, C, C, 0, C, C, C, C], FURNACE, 1),
  shaped(1, 2, [COAL, S], TORCH, 4),
  shaped(1, 2, [CHARCOAL, S], TORCH, 4),
  shaped(3, 3, [P, P, P, 0, S, 0, 0, S, 0], WOOD_PICK, 1),
  shaped(3, 3, [C, C, C, 0, S, 0, 0, S, 0], STONE_PICK, 1),
  shaped(3, 3, [I, I, I, 0, S, 0, 0, S, 0], IRON_PICK, 1),
  shaped(2, 3, [P, P, P, S, 0, S], WOOD_AXE, 1),
  shaped(2, 3, [C, C, C, S, 0, S], STONE_AXE, 1),
  shaped(2, 3, [I, I, I, S, 0, S], IRON_AXE, 1),
  shaped(1, 3, [P, S, S], WOOD_SHOVEL, 1),
  shaped(1, 3, [C, S, S], STONE_SHOVEL, 1),
  shaped(1, 3, [I, S, S], IRON_SHOVEL, 1),
  shaped(1, 3, [P, P, S], WOOD_SWORD, 1),
  shaped(1, 3, [C, C, S], STONE_SWORD, 1),
  shaped(1, 3, [I, I, S], IRON_SWORD, 1),
];

function counts(ids) {
  const map = new Map();
  for (const id of ids) {
    if (!id) continue;
    map.set(id, (map.get(id) || 0) + 1);
  }
  return map;
}

function sameCounts(a, b) {
  if (a.size !== b.size) return false;
  for (const [k, v] of a) if (b.get(k) !== v) return false;
  return true;
}

function fits(grid, size, recipe, ox, oy, mirror) {
  const expected = new Array(size * size).fill(0);
  for (let y = 0; y < recipe.h; y++) {
    for (let x = 0; x < recipe.w; x++) {
      const sx = mirror ? recipe.w - 1 - x : x;
      const id = recipe.cells[y * recipe.w + x] || 0;
      const gx = ox + sx;
      const gy = oy + y;
      if (gx < 0 || gy < 0 || gx >= size || gy >= size) return false;
      expected[gy * size + gx] = id;
    }
  }
  for (let i = 0; i < grid.length; i++) {
    if ((grid[i] || 0) !== expected[i]) return false;
  }
  return true;
}

export function matchCraft(grid, size) {
  for (const recipe of RECIPES) {
    if (recipe.shapeless) {
      const have = counts(grid);
      const need = counts(recipe.input);
      if (sameCounts(have, need)) return { id: recipe.out, count: recipe.n };
      continue;
    }
    if (recipe.w > size || recipe.h > size) continue;
    for (let oy = 0; oy <= size - recipe.h; oy++) {
      for (let ox = 0; ox <= size - recipe.w; ox++) {
        if (fits(grid, size, recipe, ox, oy, false) || fits(grid, size, recipe, ox, oy, true)) {
          return { id: recipe.out, count: recipe.n };
        }
      }
    }
  }
  return null;
}

export const SMELT = {
  [IRON_ORE]: IRON_INGOT,
  [GOLD_ORE]: GOLD_INGOT,
  [RAW_IRON]: IRON_INGOT,
  [RAW_GOLD]: GOLD_INGOT,
  [SAND]: GLASS,
  [COBBLE]: STONE,
  [RAW_MEAT]: COOKED_MEAT,
  [LOG]: CHARCOAL,
};

export const FUEL_OF = {
  [COAL]: 8,
  [CHARCOAL]: 8,
  [PLANKS]: 1.5,
  [LOG]: 1.5,
  [SPRUCE_LOG]: 1.5,
  [STICK]: 0.5,
  [WOOD_PICK]: 1,
  [WOOD_AXE]: 1,
  [WOOD_SHOVEL]: 1,
  [WOOD_SWORD]: 1,
  [TABLE]: 1.5,
  [CHEST]: 1.5,
};

export function fuelValue(id) {
  return FUEL_OF[id] || 0;
}

export function smeltResult(id) {
  return SMELT[id] || 0;
}
