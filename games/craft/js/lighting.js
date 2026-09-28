import { HEIGHT, SIZE, VOLUME, idx } from "./constants.js";
import { AIR, blockOf } from "./blocks.js";

const DX = [1, -1, 0, 0, 0, 0];
const DY = [0, 0, 1, -1, 0, 0];
const DZ = [0, 0, 0, 0, 1, -1];

function spreadFall(id) {
  if (id === AIR || id === 255) return 1;
  const b = blockOf(id);
  if (!b) return 1;
  if (b.occlude || b.lava) return 99;
  if (b.fluid) return 3;
  if (b.leaves) return 2;
  return 1;
}

export function computeLight(world, chunk) {
  const blocks = chunk.blocks;
  const sky = new Uint8Array(VOLUME);
  const glow = new Uint8Array(VOLUME);
  const q = new Int32Array(VOLUME * 4);
  let qs = 0;
  let qe = 0;
  const push = (i) => {
    q[qe++] = i;
  };

  const x0 = chunk.cx * SIZE;
  const z0 = chunk.cz * SIZE;

  for (let lz = 0; lz < SIZE; lz++) {
    for (let lx = 0; lx < SIZE; lx++) {
      let sun = 15;
      for (let y = HEIGHT - 1; y >= 0; y--) {
        const i = idx(lx, y, lz);
        const id = blocks[i];
        const fall = spreadFall(id);
        if (fall >= 99) {
          sun = 0;
          sky[i] = 0;
        } else {
          sky[i] = sun;
          if (sun > 0) push(i);
          sun = Math.max(0, sun - (fall - 1));
        }
        const emit = blockOf(id)?.emit || 0;
        if (emit > 0) {
          glow[i] = emit;
          push(i);
        }
      }
    }
  }

  // Pull light in from already-lit neighbors so caves and torches cross chunk borders.
  for (let lz = 0; lz < SIZE; lz++) {
    for (let y = 0; y < HEIGHT; y++) {
      seedBorder(world, sky, glow, push, x0 - 1, y, z0 + lz, 0, y, lz);
      seedBorder(world, sky, glow, push, x0 + SIZE, y, z0 + lz, SIZE - 1, y, lz);
    }
  }
  for (let lx = 0; lx < SIZE; lx++) {
    for (let y = 0; y < HEIGHT; y++) {
      seedBorder(world, sky, glow, push, x0 + lx, y, z0 - 1, lx, y, 0);
      seedBorder(world, sky, glow, push, x0 + lx, y, z0 + SIZE, lx, y, SIZE - 1);
    }
  }

  while (qs < qe) {
    const i = q[qs++];
    const y = (i / (SIZE * SIZE)) | 0;
    const rem = i - y * SIZE * SIZE;
    const z = (rem / SIZE) | 0;
    const x = rem - z * SIZE;
    const s0 = sky[i];
    const g0 = glow[i];
    for (let d = 0; d < 6; d++) {
      const nx = x + DX[d];
      const ny = y + DY[d];
      const nz = z + DZ[d];
      if (ny < 0 || ny >= HEIGHT) continue;
      if (nx < 0 || nz < 0 || nx >= SIZE || nz >= SIZE) {
        spill(world, chunk, x0 + x, y, z0 + z, x0 + nx, ny, z0 + nz, s0, g0);
        continue;
      }
      const ni = idx(nx, ny, nz);
      const cost = spreadFall(blocks[ni]);
      if (cost >= 99) continue;
      if (s0 - cost > sky[ni]) {
        sky[ni] = s0 - cost;
        push(ni);
      }
      if (g0 - cost > glow[ni]) {
        glow[ni] = g0 - cost;
        push(ni);
      }
    }
  }

  chunk.sky = sky;
  chunk.glow = glow;
}

function seedBorder(world, sky, glow, push, wx, y, wz, lx, y2, lz) {
  const sample = world.sampleLight(wx, y, wz);
  if (!sample) return;
  const i = idx(lx, y2, lz);
  const cost = 1;
  if (sample.sky - cost > sky[i]) {
    sky[i] = sample.sky - cost;
    push(i);
  }
  if (sample.block - cost > glow[i]) {
    glow[i] = sample.block - cost;
    push(i);
  }
}

function spill(world, chunk, x, y, z, nx, ny, nz, s0, g0) {
  const id = world.getBlock(nx, ny, nz);
  const cost = spreadFall(id);
  if (cost >= 99) return;
  const nb = world.chunkOf(nx, nz);
  if (!nb || nb === chunk || !nb.sky) {
    if (nb && nb !== chunk) nb.lightDirty = true;
    return;
  }
  const lx = nx - nb.cx * SIZE;
  const lz = nz - nb.cz * SIZE;
  const i = idx(lx, ny, lz);
  if (s0 - cost > nb.sky[i] + 1 || g0 - cost > nb.glow[i] + 1) nb.lightDirty = true;
}
