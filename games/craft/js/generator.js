import { HEIGHT, SEA, SIZE, hash3, idx } from "./constants.js";
import {
  AIR, BEDROCK, CACTUS, DEAD_BUSH, DIRT, FLOWER, GRASS, GRAVEL, LAVA, LEAVES, LOG,
  SAND, SANDSTONE, SNOW, SPRUCE_LEAVES, SPRUCE_LOG, STONE, TALLGRASS, WATER,
  COAL_ORE, IRON_ORE, GOLD_ORE, DIAMOND_ORE,
} from "./blocks.js";
import { makeNoise } from "./noise.js";

export const BIOME = {
  PLAINS: 0,
  FOREST: 1,
  DESERT: 2,
  TAIGA: 3,
  BEACH: 4,
  OCEAN: 5,
  PEAKS: 6,
};

export function terrainHeight(noise, x, z) {
  const cont = noise.fbm2(x * 0.0016, z * 0.0016, 4);
  const hill = noise.fbm2(x * 0.008 + 40, z * 0.008 - 15, 3);
  const ridge = noise.fbm2(x * 0.0032 + 120, z * 0.0032, 3);
  let h = 50 + (cont - 0.5) * 24 + (hill - 0.5) * 14;
  if (cont < 0.4) h -= (0.4 - cont) * 36;
  if (ridge > 0.6) {
    const t = (ridge - 0.6) / 0.4;
    h += t * t * 46;
  }
  return Math.max(8, Math.min(HEIGHT - 10, Math.floor(h)));
}

export function biomeAt(noise, x, z, h) {
  if (h < SEA - 1) return BIOME.OCEAN;
  if (h <= SEA + 1) return BIOME.BEACH;
  if (h > 88) return BIOME.PEAKS;
  const temp = noise.fbm2(x * 0.0022 + 220, z * 0.0022, 3);
  const hum = noise.fbm2(x * 0.0022 + 540, z * 0.0022 + 70, 3);
  if (temp > 0.64 && hum < 0.46) return BIOME.DESERT;
  if (temp < 0.36) return BIOME.TAIGA;
  if (hum > 0.56) return BIOME.FOREST;
  return BIOME.PLAINS;
}

function surfaceBlock(biome, y) {
  if (biome === BIOME.DESERT || biome === BIOME.BEACH) return SAND;
  if (biome === BIOME.OCEAN) return y < SEA - 6 ? GRAVEL : SAND;
  if (biome === BIOME.PEAKS) return y > 96 ? SNOW : STONE;
  return GRASS;
}

function fillBlock(biome, y, surface) {
  if (biome === BIOME.DESERT || biome === BIOME.BEACH || biome === BIOME.OCEAN) {
    if (y >= surface - 3) return SAND;
    if (y >= surface - 5) return SANDSTONE;
    return STONE;
  }
  if (biome === BIOME.PEAKS) {
    if (surface > 96 && y === surface) return SNOW;
    if (y >= surface - 2 && surface > 90) return STONE;
    if (y >= surface - 3) return DIRT;
    return STONE;
  }
  if (y >= surface - 3) return DIRT;
  return STONE;
}

function isCave(noise, x, y, z, surface) {
  if (y < 2 || y > surface - 4 || y > 100) return false;
  const a = noise.v3(x * 0.055, y * 0.08, z * 0.055);
  const b = noise.v3(x * 0.055 + 31.7, y * 0.08 + 4.2, z * 0.055 + 18.4);
  const cheese = (a - 0.5) * (a - 0.5) + (b - 0.5) * (b - 0.5);
  if (cheese < 0.014) return true;
  const tunnel = Math.abs(noise.v3(x * 0.035 + 8, y * 0.055, z * 0.035) - 0.5);
  return y < surface - 8 && y > 6 && tunnel < 0.035 && noise.v3(x * 0.012, y * 0.02, z * 0.012) > 0.42;
}

function paintOre(blocks, lx, y, lz, x, z, seed) {
  const i = idx(lx, y, lz);
  if (blocks[i] !== STONE) return;
  const roll = hash3(x, y, z, seed ^ 0x51ed);
  if (y < 16 && roll % 90 === 0) blob(blocks, lx, y, lz, DIAMOND_ORE, roll);
  else if (y < 32 && roll % 48 === 0) blob(blocks, lx, y, lz, GOLD_ORE, roll);
  else if (y < 58 && roll % 28 === 0) blob(blocks, lx, y, lz, IRON_ORE, roll);
  else if (y > 6 && y < 100 && roll % 18 === 0) blob(blocks, lx, y, lz, COAL_ORE, roll);
}

function blob(blocks, lx, y, lz, id, salt) {
  const r = 1;
  for (let dy = -r; dy <= r; dy++) {
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        if ((hash3(dx + 3, dy + 5, dz + 7, salt) & 3) === 0) continue;
        const x = lx + dx;
        const z = lz + dz;
        const yy = y + dy;
        if (x < 0 || z < 0 || x >= SIZE || z >= SIZE || yy < 1 || yy >= HEIGHT) continue;
        const i = idx(x, yy, z);
        if (blocks[i] === STONE) blocks[i] = id;
      }
    }
  }
}

function setLocal(blocks, x0, z0, x, y, z, id, onlyAir) {
  if (y < 0 || y >= HEIGHT) return;
  if (x < x0 || z < z0 || x >= x0 + SIZE || z >= z0 + SIZE) return;
  const i = idx(x - x0, y, z - z0);
  if (onlyAir && blocks[i] !== AIR) return;
  blocks[i] = id;
}

function growOak(blocks, noiseSeed, x0, z0, x, z, surface) {
  const trunk = 4 + (hash3(x, 9, z, noiseSeed) % 3);
  for (let i = 1; i <= trunk; i++) setLocal(blocks, x0, z0, x, surface + i, z, LOG, false);
  const leafBase = surface + trunk;
  for (let dy = -2; dy <= 1; dy++) {
    const r = dy >= 0 ? 1 : 2;
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        if (dx === 0 && dz === 0 && dy < 1) continue;
        if (Math.abs(dx) === r && Math.abs(dz) === r && (hash3(x + dx, dy, z + dz, noiseSeed) & 3) === 0) continue;
        setLocal(blocks, x0, z0, x + dx, leafBase + dy, z + dz, LEAVES, true);
      }
    }
  }
}

function growSpruce(blocks, noiseSeed, x0, z0, x, z, surface) {
  const trunk = 6 + (hash3(x, 4, z, noiseSeed) % 3);
  for (let i = 1; i <= trunk; i++) setLocal(blocks, x0, z0, x, surface + i, z, SPRUCE_LOG, false);
  for (let dy = 0; dy <= trunk - 1; dy++) {
    const layer = trunk - dy;
    let r = 0;
    if (layer > 2) r = 1 + ((trunk - layer) % 2);
    if (layer > trunk - 2) r = 0;
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        if (dx === 0 && dz === 0) continue;
        if (Math.abs(dx) === r && Math.abs(dz) === r && r > 0) continue;
        setLocal(blocks, x0, z0, x + dx, surface + 2 + dy, z + dz, SPRUCE_LEAVES, true);
      }
    }
  }
}

function growCactus(blocks, noiseSeed, x0, z0, x, z, surface) {
  const h = 2 + (hash3(x, 2, z, noiseSeed) % 3);
  for (let i = 1; i <= h; i++) setLocal(blocks, x0, z0, x, surface + i, z, CACTUS, true);
}

export function generateChunk(seed, cx, cz, mods) {
  const noise = makeNoise(seed >>> 0);
  const blocks = new Uint8Array(SIZE * SIZE * HEIGHT);
  const biomes = new Uint8Array(SIZE * SIZE);
  const x0 = cx * SIZE;
  const z0 = cz * SIZE;
  const heights = new Int16Array(SIZE * SIZE);

  for (let lz = 0; lz < SIZE; lz++) {
    for (let lx = 0; lx < SIZE; lx++) {
      const x = x0 + lx;
      const z = z0 + lz;
      const h = terrainHeight(noise, x, z);
      const biome = biomeAt(noise, x, z, h);
      heights[lx + lz * SIZE] = h;
      biomes[lx + lz * SIZE] = biome;
      for (let y = 0; y <= h; y++) {
        let id;
        if (y === 0 || (y <= 2 && (hash3(x, y, z, seed) % 3) !== 0)) id = BEDROCK;
        else if (y === h) id = surfaceBlock(biome, y);
        else id = fillBlock(biome, y, h);
        blocks[idx(lx, y, lz)] = id;
      }
      for (let y = 2; y < h - 3; y++) {
        if (!isCave(noise, x, y, z, h)) continue;
        blocks[idx(lx, y, lz)] = y < 7 ? LAVA : AIR;
      }
      for (let y = 1; y < h; y++) paintOre(blocks, lx, y, lz, x, z, seed);
      if (h < SEA - 1) {
        for (let y = h + 1; y < SEA; y++) {
          if (blocks[idx(lx, y, lz)] === AIR) blocks[idx(lx, y, lz)] = WATER;
        }
      }
    }
  }

  for (let z = z0 - 5; z < z0 + SIZE + 5; z++) {
    for (let x = x0 - 5; x < x0 + SIZE + 5; x++) {
      const h = terrainHeight(noise, x, z);
      const biome = biomeAt(noise, x, z, h);
      const roll = hash3(x, 17, z, seed);
      const slope = Math.abs(terrainHeight(noise, x + 1, z) - h) + Math.abs(terrainHeight(noise, x, z + 1) - h);
      if (slope > 3) continue;
      if (biome === BIOME.DESERT && roll % 37 === 0) growCactus(blocks, seed, x0, z0, x, z, h);
      else if (biome === BIOME.TAIGA && roll % 11 === 0) growSpruce(blocks, seed, x0, z0, x, z, h);
      else if (biome === BIOME.FOREST && roll % 8 === 0) growOak(blocks, seed, x0, z0, x, z, h);
      else if (biome === BIOME.PLAINS && roll % 29 === 0) growOak(blocks, seed, x0, z0, x, z, h);
      else if ((biome === BIOME.PLAINS || biome === BIOME.FOREST) && h >= SEA) {
        if (roll % 6 === 0) setLocal(blocks, x0, z0, x, h + 1, z, TALLGRASS, true);
        else if (roll % 17 === 0) setLocal(blocks, x0, z0, x, h + 1, z, FLOWER, true);
      } else if (biome === BIOME.DESERT && roll % 19 === 0) {
        setLocal(blocks, x0, z0, x, h + 1, z, DEAD_BUSH, true);
      }
    }
  }

  if (mods && mods.length) {
    for (let i = 0; i < mods.length; i += 4) {
      const x = mods[i];
      const y = mods[i + 1];
      const z = mods[i + 2];
      const id = mods[i + 3];
      if (x < x0 || z < z0 || x >= x0 + SIZE || z >= z0 + SIZE || y < 0 || y >= HEIGHT) continue;
      blocks[idx(x - x0, y, z - z0)] = id;
    }
  }

  return { blocks, biomes, heights };
}

export function findSpawnColumn(seed) {
  const noise = makeNoise(seed >>> 0);
  for (let r = 0; r < 96; r++) {
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        if (r !== 0 && Math.abs(dx) !== r && Math.abs(dz) !== r) continue;
        const h = terrainHeight(noise, dx, dz);
        const b = biomeAt(noise, dx, dz, h);
        if (h >= SEA + 1 && b !== BIOME.OCEAN && b !== BIOME.BEACH && b !== BIOME.PEAKS) {
          return { x: dx, z: dz, y: h + 1 };
        }
      }
    }
  }
  const h = terrainHeight(noise, 0, 0);
  return { x: 0, z: 0, y: h + 1 };
}
