import { HEIGHT, SIZE } from "./constants.js";
import { AIR, LAVA, WATER, blockOf } from "./blocks.js";
import { TILE } from "./tiles.js";
import { BIOME } from "./generator.js";

function hides(selfId, neighborId) {
  if (neighborId === AIR || neighborId == null) return false;
  const self = blockOf(selfId);
  const nei = blockOf(neighborId);
  if (!self || !nei) return false;
  if (nei.occlude) return true;
  if (selfId === neighborId && (self.fluid || self.glass || self.leaves)) return true;
  if (self.fluid && nei.fluid && !!self.lava === !!nei.lava) return true;
  return false;
}

function tileFor(id, axis, sign, biome) {
  const b = blockOf(id);
  if (!b) return 0;
  if (id === 1) {
    if (axis === 1 && sign > 0) return biome === BIOME.TAIGA ? TILE.GRASS_TAIGA : TILE.GRASS_TOP;
    if (axis === 1 && sign < 0) return TILE.DIRT;
    return biome === BIOME.TAIGA ? TILE.GRASS_SIDE_TAIGA : TILE.GRASS_SIDE;
  }
  if (axis === 1 && sign > 0 && b.tiles?.top != null) return b.tiles.top;
  if (axis === 1 && sign < 0 && b.tiles?.bottom != null) return b.tiles.bottom;
  if (b.tiles?.front != null && axis === 2 && sign > 0) return b.tiles.front;
  if (b.tiles?.side != null) return b.tiles.side;
  return b.tiles?.all ?? 0;
}

function vertexAO(s1, s2, c) {
  if (s1 && s2) return 0;
  return 3 - ((s1 ? 1 : 0) + (s2 ? 1 : 0) + (c ? 1 : 0));
}

function solidAt(get, x, y, z) {
  const id = get(x, y, z);
  if (id === AIR) return false;
  const b = blockOf(id);
  return !!(b && (b.occlude || b.leaves || b.cactus));
}

function aoForFace(get, x, y, z, axis, sign) {
  // Average of the four corners on the outer side of this face.
  const n = [0, 0, 0];
  n[axis] = sign;
  const ux = axis === 0 ? 0 : 1;
  const uy = axis === 1 ? 0 : (axis === 0 ? 1 : 0);
  const uz = axis === 2 ? 0 : (axis === 1 ? 1 : 0);
  // Two tangent axes.
  let t1, t2;
  if (axis === 0) {
    t1 = [0, 1, 0];
    t2 = [0, 0, 1];
  } else if (axis === 1) {
    t1 = [1, 0, 0];
    t2 = [0, 0, 1];
  } else {
    t1 = [1, 0, 0];
    t2 = [0, 1, 0];
  }
  void ux; void uy; void uz;
  const signs = [[-1, -1], [1, -1], [1, 1], [-1, -1]];
  // Recompute properly for the four corners of a 1x1 face: offsets of the two tangents.
  const corners = [
    [-1, -1],
    [1, -1],
    [1, 1],
    [-1, 1],
  ];
  let sum = 0;
  const oy = y + (sign > 0 && axis === 1 ? 1 : 0);
  const ox = x + (sign > 0 && axis === 0 ? 1 : 0);
  const oz = z + (sign > 0 && axis === 2 ? 1 : 0);
  // Sample occluders in the plane one step along the normal, beside the face.
  const bx = x + n[0];
  const by = y + n[1];
  const bz = z + n[2];
  void ox; void oy; void oz;
  for (const [a, c] of corners) {
    const s1x = bx + t1[0] * a;
    const s1y = by + t1[1] * a;
    const s1z = bz + t1[2] * a;
    const s2x = bx + t2[0] * c;
    const s2y = by + t2[1] * c;
    const s2z = bz + t2[2] * c;
    const ccx = bx + t1[0] * a + t2[0] * c;
    const ccy = by + t1[1] * a + t2[1] * c;
    const ccz = bz + t1[2] * a + t2[2] * c;
    sum += vertexAO(solidAt(get, s1x, s1y, s1z), solidAt(get, s2x, s2y, s2z), solidAt(get, ccx, ccy, ccz));
  }
  return sum / 4;
}

function sameCell(a, b) {
  return a && b && a.tile === b.tile && a.light === b.light && a.ao === b.ao && a.pass === b.pass;
}

function pushQuad(bucket, verts, x, y, z, du, dv, tile, light, ao, shade, flip) {
  const base = verts.length / 9;
  const corners = flip
    ? [[0, 0], [0, 1], [1, 1], [1, 0]]
    : [[0, 0], [1, 0], [1, 1], [0, 1]];
  const side = Math.abs(du[1]) + Math.abs(dv[1]) > 0.001;
  const litA = shade * (0.42 + 0.58 * (ao / 3));
  const sky = ((light >> 4) & 15) / 15;
  const block = (light & 15) / 15;
  for (const [su, sv] of corners) {
    const px = du[0] * su + dv[0] * sv;
    const py = du[1] * su + dv[1] * sv;
    const pz = du[2] * su + dv[2] * sv;
    let tu;
    let tv;
    if (side) {
      tu = Math.abs(du[0]) + Math.abs(dv[0]) > 0 ? px : pz;
      tv = py;
    } else {
      tu = px;
      tv = pz;
    }
    verts.push(x + px, y + py, z + pz, tu, tv, tile, sky, block, litA);
  }
  bucket.push(base, base + 1, base + 2, base, base + 2, base + 3);
}

function matchesPass(b, id, want) {
  if (want === "opaque") return b.occlude && id !== LAVA;
  if (want === "cutout") return b.leaves || b.glass;
  if (want === "water") return id === WATER;
  if (want === "lava") return id === LAVA;
  return false;
}

export function buildMesh(x0, z0, getBlock, getLight, getBiome) {
  const opaque = meshCubes(x0, z0, getBlock, getLight, getBiome, "opaque");
  const cutout = meshCubes(x0, z0, getBlock, getLight, getBiome, "cutout");
  const water = meshCubes(x0, z0, getBlock, getLight, getBiome, "water");
  const lava = meshCubes(x0, z0, getBlock, getLight, getBiome, "lava");
  addSpecials(cutout, x0, z0, getBlock, getLight);
  return { opaque, cutout, water, lava };
}

function meshCubes(x0, z0, getBlock, getLight, getBiome, pass) {
  const verts = [];
  const indices = [];
  const dims = [SIZE, HEIGHT, SIZE];
  for (let axis = 0; axis < 3; axis++) {
    const u = (axis + 1) % 3;
    const v = (axis + 2) % 3;
    for (const sign of [1, -1]) {
      for (let sd = 0; sd < dims[axis]; sd++) {
        const mask = new Array(dims[u] * dims[v]);
        for (let sv = 0; sv < dims[v]; sv++) {
          for (let su = 0; su < dims[u]; su++) {
            const pos = [0, 0, 0];
            pos[axis] = sd;
            pos[u] = su;
            pos[v] = sv;
            const wx = x0 + pos[0];
            const wy = pos[1];
            const wz = z0 + pos[2];
            const id = getBlock(wx, wy, wz);
            const b = blockOf(id);
            const np = [wx, wy, wz];
            np[axis] += sign;
            const nid = getBlock(np[0], np[1], np[2]);
            if (!b || !matchesPass(b, id, pass) || hides(id, nid)) {
              mask[sv * dims[u] + su] = null;
              continue;
            }
            const lit = getLight(np[0], np[1], np[2]) || { sky: 0, block: 0 };
            const ao = Math.round(aoForFace(getBlock, wx, wy, wz, axis, sign));
            mask[sv * dims[u] + su] = {
              tile: tileFor(id, axis, sign, getBiome(wx, wz)),
              light: ((lit.sky & 15) << 4) | (lit.block & 15),
              ao,
            };
          }
        }
        for (let sv = 0; sv < dims[v]; sv++) {
          for (let su = 0; su < dims[u];) {
            const cell = mask[sv * dims[u] + su];
            if (!cell) {
              su++;
              continue;
            }
            let w = 1;
            while (su + w < dims[u] && sameCell(mask[sv * dims[u] + su + w], cell)) w++;
            let h = 1;
            outer: while (sv + h < dims[v]) {
              for (let k = 0; k < w; k++) {
                if (!sameCell(mask[(sv + h) * dims[u] + su + k], cell)) break outer;
              }
              h++;
            }
            const pos = [0, 0, 0];
            pos[axis] = sd;
            pos[u] = su;
            pos[v] = sv;
            emitRect(indices, verts, axis, sign, x0 + pos[0], pos[1], z0 + pos[2], u, v, w, h, cell);
            for (let dy = 0; dy < h; dy++) {
              for (let dx = 0; dx < w; dx++) mask[(sv + dy) * dims[u] + su + dx] = null;
            }
            su += w;
          }
        }
      }
    }
  }
  return { verts: new Float32Array(verts), indices: new Uint32Array(indices) };
}

function emitRect(indices, verts, axis, sign, x, y, z, u, v, w, h, cell) {
  const du = [0, 0, 0];
  const dv = [0, 0, 0];
  du[u] = w;
  dv[v] = h;
  const shade = axis === 1 ? (sign > 0 ? 1 : 0.55) : axis === 0 ? 0.68 : 0.8;
  let flip = false;
  let ox = x;
  let oy = y;
  let oz = z;
  if (axis === 1 && sign > 0) oy = y + 1;
  else if (axis === 1 && sign < 0) flip = true;
  else if (axis === 0 && sign > 0) ox = x + 1;
  else if (axis === 0 && sign < 0) flip = true;
  else if (axis === 2 && sign > 0) {
    oz = z + 1;
    flip = true;
  }
  // Winding check via cross product is encoded by flip.
  // +Y: du=+X dv=+Z, CCW from above needs flip false? 
  // edge1 +X, edge2 +Z => cross -Y, so we NEED flip true for +Y.
  // Recalculate:
  // +Y should have cross +Y. edge1 = +Z (dv if we swap), let's just set flip from known table.
  if (axis === 1 && sign > 0) flip = true;
  if (axis === 1 && sign < 0) flip = false;
  if (axis === 0 && sign > 0) flip = false;
  if (axis === 0 && sign < 0) flip = true;
  if (axis === 2 && sign > 0) flip = false;
  if (axis === 2 && sign < 0) flip = true;
  pushQuad(indices, verts, ox, oy, oz, du, dv, cell.tile, cell.light, cell.ao, shade, flip);
}

function addSpecials(cutout, x0, z0, getBlock, getLight) {
  const verts = Array.from(cutout.verts);
  const indices = Array.from(cutout.indices);
  for (let lz = 0; lz < SIZE; lz++) {
    for (let lx = 0; lx < SIZE; lx++) {
      for (let y = 0; y < HEIGHT; y++) {
        const x = x0 + lx;
        const z = z0 + lz;
        const id = getBlock(x, y, z);
        const b = blockOf(id);
        if (!b) continue;
        const lit = getLight(x, y, z) || { sky: 15, block: b.emit || 0 };
        const light = (((lit.sky & 15) << 4) | ((Math.max(lit.block, b.emit || 0)) & 15));
        if (b.cross) addCross(indices, verts, x, y, z, b.tiles.all, light);
        else if (b.torch) addTorch(indices, verts, x, y, z, light);
        else if (b.cactus) addCactus(indices, verts, x, y, z, b, light);
      }
    }
  }
  cutout.verts = new Float32Array(verts);
  cutout.indices = new Uint32Array(indices);
}

function addCross(indices, verts, x, y, z, tile, light) {
  const inset = 0.146;
  quadRaw(indices, verts, [x + inset, y, z + inset], [x + 1 - inset, y, z + 1 - inset], [x + 1 - inset, y + 1, z + 1 - inset], [x + inset, y + 1, z + inset], tile, light, 0.9);
  quadRaw(indices, verts, [x + 1 - inset, y, z + inset], [x + inset, y, z + 1 - inset], [x + inset, y + 1, z + 1 - inset], [x + 1 - inset, y + 1, z + inset], tile, light, 0.9);
}

function addTorch(indices, verts, x, y, z, light) {
  const s = 0.125;
  const x0 = x + 0.5 - s;
  const x1 = x + 0.5 + s;
  const z0 = z + 0.5 - s;
  const z1 = z + 0.5 + s;
  const y1 = y + 0.72;
  box(indices, verts, x0, y, z0, x1, y1, z1, TILE.TORCH, light, 1);
}

function addCactus(indices, verts, x, y, z, b, light) {
  const i = 1 / 16;
  boxTiles(indices, verts, x + i, y, z + i, x + 1 - i, y + 1, z + 1 - i, b, light);
}

function box(indices, verts, x0, y0, z0, x1, y1, z1, tile, light, shade) {
  quadRaw(indices, verts, [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1], tile, light, shade);
  quadRaw(indices, verts, [x0, y0, z1], [x1, y0, z1], [x1, y0, z0], [x0, y0, z0], tile, light, shade * 0.6);
  quadRaw(indices, verts, [x0, y0, z1], [x0, y0, z0], [x0, y1, z0], [x0, y1, z1], tile, light, shade * 0.7);
  quadRaw(indices, verts, [x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0], tile, light, shade * 0.7);
  quadRaw(indices, verts, [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], tile, light, shade * 0.82);
  quadRaw(indices, verts, [x1, y0, z1], [x0, y0, z1], [x0, y1, z1], [x1, y1, z1], tile, light, shade * 0.82);
}

function boxTiles(indices, verts, x0, y0, z0, x1, y1, z1, b, light) {
  const top = b.tiles.top ?? b.tiles.all;
  const side = b.tiles.side ?? b.tiles.all;
  const bot = b.tiles.bottom ?? b.tiles.all;
  quadRaw(indices, verts, [x0, y1, z1], [x1, y1, z1], [x1, y1, z0], [x0, y1, z0], top, light, 1);
  quadRaw(indices, verts, [x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], bot, light, 0.55);
  quadRaw(indices, verts, [x0, y0, z1], [x0, y0, z0], [x0, y1, z0], [x0, y1, z1], side, light, 0.68);
  quadRaw(indices, verts, [x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0], side, light, 0.68);
  quadRaw(indices, verts, [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], side, light, 0.8);
  quadRaw(indices, verts, [x1, y0, z1], [x0, y0, z1], [x0, y1, z1], [x1, y1, z1], side, light, 0.8);
}

function quadRaw(indices, verts, a, b, c, d, tile, light, shade) {
  const base = verts.length / 9;
  const pts = [a, b, c, d];
  const uvs = [[0, 0], [1, 0], [1, 1], [0, 1]];
  for (let i = 0; i < 4; i++) {
    verts.push(pts[i][0], pts[i][1], pts[i][2], uvs[i][0], uvs[i][1], tile, ((light >> 4) & 15) / 15, (light & 15) / 15, shade);
  }
  indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
}

export function meshBlockOutline() {
  const p = [
    [0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1],
    [0, 1, 0], [1, 1, 0], [1, 1, 1], [0, 1, 1],
  ];
  const e = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
  const verts = [];
  for (const [a, b] of e) {
    verts.push(...p[a], ...p[b]);
  }
  return new Float32Array(verts);
}
