export const SIZE = 16;
export const HEIGHT = 128;
export const SEA = 52;
export const VOLUME = SIZE * SIZE * HEIGHT;
export const UNLOADED = 255;

export function idx(x, y, z) {
  return x + z * SIZE + y * SIZE * SIZE;
}

export function chunkKey(cx, cz) {
  return cx + "," + cz;
}

export function blockKey(x, y, z) {
  return x + "," + y + "," + z;
}

export function floorDiv(n, d) {
  return Math.floor(n / d);
}

export function clamp(v, a, b) {
  return v < a ? a : v > b ? b : v;
}

export function lerp(a, b, t) {
  return a + (b - a) * t;
}

export function smoothstep(e0, e1, x) {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

export function hash3(x, y, z, seed) {
  let h = (Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(z | 0, 1274126177) ^ (seed | 0)) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return (h ^ (h >>> 16)) >>> 0;
}

export function hash01(x, y, z, seed) {
  return hash3(x, y, z, seed) / 4294967296;
}
