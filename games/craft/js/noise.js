import { hash3 } from "./constants.js";

export function makeNoise(seed) {
  const s = seed >>> 0;

  function h2(x, z) {
    return hash3(x, 0, z, s) / 4294967296;
  }

  function h3(x, y, z) {
    return hash3(x, y, z, s) / 4294967296;
  }

  function fade(t) {
    return t * t * (3 - 2 * t);
  }

  function v2(x, z) {
    const x0 = Math.floor(x);
    const z0 = Math.floor(z);
    const fx = fade(x - x0);
    const fz = fade(z - z0);
    const a = h2(x0, z0);
    const b = h2(x0 + 1, z0);
    const c = h2(x0, z0 + 1);
    const d = h2(x0 + 1, z0 + 1);
    return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz;
  }

  function v3(x, y, z) {
    const x0 = Math.floor(x);
    const y0 = Math.floor(y);
    const z0 = Math.floor(z);
    const fx = fade(x - x0);
    const fy = fade(y - y0);
    const fz = fade(z - z0);
    const x1 = x0 + 1;
    const y1 = y0 + 1;
    const z1 = z0 + 1;
    const c000 = h3(x0, y0, z0);
    const c100 = h3(x1, y0, z0);
    const c010 = h3(x0, y1, z0);
    const c110 = h3(x1, y1, z0);
    const c001 = h3(x0, y0, z1);
    const c101 = h3(x1, y0, z1);
    const c011 = h3(x0, y1, z1);
    const c111 = h3(x1, y1, z1);
    const x00 = c000 + (c100 - c000) * fx;
    const x10 = c010 + (c110 - c010) * fx;
    const x01 = c001 + (c101 - c001) * fx;
    const x11 = c011 + (c111 - c011) * fx;
    const y0v = x00 + (x10 - x00) * fy;
    const y1v = x01 + (x11 - x01) * fy;
    return y0v + (y1v - y0v) * fz;
  }

  function fbm2(x, z, octaves) {
    let amp = 1;
    let freq = 1;
    let sum = 0;
    let norm = 0;
    for (let i = 0; i < octaves; i++) {
      sum += v2(x * freq, z * freq) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return sum / norm;
  }

  return { v2, v3, fbm2, h2, h3 };
}
