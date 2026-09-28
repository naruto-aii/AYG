import { LAVA, WATER, collides } from "./blocks.js";

export function overlaps(world, ent) {
  const minX = ent.x - ent.w * 0.5;
  const maxX = ent.x + ent.w * 0.5;
  const minY = ent.y;
  const maxY = ent.y + ent.h;
  const minZ = ent.z - ent.d * 0.5;
  const maxZ = ent.z + ent.d * 0.5;
  const x0 = Math.floor(minX);
  const x1 = Math.floor(maxX - 1e-4);
  const y0 = Math.floor(minY);
  const y1 = Math.floor(maxY - 1e-4);
  const z0 = Math.floor(minZ);
  const z1 = Math.floor(maxZ - 1e-4);
  for (let y = y0; y <= y1; y++) {
    for (let z = z0; z <= z1; z++) {
      for (let x = x0; x <= x1; x++) {
        if (collides(world.getBlock(x, y, z))) return true;
      }
    }
  }
  return false;
}

function sweep(world, ent, axis, delta) {
  if (delta === 0) return false;
  const start = ent[axis];
  ent[axis] = start + delta;
  if (!overlaps(world, ent)) return false;
  let lo = 0;
  let hi = delta;
  for (let i = 0; i < 10; i++) {
    const mid = (lo + hi) * 0.5;
    ent[axis] = start + mid;
    if (overlaps(world, ent)) hi = mid;
    else lo = mid;
  }
  ent[axis] = start + lo;
  if (axis === "y") ent.vy = 0;
  if (axis === "x") ent.vx = 0;
  if (axis === "z") ent.vz = 0;
  if (axis === "y" && delta < 0) ent.onGround = true;
  return true;
}

function hasFloor(world, ent, x, z) {
  const y = Math.floor(ent.y - 0.02);
  const x0 = Math.floor(x - ent.w * 0.5 + 0.02);
  const x1 = Math.floor(x + ent.w * 0.5 - 0.02);
  const z0 = Math.floor(z - ent.d * 0.5 + 0.02);
  const z1 = Math.floor(z + ent.d * 0.5 - 0.02);
  for (let zz = z0; zz <= z1; zz++) {
    for (let xx = x0; xx <= x1; xx++) {
      if (collides(world.getBlock(xx, y, zz))) return true;
    }
  }
  return false;
}

export function moveBody(world, ent, dx, dy, dz, opts = {}) {
  ent.onGround = false;
  const step = opts.step || 0;
  const sneak = !!opts.sneak;

  const moveH = (axis, delta) => {
    if (!delta) return;
    if (sneak && ent.wasGround) {
      const nx = axis === "x" ? ent.x + delta : ent.x;
      const nz = axis === "z" ? ent.z + delta : ent.z;
      if (!hasFloor(world, ent, nx, nz)) return;
    }
    const before = ent[axis];
    const blocked = sweep(world, ent, axis, delta);
    if (blocked && step && ent.wasGround) {
      const stopped = ent[axis];
      ent[axis] = before;
      const y0 = ent.y;
      ent.y = y0 + step;
      if (!overlaps(world, ent)) {
        sweep(world, ent, axis, delta);
        if (Math.abs(ent[axis] - (before + delta)) < Math.abs(stopped - (before + delta))) return;
      }
      ent.y = y0;
      ent[axis] = stopped;
    }
  };

  ent.wasGround = !!opts.wasGround;
  moveH("x", dx);
  moveH("z", dz);
  sweep(world, ent, "y", dy);
  ent.wasGround = ent.onGround;
}

export function bodyIn(world, ent, id, height) {
  const y = Math.floor(ent.y + height);
  return world.getBlock(Math.floor(ent.x), y, Math.floor(ent.z)) === id;
}

export function inWater(world, ent) {
  return bodyIn(world, ent, WATER, 0.2) || bodyIn(world, ent, WATER, ent.h * 0.6);
}

export function headInWater(world, ent) {
  return bodyIn(world, ent, WATER, ent.h - 0.15);
}

export function inLava(world, ent) {
  return bodyIn(world, ent, LAVA, 0.2) || bodyIn(world, ent, LAVA, ent.h * 0.5);
}

export function raycast(world, ox, oy, oz, dx, dy, dz, maxDist) {
  const len = Math.hypot(dx, dy, dz) || 1;
  dx /= len;
  dy /= len;
  dz /= len;
  let x = Math.floor(ox);
  let y = Math.floor(oy);
  let z = Math.floor(oz);
  const stepX = dx > 0 ? 1 : dx < 0 ? -1 : 0;
  const stepY = dy > 0 ? 1 : dy < 0 ? -1 : 0;
  const stepZ = dz > 0 ? 1 : dz < 0 ? -1 : 0;
  const tDeltaX = stepX === 0 ? Infinity : Math.abs(1 / dx);
  const tDeltaY = stepY === 0 ? Infinity : Math.abs(1 / dy);
  const tDeltaZ = stepZ === 0 ? Infinity : Math.abs(1 / dz);
  let tMaxX = stepX > 0 ? (x + 1 - ox) * tDeltaX : stepX < 0 ? (ox - x) * tDeltaX : Infinity;
  let tMaxY = stepY > 0 ? (y + 1 - oy) * tDeltaY : stepY < 0 ? (oy - y) * tDeltaY : Infinity;
  let tMaxZ = stepZ > 0 ? (z + 1 - oz) * tDeltaZ : stepZ < 0 ? (oz - z) * tDeltaZ : Infinity;
  let prev = null;
  let dist = 0;
  for (let i = 0; i < 48; i++) {
    const id = world.getBlock(x, y, z);
    if (id && id !== 255 && id !== WATER && id !== LAVA) {
      return {
        x, y, z, id,
        px: prev ? prev.x : x,
        py: prev ? prev.y : y,
        pz: prev ? prev.z : z,
        dist,
      };
    }
    if (tMaxX < tMaxY && tMaxX < tMaxZ) {
      if (tMaxX > maxDist) return null;
      dist = tMaxX;
      prev = { x, y, z };
      x += stepX;
      tMaxX += tDeltaX;
    } else if (tMaxY < tMaxZ) {
      if (tMaxY > maxDist) return null;
      dist = tMaxY;
      prev = { x, y, z };
      y += stepY;
      tMaxY += tDeltaY;
    } else {
      if (tMaxZ > maxDist) return null;
      dist = tMaxZ;
      prev = { x, y, z };
      z += stepZ;
      tMaxZ += tDeltaZ;
    }
  }
  return null;
}

export function rayAabb(ox, oy, oz, dx, dy, dz, box, maxDist) {
  const invX = dx !== 0 ? 1 / dx : Infinity;
  const invY = dy !== 0 ? 1 / dy : Infinity;
  const invZ = dz !== 0 ? 1 / dz : Infinity;
  let t1 = (box.minX - ox) * invX;
  let t2 = (box.maxX - ox) * invX;
  let t3 = (box.minY - oy) * invY;
  let t4 = (box.maxY - oy) * invY;
  let t5 = (box.minZ - oz) * invZ;
  let t6 = (box.maxZ - oz) * invZ;
  let tmin = Math.max(Math.min(t1, t2), Math.min(t3, t4), Math.min(t5, t6));
  const tmax = Math.min(Math.max(t1, t2), Math.max(t3, t4), Math.max(t5, t6));
  if (tmax < 0 || tmin > tmax || tmin > maxDist) return null;
  if (tmin < 0) tmin = 0;
  return tmin;
}
