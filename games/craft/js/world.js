import { HEIGHT, SIZE, UNLOADED, blockKey, chunkKey, floorDiv, idx } from "./constants.js";
import {
  AIR, BEDROCK, CHEST, FURNACE, FURNACE_LIT, GRAVEL, SAND, blockOf,
} from "./blocks.js";
import { findSpawnColumn, generateChunk } from "./generator.js";
import { computeLight } from "./lighting.js";
import { buildMesh } from "./mesher.js";
import { fuelValue, smeltResult } from "./crafting.js";

export class World {
  constructor(seed) {
    this.seed = seed >>> 0;
    this.chunks = new Map();
    this.mods = new Map();
    this.chests = new Map();
    this.furnaces = new Map();
    this.inflight = new Set();
    this.worker = null;
    this.spawn = findSpawnColumn(this.seed);
    this.time = 2200;
    this.rain = 0;
    this.onBlock = null;
    this.onUpload = null;
    this.onDispose = null;
    this.suppress = false;
    this.readySpawn = false;
  }

  attachWorker() {
    if (this.worker || typeof Worker === "undefined") return;
    try {
      this.worker = new Worker(new URL("./chunkWorker.js", import.meta.url), { type: "module" });
      this.worker.onmessage = (e) => {
        const { cx, cz, blocks, biomes } = e.data;
        this.install(cx, cz, blocks, biomes);
      };
      this.worker.onerror = () => {
        try { this.worker.terminate(); } catch { /* already stopped */ }
        this.worker = null;
        this.inflight.clear();
      };
    } catch {
      this.worker = null;
    }
  }

  modsIn(cx, cz) {
    const x0 = cx * SIZE;
    const z0 = cz * SIZE;
    const x1 = x0 + SIZE;
    const z1 = z0 + SIZE;
    const out = [];
    for (const [k, id] of this.mods) {
      const [x, y, z] = k.split(",").map(Number);
      if (x >= x0 && x < x1 && z >= z0 && z < z1 && y >= 0 && y < HEIGHT) out.push(x, y, z, id);
    }
    return out;
  }

  request(cx, cz) {
    const key = chunkKey(cx, cz);
    if (this.chunks.has(key) || this.inflight.has(key)) return;
    this.inflight.add(key);
    const mods = this.modsIn(cx, cz);
    if (this.worker) {
      this.worker.postMessage({ cx, cz, seed: this.seed, mods });
      return;
    }
    const gen = generateChunk(this.seed, cx, cz, mods);
    this.install(cx, cz, gen.blocks, gen.biomes);
  }

  install(cx, cz, blocks, biomes) {
    const key = chunkKey(cx, cz);
    this.inflight.delete(key);
    const chunk = {
      cx, cz, blocks, biomes,
      sky: null,
      glow: null,
      lightDirty: true,
      meshDirty: true,
    };
    this.chunks.set(key, chunk);
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nb = this.chunks.get(chunkKey(cx + dx, cz + dz));
      if (nb) {
        nb.lightDirty = true;
        nb.meshDirty = true;
      }
    }
    const sx = floorDiv(this.spawn.x, SIZE);
    const sz = floorDiv(this.spawn.z, SIZE);
    if (cx === sx && cz === sz) this.readySpawn = true;
  }

  chunkOf(x, z) {
    return this.chunks.get(chunkKey(floorDiv(Math.floor(x), SIZE), floorDiv(Math.floor(z), SIZE))) || null;
  }

  getBlock(x, y, z) {
    x = Math.floor(x);
    y = Math.floor(y);
    z = Math.floor(z);
    if (y < 0) return BEDROCK;
    if (y >= HEIGHT) return AIR;
    const cx = floorDiv(x, SIZE);
    const cz = floorDiv(z, SIZE);
    const chunk = this.chunks.get(chunkKey(cx, cz));
    if (!chunk?.blocks) return UNLOADED;
    return chunk.blocks[idx(x - cx * SIZE, y, z - cz * SIZE)];
  }

  getBiome(x, z) {
    const chunk = this.chunkOf(x, z);
    if (!chunk?.biomes) return 0;
    const lx = Math.floor(x) - chunk.cx * SIZE;
    const lz = Math.floor(z) - chunk.cz * SIZE;
    return chunk.biomes[lx + lz * SIZE] || 0;
  }

  sampleLight(x, y, z) {
    y = Math.floor(y);
    if (y < 0 || y >= HEIGHT) return { sky: y >= HEIGHT ? 15 : 0, block: 0 };
    const chunk = this.chunkOf(x, z);
    if (!chunk?.sky) return null;
    const lx = Math.floor(x) - chunk.cx * SIZE;
    const lz = Math.floor(z) - chunk.cz * SIZE;
    const i = idx(lx, y, lz);
    return { sky: chunk.sky[i], block: chunk.glow[i] };
  }

  lightAt(x, y, z) {
    const sampled = this.sampleLight(x, y, z);
    if (sampled) return sampled;
    const id = this.getBlock(x, y, z);
    const emit = blockOf(id)?.emit || 0;
    if (id === AIR || id === UNLOADED) return { sky: 15, block: emit };
    if (emit) return { sky: 0, block: emit };
    const b = blockOf(id);
    if (b && !b.occlude) return { sky: 12, block: emit };
    return { sky: 0, block: 0 };
  }

  setBlock(x, y, z, id, opts = {}) {
    x = Math.floor(x);
    y = Math.floor(y);
    z = Math.floor(z);
    if (y < 0 || y >= HEIGHT) return false;
    const prev = this.getBlock(x, y, z);
    if (prev === UNLOADED) {
      this.mods.set(blockKey(x, y, z), id);
      if (!opts.silent && this.onBlock) this.onBlock(x, y, z, id);
      return true;
    }
    if (prev === id) return false;
    const cx = floorDiv(x, SIZE);
    const cz = floorDiv(z, SIZE);
    const chunk = this.chunks.get(chunkKey(cx, cz));
    chunk.blocks[idx(x - cx * SIZE, y, z - cz * SIZE)] = id;
    this.mods.set(blockKey(x, y, z), id);
    this.touch(cx, cz, x, z);
    if ((prev === CHEST || id !== CHEST) && prev === CHEST && id !== CHEST) {
      const spilled = this.chests.get(blockKey(x, y, z));
      this.chests.delete(blockKey(x, y, z));
      if (spilled && this.onSpill) this.onSpill(x, y, z, spilled);
    }
    if ((prev === FURNACE || prev === FURNACE_LIT) && id !== FURNACE && id !== FURNACE_LIT) {
      const furnace = this.furnaces.get(blockKey(x, y, z));
      this.furnaces.delete(blockKey(x, y, z));
      if (furnace && this.onSpill) {
        this.onSpill(x, y, z, [furnace.input, furnace.fuel, furnace.output].filter(Boolean));
      }
    }
    if (!opts.silent && this.onBlock) this.onBlock(x, y, z, id);
    if (!this.suppress && !opts.noFall) this.settleColumn(x, z);
    return true;
  }

  touch(cx, cz, x, z) {
    const lx = x - cx * SIZE;
    const lz = z - cz * SIZE;
    const mark = (dx, dz) => {
      const c = this.chunks.get(chunkKey(cx + dx, cz + dz));
      if (!c) return;
      c.lightDirty = true;
      c.meshDirty = true;
    };
    mark(0, 0);
    if (lx === 0) mark(-1, 0);
    if (lx === SIZE - 1) mark(1, 0);
    if (lz === 0) mark(0, -1);
    if (lz === SIZE - 1) mark(0, 1);
  }

  settleColumn(x, z) {
    this.suppress = true;
    for (let y = 1; y < HEIGHT; y++) {
      const id = this.getBlock(x, y, z);
      if (id !== SAND && id !== GRAVEL) continue;
      if (this.getBlock(x, y - 1, z) !== AIR) continue;
      let ny = y - 1;
      while (ny > 0 && this.getBlock(x, ny - 1, z) === AIR) ny--;
      this.setBlock(x, y, z, AIR, { noFall: true });
      this.setBlock(x, ny, z, id, { noFall: true });
    }
    this.suppress = false;
  }

  ensureChest(x, y, z) {
    const key = blockKey(x, y, z);
    if (!this.chests.has(key)) this.chests.set(key, Array.from({ length: 27 }, () => null));
    return this.chests.get(key);
  }

  ensureFurnace(x, y, z) {
    const key = blockKey(x, y, z);
    if (!this.furnaces.has(key)) {
      this.furnaces.set(key, { input: null, fuel: null, output: null, burn: 0, burnMax: 0, cook: 0 });
    }
    return this.furnaces.get(key);
  }

  tickFurnaces(dt) {
    const ticks = dt * 20;
    for (const [key, f] of this.furnaces) {
      const [x, y, z] = key.split(",").map(Number);
      const result = f.input ? smeltResult(f.input.id) : 0;
      const canOut = result && (!f.output || (f.output.id === result && f.output.count < 64));
      if (f.burn > 0) f.burn = Math.max(0, f.burn - ticks);
      if (f.burn <= 0 && canOut && f.fuel && fuelValue(f.fuel.id) > 0) {
        f.burnMax = fuelValue(f.fuel.id) * 20;
        f.burn = f.burnMax;
        f.fuel.count -= 1;
        if (f.fuel.count <= 0) f.fuel = null;
      }
      if (f.burn > 0 && canOut) {
        f.cook += ticks;
        if (f.cook >= 200) {
          f.cook = 0;
          f.input.count -= 1;
          if (f.input.count <= 0) f.input = null;
          if (!f.output) f.output = { id: result, count: 1 };
          else f.output.count += 1;
        }
      } else if (!canOut) f.cook = Math.max(0, f.cook - ticks);
      const lit = f.burn > 0;
      const cur = this.getBlock(x, y, z);
      if (lit && cur === FURNACE) this.setBlock(x, y, z, FURNACE_LIT, { noFall: true });
      if (!lit && cur === FURNACE_LIT) this.setBlock(x, y, z, FURNACE, { noFall: true });
    }
  }

  update(px, pz, radius, budget) {
    const cx = floorDiv(px, SIZE);
    const cz = floorDiv(pz, SIZE);
    const want = [];
    for (let dz = -radius; dz <= radius; dz++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dz * dz > radius * radius + 1) continue;
        want.push([cx + dx, cz + dz, dx * dx + dz * dz]);
      }
    }
    want.sort((a, b) => a[2] - b[2]);
    let requested = 0;
    for (const [x, z] of want) {
      if (requested > 4) break;
      const key = chunkKey(x, z);
      if (!this.chunks.has(key) && !this.inflight.has(key)) {
        this.request(x, z);
        requested++;
      }
    }
    const keep = radius + 2;
    for (const [key, chunk] of this.chunks) {
      const dx = chunk.cx - cx;
      const dz = chunk.cz - cz;
      if (dx * dx + dz * dz > keep * keep) {
        if (this.onDispose) this.onDispose(key);
        this.chunks.delete(key);
      }
    }
    let built = 0;
    const list = [...this.chunks.values()].sort((a, b) => {
      const da = (a.cx - cx) ** 2 + (a.cz - cz) ** 2;
      const db = (b.cx - cx) ** 2 + (b.cz - cz) ** 2;
      return da - db;
    });
    for (const chunk of list) {
      if (!chunk.lightDirty && !chunk.meshDirty) continue;
      if (chunk.lightDirty) {
        computeLight(this, chunk);
        chunk.lightDirty = false;
        chunk.meshDirty = true;
      }
      if (built >= budget) continue;
      if (!chunk.meshDirty) continue;
      const mesh = buildMesh(
        chunk.cx * SIZE,
        chunk.cz * SIZE,
        (x, y, z) => {
          const id = this.getBlock(x, y, z);
          return id === UNLOADED ? AIR : id;
        },
        (x, y, z) => this.lightAt(x, y, z),
        (x, z) => this.getBiome(x, z),
      );
      chunk.meshDirty = false;
      if (this.onUpload) this.onUpload(chunkKey(chunk.cx, chunk.cz), mesh);
      built++;
    }
    return { loaded: this.chunks.size, inflight: this.inflight.size };
  }

  exportMods() {
    const out = [];
    for (const [k, id] of this.mods) {
      const [x, y, z] = k.split(",").map(Number);
      out.push(x, y, z, id);
    }
    return out;
  }

  importMods(list) {
    if (!list) return;
    for (let i = 0; i < list.length; i += 4) {
      this.mods.set(blockKey(list[i], list[i + 1], list[i + 2]), list[i + 3]);
    }
    for (const chunk of this.chunks.values()) {
      const local = this.modsIn(chunk.cx, chunk.cz);
      for (let i = 0; i < local.length; i += 4) {
        const x = local[i];
        const y = local[i + 1];
        const z = local[i + 2];
        const id = local[i + 3];
        chunk.blocks[idx(x - chunk.cx * SIZE, y, z - chunk.cz * SIZE)] = id;
      }
      chunk.lightDirty = true;
      chunk.meshDirty = true;
    }
  }

  dispose() {
    if (this.worker) this.worker.terminate();
    this.worker = null;
  }
}
