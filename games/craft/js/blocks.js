import { TILE } from "./tiles.js";

export const AIR = 0;
export const GRASS = 1;
export const DIRT = 2;
export const STONE = 3;
export const COBBLE = 4;
export const SAND = 5;
export const GRAVEL = 6;
export const LOG = 7;
export const LEAVES = 8;
export const PLANKS = 9;
export const WATER = 10;
export const BEDROCK = 11;
export const COAL_ORE = 12;
export const IRON_ORE = 13;
export const GOLD_ORE = 14;
export const DIAMOND_ORE = 15;
export const TABLE = 16;
export const FURNACE = 17;
export const FURNACE_LIT = 18;
export const CHEST = 19;
export const TORCH = 20;
export const GLASS = 21;
export const SANDSTONE = 22;
export const SNOW = 23;
export const CACTUS = 24;
export const FLOWER = 25;
export const TALLGRASS = 26;
export const SPRUCE_LOG = 27;
export const SPRUCE_LEAVES = 28;
export const DEAD_BUSH = 29;
export const LAVA = 30;

export const COAL = 40;
export const RAW_IRON = 41;
export const RAW_GOLD = 42;
export const DIAMOND = 43;
export const IRON_INGOT = 44;
export const GOLD_INGOT = 45;
export const STICK = 46;
export const APPLE = 47;
export const RAW_MEAT = 48;
export const COOKED_MEAT = 49;
export const WOOD_PICK = 50;
export const STONE_PICK = 51;
export const IRON_PICK = 52;
export const WOOD_AXE = 53;
export const STONE_AXE = 54;
export const IRON_AXE = 55;
export const WOOD_SHOVEL = 56;
export const STONE_SHOVEL = 57;
export const IRON_SHOVEL = 58;
export const WOOD_SWORD = 59;
export const STONE_SWORD = 60;
export const IRON_SWORD = 61;
export const CHARCOAL = 62;

export const BLOCKS = [];

function define(id, spec) {
  BLOCKS[id] = {
    id,
    name: spec.name,
    collides: !!spec.collides,
    occlude: !!spec.occlude,
    lightPass: spec.lightPass ?? (spec.occlude ? 15 : 0),
    cube: spec.cube !== false && !!spec.collides,
    fluid: !!spec.fluid,
    leaves: !!spec.leaves,
    glass: !!spec.glass,
    cross: !!spec.cross,
    torch: !!spec.torch,
    cactus: !!spec.cactus,
    emit: spec.emit || 0,
    hardness: spec.hardness ?? 0,
    tool: spec.tool || null,
    minTier: spec.minTier || 0,
    tiles: spec.tiles || null,
    drop: spec.drop === undefined ? id : spec.drop,
    placeable: !!spec.placeable,
    stack: spec.stack ?? 64,
    food: spec.food || null,
    falling: !!spec.falling,
    speed: spec.speed || 0,
    tier: spec.tier || 0,
    attack: spec.attack || 1,
    fuel: spec.fuel || 0,
    interactive: spec.interactive || null,
  };
}

const cube = (name, tiles, extra) => define(extra.id, {
  name,
  collides: true,
  occlude: true,
  cube: true,
  placeable: true,
  tiles,
  hardness: 1,
  ...extra,
  id: undefined,
});

define(AIR, { name: "空気", hardness: 0, drop: null, cube: false });

cube("草ブロック", { top: TILE.GRASS_TOP, bottom: TILE.DIRT, side: TILE.GRASS_SIDE }, {
  id: GRASS, hardness: 0.6, tool: "shovel", drop: DIRT,
});
cube("土", { all: TILE.DIRT }, { id: DIRT, hardness: 0.5, tool: "shovel" });
cube("石", { all: TILE.STONE }, { id: STONE, hardness: 1.5, tool: "pick", minTier: 1, drop: COBBLE });
cube("丸石", { all: TILE.COBBLE }, { id: COBBLE, hardness: 2, tool: "pick", minTier: 1 });
cube("砂", { all: TILE.SAND }, { id: SAND, hardness: 0.5, tool: "shovel", falling: true });
cube("砂利", { all: TILE.GRAVEL }, { id: GRAVEL, hardness: 0.6, tool: "shovel", falling: true });
cube("オークの原木", { top: TILE.LOG_TOP, bottom: TILE.LOG_TOP, side: TILE.LOG_SIDE }, {
  id: LOG, hardness: 2, tool: "axe",
});
define(LEAVES, {
  name: "葉",
  collides: true,
  occlude: false,
  leaves: true,
  lightPass: 1,
  placeable: true,
  tiles: { all: TILE.LEAVES },
  hardness: 0.2,
  drop: null,
});
cube("板材", { all: TILE.PLANKS }, { id: PLANKS, hardness: 2, tool: "axe", fuel: 1.5 });
define(WATER, {
  name: "水",
  fluid: true,
  lightPass: 2,
  hardness: 100,
  drop: null,
  tiles: null,
});
cube("岩盤", { all: TILE.BEDROCK }, { id: BEDROCK, hardness: -1, drop: null });
cube("石炭鉱石", { all: TILE.COAL_ORE }, { id: COAL_ORE, hardness: 3, tool: "pick", minTier: 1, drop: COAL });
cube("鉄鉱石", { all: TILE.IRON_ORE }, { id: IRON_ORE, hardness: 3, tool: "pick", minTier: 1, drop: RAW_IRON });
cube("金鉱石", { all: TILE.GOLD_ORE }, { id: GOLD_ORE, hardness: 3, tool: "pick", minTier: 2, drop: RAW_GOLD });
cube("ダイヤモンド鉱石", { all: TILE.DIAMOND_ORE }, {
  id: DIAMOND_ORE, hardness: 3, tool: "pick", minTier: 3, drop: DIAMOND,
});
cube("作業台", { top: TILE.TABLE_TOP, bottom: TILE.PLANKS, side: TILE.TABLE_FRONT }, {
  id: TABLE, hardness: 2.5, tool: "axe", interactive: "craft",
});
cube("かまど", { top: TILE.FURNACE_TOP, bottom: TILE.FURNACE_TOP, side: TILE.FURNACE_SIDE, front: TILE.FURNACE_FRONT }, {
  id: FURNACE, hardness: 3.5, tool: "pick", minTier: 1, interactive: "furnace",
});
cube("かまど", { top: TILE.FURNACE_TOP, bottom: TILE.FURNACE_TOP, side: TILE.FURNACE_SIDE, front: TILE.FURNACE_LIT }, {
  id: FURNACE_LIT, hardness: 3.5, tool: "pick", minTier: 1, interactive: "furnace", emit: 13, drop: FURNACE,
});
cube("チェスト", { top: TILE.CHEST_TOP, bottom: TILE.PLANKS, side: TILE.CHEST_SIDE, front: TILE.CHEST_FRONT }, {
  id: CHEST, hardness: 2.5, tool: "axe", interactive: "chest",
});
define(TORCH, {
  name: "たいまつ",
  torch: true,
  emit: 14,
  placeable: true,
  tiles: { all: TILE.TORCH },
  hardness: 0,
  lightPass: 0,
});
define(GLASS, {
  name: "ガラス",
  collides: true,
  glass: true,
  placeable: true,
  tiles: { all: TILE.GLASS },
  hardness: 0.3,
  drop: GLASS,
});
cube("砂岩", { top: TILE.SANDSTONE_TOP, bottom: TILE.SANDSTONE, side: TILE.SANDSTONE }, {
  id: SANDSTONE, hardness: 0.8, tool: "pick", minTier: 1,
});
cube("雪ブロック", { all: TILE.SNOW }, { id: SNOW, hardness: 0.2, tool: "shovel" });
define(CACTUS, {
  name: "サボテン",
  collides: true,
  cactus: true,
  placeable: true,
  tiles: { top: TILE.CACTUS_TOP, bottom: TILE.CACTUS_TOP, side: TILE.CACTUS_SIDE },
  hardness: 0.4,
  lightPass: 0,
});
define(FLOWER, {
  name: "花",
  cross: true,
  placeable: true,
  tiles: { all: TILE.FLOWER },
  hardness: 0,
});
define(TALLGRASS, {
  name: "草",
  cross: true,
  placeable: true,
  tiles: { all: TILE.TALLGRASS },
  hardness: 0,
  drop: null,
});
cube("マツの原木", { top: TILE.SPRUCE_TOP, bottom: TILE.SPRUCE_TOP, side: TILE.SPRUCE_SIDE }, {
  id: SPRUCE_LOG, hardness: 2, tool: "axe", fuel: 1.5,
});
define(SPRUCE_LEAVES, {
  name: "マツの葉",
  collides: true,
  leaves: true,
  lightPass: 1,
  placeable: true,
  tiles: { all: TILE.SPRUCE_LEAVES },
  hardness: 0.2,
  drop: null,
});
define(DEAD_BUSH, {
  name: "枯れ木",
  cross: true,
  placeable: true,
  tiles: { all: TILE.DEAD_BUSH },
  hardness: 0,
  drop: STICK,
});
define(LAVA, {
  name: "溶岩",
  fluid: true,
  lava: true,
  emit: 15,
  collides: false,
  hardness: 100,
  drop: null,
  lightPass: 15,
});

function item(id, name, tile, extra = {}) {
  define(id, {
    name,
    tiles: { all: tile },
    hardness: 0,
    drop: null,
    cube: false,
    placeable: false,
    ...extra,
  });
}

item(COAL, "石炭", TILE.COAL, { fuel: 8 });
item(RAW_IRON, "鉄の原石", TILE.IRON);
item(RAW_GOLD, "金の原石", TILE.GOLD);
item(DIAMOND, "ダイヤモンド", TILE.DIAMOND);
item(IRON_INGOT, "鉄インゴット", TILE.IRON);
item(GOLD_INGOT, "金インゴット", TILE.GOLD);
item(STICK, "棒", TILE.STICK, { fuel: 0.5 });
item(APPLE, "りんご", TILE.APPLE, { food: { hunger: 4 } });
item(RAW_MEAT, "生肉", TILE.RAW_MEAT, { food: { hunger: 3 } });
item(COOKED_MEAT, "焼き肉", TILE.COOKED, { food: { hunger: 8 } });
item(CHARCOAL, "木炭", TILE.CHARCOAL, { fuel: 8 });

function tool(id, name, tile, kind, tier, speed, attack) {
  item(id, name, tile, { tool: kind, tier, speed, attack, stack: 1, fuel: kind === "pick" || kind === "axe" || kind === "shovel" || kind === "sword" ? (tier === 1 ? 1 : 0) : 0 });
}

tool(WOOD_PICK, "木のつるはし", TILE.PICK_WOOD, "pick", 1, 2, 2);
tool(STONE_PICK, "石のつるはし", TILE.PICK_STONE, "pick", 2, 4, 3);
tool(IRON_PICK, "鉄のつるはし", TILE.PICK_IRON, "pick", 3, 6, 4);
tool(WOOD_AXE, "木の斧", TILE.AXE_WOOD, "axe", 1, 2, 3);
tool(STONE_AXE, "石の斧", TILE.AXE_STONE, "axe", 2, 4, 4);
tool(IRON_AXE, "鉄の斧", TILE.AXE_IRON, "axe", 3, 6, 5);
tool(WOOD_SHOVEL, "木のシャベル", TILE.SHOVEL_WOOD, "shovel", 1, 2, 1);
tool(STONE_SHOVEL, "石のシャベル", TILE.SHOVEL_STONE, "shovel", 2, 4, 2);
tool(IRON_SHOVEL, "鉄のシャベル", TILE.SHOVEL_IRON, "shovel", 3, 6, 3);
tool(WOOD_SWORD, "木の剣", TILE.SWORD_WOOD, "sword", 1, 2, 4);
tool(STONE_SWORD, "石の剣", TILE.SWORD_STONE, "sword", 2, 4, 5);
tool(IRON_SWORD, "鉄の剣", TILE.SWORD_IRON, "sword", 3, 6, 6);

export function blockOf(id) {
  return BLOCKS[id] || null;
}

export function tileOf(id, face) {
  const b = BLOCKS[id];
  if (!b?.tiles) return 0;
  if (face && b.tiles[face] != null) return b.tiles[face];
  if (face === "front" && b.tiles.side != null && b.tiles.front == null) return b.tiles.side;
  if ((face === "top" || face === "bottom" || face === "side") && b.tiles.all != null) return b.tiles.all;
  return b.tiles.all ?? b.tiles.side ?? b.tiles.top ?? 0;
}

export function collides(id) {
  if (id === 255) return true;
  return !!BLOCKS[id]?.collides;
}

export function occludes(id) {
  return !!BLOCKS[id]?.occlude;
}

export function canHarvest(blockId, heldId) {
  const b = BLOCKS[blockId];
  if (!b) return false;
  if ((b.minTier || 0) <= 0) return true;
  const h = BLOCKS[heldId];
  return !!(h && h.tool === b.tool && (h.tier || 0) >= b.minTier);
}

export function breakDuration(blockId, heldId, creative) {
  const b = BLOCKS[blockId];
  if (!b || b.hardness < 0 || b.fluid) return Infinity;
  if (creative) return 0.05;
  const held = BLOCKS[heldId];
  const harvest = canHarvest(blockId, heldId);
  const speed = held && held.tool && held.tool === b.tool ? held.speed : 1;
  return (b.hardness * (harvest ? 1.5 : 5)) / speed;
}

export function dropFor(blockId, heldId, bonusRoll) {
  const b = BLOCKS[blockId];
  if (!b) return null;
  if (blockId === LEAVES || blockId === SPRUCE_LEAVES) {
    if (bonusRoll < 0.08) return { id: APPLE, count: 1 };
    if (bonusRoll < 0.2) return { id: STICK, count: 1 };
    return null;
  }
  if (blockId === TALLGRASS) {
    if (bonusRoll < 0.12) return { id: STICK, count: 1 };
    return null;
  }
  if (!canHarvest(blockId, heldId)) return null;
  if (b.drop == null) return null;
  return { id: b.drop, count: 1 };
}

export function isFood(id) {
  return !!BLOCKS[id]?.food;
}

export function isTool(id) {
  return !!BLOCKS[id]?.tool;
}

export const PLACEABLE_IDS = BLOCKS.map((b, i) => (b?.placeable ? i : 0)).filter(Boolean);
export const CREATIVE_IDS = [
  GRASS, DIRT, STONE, COBBLE, SAND, GRAVEL, LOG, LEAVES, PLANKS, TABLE, FURNACE, CHEST, TORCH,
  GLASS, SANDSTONE, SNOW, CACTUS, FLOWER, TALLGRASS, SPRUCE_LOG, SPRUCE_LEAVES, DEAD_BUSH,
  COAL, RAW_IRON, RAW_GOLD, DIAMOND, IRON_INGOT, GOLD_INGOT, STICK, APPLE, RAW_MEAT, COOKED_MEAT, CHARCOAL,
  WOOD_PICK, STONE_PICK, IRON_PICK, WOOD_AXE, STONE_AXE, IRON_AXE,
  WOOD_SHOVEL, STONE_SHOVEL, IRON_SHOVEL, WOOD_SWORD, STONE_SWORD, IRON_SWORD,
  WATER, LAVA,
];
