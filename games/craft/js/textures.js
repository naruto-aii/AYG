import { hash3 } from "./constants.js";
import { COLS, ROWS, TILE } from "./tiles.js";

const T = 16;

function clampByte(v) {
  return v < 0 ? 0 : v > 255 ? 255 : v | 0;
}

export function createTextures() {
  const canvas = document.createElement("canvas");
  canvas.width = COLS * T;
  canvas.height = ROWS * T;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  const image = ctx.createImageData(canvas.width, canvas.height);
  const data = image.data;

  const set = (tile, x, y, r, g, b, a = 255) => {
    if (x < 0 || y < 0 || x >= T || y >= T) return;
    const col = tile % COLS;
    const row = (tile / COLS) | 0;
    const px = col * T + x;
    const py = row * T + y;
    const i = (py * canvas.width + px) * 4;
    data[i] = clampByte(r);
    data[i + 1] = clampByte(g);
    data[i + 2] = clampByte(b);
    data[i + 3] = clampByte(a);
  };
  const fill = (tile, r, g, b, a = 255) => {
    for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) set(tile, x, y, r, g, b, a);
  };
  const shade = (tile, base, amp, salt) => {
    for (let y = 0; y < T; y++) {
      for (let x = 0; x < T; x++) {
        const n = (hash3(x, y, salt, 91) & 15) - 8;
        const d = n * amp;
        set(tile, x, y, base[0] + d, base[1] + d, base[2] + d, base[3] ?? 255);
      }
    }
  };

  shade(TILE.GRASS_TOP, [104, 170, 52], 1.15, 3);
  for (const [x, y] of [[1, 2], [4, 7], [6, 1], [9, 4], [12, 2], [14, 8], [2, 12], [7, 13], [11, 10], [15, 14], [8, 8], [3, 5]]) {
    set(TILE.GRASS_TOP, x, y, 72, 132, 34);
  }
  for (const [x, y] of [[2, 3], [10, 1], [5, 11], [13, 12], [8, 6]]) {
    set(TILE.GRASS_TOP, x, y, 138, 198, 70);
  }

  shade(TILE.GRASS_TAIGA, [62, 130, 78], 1.1, 8);
  for (const [x, y] of [[2, 4], [8, 2], [13, 6], [5, 12], [11, 13]]) set(TILE.GRASS_TAIGA, x, y, 46, 104, 64);

  shade(TILE.DIRT, [134, 98, 64], 1.2, 4);
  for (const [x, y] of [[1, 3], [6, 2], [11, 5], [3, 9], [8, 12], [14, 8], [5, 15], [12, 13], [9, 7]]) {
    set(TILE.DIRT, x, y, 112, 78, 48);
  }
  for (const [x, y] of [[4, 4], [13, 2], [7, 10], [2, 14]]) set(TILE.DIRT, x, y, 156, 118, 78);

  const grassEdge = [3, 4, 3, 5, 4, 2, 4, 6, 3, 4, 5, 3, 4, 2, 5, 3];
  const paintSide = (tile, greens) => {
    shade(tile, [134, 98, 64], 1.05, tile + 2);
    for (let x = 0; x < 16; x++) {
      for (let y = 0; y < grassEdge[x]; y++) {
        const n = hash3(x, y, tile, 5) & 3;
        const c = greens[n % greens.length];
        set(tile, x, y, c[0], c[1], c[2]);
      }
      const e = grassEdge[x];
      if (e < 16) set(tile, x, e, 96, 78, 48);
    }
  };
  paintSide(TILE.GRASS_SIDE, [[98, 166, 50], [78, 142, 38], [124, 186, 62], [68, 122, 34]]);
  paintSide(TILE.GRASS_SIDE_TAIGA, [[70, 136, 86], [54, 116, 74], [88, 154, 98], [48, 100, 68]]);

  shade(TILE.STONE, [124, 124, 128], 0.9, 6);
  for (const [x, y] of [[0, 5], [1, 5], [2, 6], [3, 6], [8, 2], [9, 2], [10, 3], [11, 3], [5, 11], [6, 12], [7, 12], [13, 8], [14, 7], [4, 14], [15, 10]]) {
    set(TILE.STONE, x, y, 96, 96, 100);
  }
  for (const [x, y] of [[2, 2], [7, 8], [12, 12], [14, 4], [5, 6]]) set(TILE.STONE, x, y, 168, 168, 172);

  fill(TILE.COBBLE, 108, 108, 112);
  const stones = [
    [3.2, 3.4, 3.1, [146, 146, 150]],
    [8.6, 4.2, 2.6, [132, 132, 136]],
    [13.2, 3.1, 2.4, [158, 158, 160]],
    [4.4, 9.2, 3.0, [138, 138, 142]],
    [10.2, 10.4, 3.3, [150, 150, 154]],
    [14.4, 12.2, 2.5, [126, 126, 130]],
    [6.5, 14.2, 2.2, [160, 160, 164]],
  ];
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      let best = null;
      let bestD = 99;
      for (const [cx, cy, r, col] of stones) {
        const d = Math.hypot(x - cx, y - cy);
        if (d < bestD) {
          bestD = d;
          best = { d, r, col };
        }
      }
      if (!best) continue;
      if (best.d <= best.r - 0.15) set(TILE.COBBLE, x, y, best.col[0], best.col[1], best.col[2]);
      else set(TILE.COBBLE, x, y, 78, 78, 82);
    }
  }

  shade(TILE.SAND, [220, 208, 156], 0.7, 9);
  for (const [x, y] of [[2, 3], [8, 1], [14, 6], [5, 9], [11, 12], [3, 14], [9, 7]]) set(TILE.SAND, x, y, 196, 180, 122);
  shade(TILE.GRAVEL, [128, 124, 120], 1.3, 10);
  for (const [x, y, c] of [[2, 2, 90], [6, 5, 150], [11, 3, 86], [4, 10, 156], [9, 12, 92], [14, 9, 148], [7, 15, 100]]) {
    set(TILE.GRAVEL, x, y, c, c - 4, c - 8);
  }

  shade(TILE.LOG_SIDE, [96, 74, 46], 0.8, 11);
  for (let x = 0; x < 16; x++) {
    if (x % 4 === 0) for (let y = 0; y < 16; y++) set(TILE.LOG_SIDE, x, y, 72, 54, 32);
  }
  for (const [x, y] of [[6, 4], [6, 5], [7, 5], [10, 11], [11, 11]]) set(TILE.LOG_SIDE, x, y, 64, 46, 28);

  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const d = Math.hypot(x - 7.5, y - 7.5);
      const ring = Math.floor(d * 1.15);
      const bark = ring > 6.2;
      const light = ring % 2 === 0;
      if (bark) set(TILE.LOG_TOP, x, y, 102, 78, 48);
      else set(TILE.LOG_TOP, x, y, light ? 176 : 154, light ? 138 : 116, light ? 78 : 62);
    }
  }
  set(TILE.LOG_TOP, 8, 7, 120, 86, 48);

  shade(TILE.SPRUCE_SIDE, [70, 52, 34], 0.75, 12);
  for (let x = 0; x < 16; x++) if (x % 3 === 0) for (let y = 0; y < 16; y++) set(TILE.SPRUCE_SIDE, x, y, 52, 38, 24);
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const d = Math.hypot(x - 7.5, y - 7.5);
      const ring = Math.floor(d);
      if (ring > 6) set(TILE.SPRUCE_TOP, x, y, 64, 48, 32);
      else set(TILE.SPRUCE_TOP, x, y, ring % 2 ? 128 : 146, ring % 2 ? 100 : 116, 70);
    }
  }

  const leaf = (tile, a, b, c, salt) => {
    shade(tile, a, 1.1, salt);
    const holes = [[0, 2], [3, 0], [6, 3], [9, 1], [13, 4], [15, 0], [1, 7], [4, 8], [8, 6], [11, 9], [14, 11], [2, 12], [7, 14], [12, 15], [5, 11], [10, 13]];
    for (const [x, y] of holes) set(tile, x, y, 0, 0, 0, 0);
    for (const [x, y] of [[2, 5], [8, 9], [12, 7]]) set(tile, x, y, b[0], b[1], b[2]);
    for (const [x, y] of [[5, 6], [14, 8]]) set(tile, x, y, c[0], c[1], c[2]);
  };
  leaf(TILE.LEAVES, [52, 122, 36], [34, 96, 26], [82, 156, 48], 13);
  leaf(TILE.SPRUCE_LEAVES, [42, 92, 58], [28, 70, 46], [64, 120, 78], 14);

  const boards = [[168, 132, 78], [154, 118, 68], [176, 142, 86], [148, 112, 64]];
  for (let y = 0; y < 16; y++) {
    const band = boards[(y / 4) | 0];
    for (let x = 0; x < 16; x++) {
      const n = ((hash3(x, y, 15, 2) & 7) - 3) * 2;
      set(TILE.PLANKS, x, y, band[0] + n, band[1] + n, band[2] + n);
    }
    if (y % 4 === 3) for (let x = 0; x < 16; x++) set(TILE.PLANKS, x, y, 112, 82, 46);
  }
  set(TILE.PLANKS, 3, 1, 120, 86, 48);
  set(TILE.PLANKS, 11, 6, 126, 90, 50);
  set(TILE.PLANKS, 6, 10, 118, 84, 46);

  shade(TILE.BEDROCK, [68, 68, 72], 1.4, 16);
  for (let i = 0; i < 18; i++) {
    const x = hash3(i, 1, 2, 3) & 15;
    const y = hash3(i, 4, 5, 6) & 15;
    set(TILE.BEDROCK, x, y, 36, 36, 40);
  }

  const ore = (tile, color) => {
    shade(tile, [124, 124, 128], 0.7, tile);
    for (const [x, y] of color.spots) set(tile, x, y, color.c[0], color.c[1], color.c[2]);
    for (const [x, y] of color.spots2 || []) set(tile, x, y, color.d[0], color.d[1], color.d[2]);
  };
  ore(TILE.COAL_ORE, { c: [38, 38, 42], d: [22, 22, 26], spots: [[3, 4], [4, 4], [4, 5], [10, 9], [11, 8], [11, 9]], spots2: [[6, 13], [7, 12], [13, 3]] });
  ore(TILE.IRON_ORE, { c: [214, 176, 146], d: [168, 124, 100], spots: [[3, 5], [4, 6], [5, 5], [11, 3], [12, 4]], spots2: [[8, 11], [9, 12], [8, 12]] });
  ore(TILE.GOLD_ORE, { c: [242, 206, 74], d: [214, 168, 42], spots: [[2, 8], [3, 8], [3, 9], [12, 5], [13, 5]], spots2: [[7, 3], [8, 13]] });
  ore(TILE.DIAMOND_ORE, { c: [92, 236, 214], d: [64, 196, 184], spots: [[5, 4], [6, 5], [6, 4], [11, 11], [12, 10]], spots2: [[3, 12], [9, 2]] });

  shade(TILE.TABLE_TOP, [168, 132, 78], 0.5, 21);
  for (let i = 0; i < 16; i++) {
    set(TILE.TABLE_TOP, i, 0, 120, 86, 48);
    set(TILE.TABLE_TOP, i, 15, 120, 86, 48);
    set(TILE.TABLE_TOP, 0, i, 120, 86, 48);
    set(TILE.TABLE_TOP, 15, i, 120, 86, 48);
  }
  for (let y = 4; y <= 11; y++) for (let x = 4; x <= 11; x++) set(TILE.TABLE_TOP, x, y, x === 4 || y === 4 || x === 11 || y === 11 ? 96 : 196, x === 4 || y === 4 || x === 11 || y === 11 ? 96 : 196, x === 4 || y === 4 || x === 11 || y === 11 ? 96 : 196);
  shade(TILE.TABLE_SIDE, [168, 132, 78], 0.5, 22);
  shade(TILE.TABLE_FRONT, [154, 118, 68], 0.45, 23);
  for (let x = 2; x <= 13; x++) for (let y = 3; y <= 12; y++) {
    const border = x === 2 || y === 3 || x === 13 || y === 12 || x === 7 || y === 7;
    if (border) set(TILE.TABLE_FRONT, x, y, 92, 68, 40);
  }

  shade(TILE.FURNACE_SIDE, [118, 118, 122], 0.6, 24);
  shade(TILE.FURNACE_TOP, [108, 108, 112], 0.5, 25);
  for (let i = 3; i < 13; i++) {
    set(TILE.FURNACE_TOP, i, 6, 70, 70, 74);
    set(TILE.FURNACE_TOP, 6, i, 70, 70, 74);
  }
  shade(TILE.FURNACE_FRONT, [112, 112, 116], 0.4, 26);
  for (let y = 3; y <= 8; y++) for (let x = 4; x <= 11; x++) set(TILE.FURNACE_FRONT, x, y, 48, 48, 52);
  for (let y = 11; y <= 14; y++) for (let x = 5; x <= 10; x++) set(TILE.FURNACE_FRONT, x, y, 70, 70, 74);
  shade(TILE.FURNACE_LIT, [112, 112, 116], 0.4, 26);
  for (let y = 3; y <= 8; y++) for (let x = 4; x <= 11; x++) set(TILE.FURNACE_LIT, x, y, 48, 48, 52);
  for (let y = 11; y <= 14; y++) for (let x = 5; x <= 10; x++) set(TILE.FURNACE_LIT, x, y, y < 13 ? 240 : 180, y < 13 ? 150 : 70, 30);

  shade(TILE.CHEST_SIDE, [148, 104, 52], 0.55, 27);
  shade(TILE.CHEST_TOP, [168, 122, 62], 0.4, 28);
  for (let x = 2; x < 14; x++) set(TILE.CHEST_TOP, x, 7, 96, 68, 36);
  shade(TILE.CHEST_FRONT, [156, 112, 58], 0.4, 29);
  for (let y = 2; y < 14; y++) set(TILE.CHEST_FRONT, 3, y, 210, 176, 64);
  for (let y = 6; y <= 9; y++) for (let x = 6; x <= 9; x++) set(TILE.CHEST_FRONT, x, y, 232, 196, 78);
  set(TILE.CHEST_FRONT, 7, 8, 90, 64, 32);

  fill(TILE.TORCH, 0, 0, 0, 0);
  for (let y = 7; y < 16; y++) {
    set(TILE.TORCH, 7, y, 92, 70, 42);
    set(TILE.TORCH, 8, y, 110, 84, 50);
  }
  for (const [x, y, c] of [[7, 3, [250, 220, 80]], [8, 3, [250, 230, 120]], [6, 4, [240, 160, 40]], [7, 4, [255, 240, 160]], [8, 4, [255, 210, 70]], [9, 4, [230, 120, 30]], [7, 5, [255, 180, 40]], [8, 5, [255, 150, 30]], [7, 6, [200, 90, 24]], [8, 6, [220, 120, 30]]]) {
    set(TILE.TORCH, x, y, c[0], c[1], c[2]);
  }

  shade(TILE.GLASS, [196, 220, 224], 0.35, 31);
  for (let i = 0; i < 16; i++) {
    set(TILE.GLASS, i, 0, 230, 244, 246, 210);
    set(TILE.GLASS, 0, i, 230, 244, 246, 210);
    set(TILE.GLASS, i, 15, 150, 180, 186, 200);
    set(TILE.GLASS, 15, i, 150, 180, 186, 200);
  }
  {
    const col = TILE.GLASS % COLS;
    const row = (TILE.GLASS / COLS) | 0;
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const i = ((row * T + y) * canvas.width + col * T + x) * 4;
        data[i + 3] = 150;
      }
    }
  }

  shade(TILE.SANDSTONE, [210, 196, 140], 0.45, 32);
  for (let y of [0, 1, 14, 15]) for (let x = 0; x < 16; x++) set(TILE.SANDSTONE, x, y, y < 2 ? 224 : 176, y < 2 ? 210 : 160, y < 2 ? 150 : 112);
  for (let y = 5; y <= 6; y++) for (let x = 0; x < 16; x++) set(TILE.SANDSTONE, x, y, 188, 170, 116);
  shade(TILE.SANDSTONE_TOP, [216, 202, 146], 0.35, 33);

  shade(TILE.SNOW, [236, 242, 246], 0.35, 34);
  for (const [x, y] of [[3, 4], [10, 2], [6, 11], [13, 9]]) set(TILE.SNOW, x, y, 210, 220, 228);

  shade(TILE.CACTUS_SIDE, [62, 140, 52], 0.8, 35);
  for (let y = 0; y < 16; y++) {
    set(TILE.CACTUS_SIDE, 0, y, 40, 100, 36);
    set(TILE.CACTUS_SIDE, 15, y, 40, 100, 36);
    if (y % 5 === 0) for (let x = 0; x < 16; x++) set(TILE.CACTUS_SIDE, x, y, 46, 112, 40);
  }
  for (const [x, y] of [[4, 3], [11, 8], [6, 13]]) set(TILE.CACTUS_SIDE, x, y, 230, 230, 220);
  shade(TILE.CACTUS_TOP, [74, 158, 60], 0.5, 36);
  for (let i = 2; i < 14; i++) {
    set(TILE.CACTUS_TOP, i, 2, 40, 110, 36);
    set(TILE.CACTUS_TOP, i, 13, 40, 110, 36);
    set(TILE.CACTUS_TOP, 2, i, 40, 110, 36);
    set(TILE.CACTUS_TOP, 13, i, 40, 110, 36);
  }

  fill(TILE.FLOWER, 0, 0, 0, 0);
  for (let y = 8; y < 16; y++) set(TILE.FLOWER, 8, y, 50, 120, 40);
  for (const [x, y] of [[6, 3], [7, 2], [8, 2], [9, 3], [10, 4], [5, 4], [7, 4], [8, 3], [9, 4], [8, 5]]) {
    set(TILE.FLOWER, x, y, x < 8 ? 230 : 250, x < 8 ? 70 : 200, x < 8 ? 90 : 70);
  }
  set(TILE.FLOWER, 8, 4, 250, 220, 80);

  fill(TILE.TALLGRASS, 0, 0, 0, 0);
  const blades = [5, 7, 8, 10, 12];
  for (const x of blades) {
    for (let y = 4 + (x % 3); y < 16; y++) set(TILE.TALLGRASS, x, y, 60 + (x % 3) * 12, 140, 48);
  }

  fill(TILE.DEAD_BUSH, 0, 0, 0, 0);
  for (const [x, y] of [[8, 15], [8, 14], [8, 13], [7, 12], [9, 12], [6, 10], [10, 10], [5, 8], [11, 8], [8, 11], [7, 9], [9, 7], [4, 6], [12, 6]]) {
    set(TILE.DEAD_BUSH, x, y, 128, 96, 54);
  }

  const itemFill = (tile) => fill(tile, 0, 0, 0, 0);
  const pix = (tile, list, c) => { for (const [x, y] of list) set(tile, x, y, c[0], c[1], c[2]); };
  itemFill(TILE.COAL);
  pix(TILE.COAL, [[5, 4], [6, 4], [7, 5], [8, 5], [6, 6], [7, 6], [8, 7], [9, 6], [5, 7], [6, 8], [7, 8], [8, 9], [9, 9], [10, 8], [4, 6], [10, 5]], [36, 36, 40]);
  itemFill(TILE.IRON);
  pix(TILE.IRON, [[4, 6], [5, 5], [6, 5], [7, 6], [8, 6], [9, 7], [10, 7], [11, 8], [8, 8], [7, 8], [6, 9], [5, 8], [9, 9]], [214, 214, 220]);
  itemFill(TILE.GOLD);
  pix(TILE.GOLD, [[4, 7], [5, 6], [6, 6], [7, 7], [8, 7], [9, 8], [10, 8], [7, 9], [6, 9], [8, 9], [5, 8]], [242, 204, 64]);
  itemFill(TILE.DIAMOND);
  pix(TILE.DIAMOND, [[8, 2], [7, 3], [8, 3], [9, 3], [6, 4], [7, 4], [8, 4], [9, 4], [10, 4], [5, 6], [7, 6], [8, 6], [9, 6], [11, 6], [7, 8], [8, 8], [9, 8], [8, 10], [8, 12]], [88, 236, 220]);
  itemFill(TILE.STICK);
  for (let i = 2; i < 14; i++) set(TILE.STICK, i, i, 150, 112, 64);
  for (let i = 2; i < 14; i++) set(TILE.STICK, i, i + 1 > 15 ? 15 : i + 1, 120, 86, 48);
  itemFill(TILE.APPLE);
  pix(TILE.APPLE, [[8, 3], [8, 4], [7, 5], [8, 5], [9, 5], [6, 6], [7, 6], [8, 6], [9, 6], [10, 6], [6, 7], [7, 7], [8, 7], [9, 7], [10, 7], [6, 8], [7, 8], [8, 8], [9, 8], [10, 8], [7, 9], [8, 9], [9, 9], [7, 10], [8, 10], [9, 10], [8, 11]], [196, 48, 42]);
  set(TILE.APPLE, 9, 3, 70, 130, 46);
  set(TILE.APPLE, 7, 7, 230, 180, 170);
  itemFill(TILE.RAW_MEAT);
  pix(TILE.RAW_MEAT, [[4, 6], [5, 5], [6, 5], [7, 6], [8, 6], [9, 7], [10, 7], [11, 8], [10, 9], [9, 9], [8, 8], [7, 8], [6, 9], [5, 8], [4, 7]], [196, 96, 88]);
  itemFill(TILE.COOKED);
  pix(TILE.COOKED, [[4, 6], [5, 5], [6, 5], [7, 6], [8, 6], [9, 7], [10, 7], [11, 8], [10, 9], [9, 9], [8, 8], [7, 8], [6, 9], [5, 8]], [150, 78, 48]);
  itemFill(TILE.CHARCOAL);
  pix(TILE.CHARCOAL, [[5, 4], [6, 5], [7, 5], [8, 6], [7, 7], [8, 7], [9, 8], [6, 8], [7, 9], [8, 10], [10, 6], [4, 7]], [42, 42, 46]);

  const woodC = [168, 132, 78];
  const stoneC = [128, 128, 132];
  const ironC = [216, 216, 222];
  const toolIcon = (tile, head, grip, color) => {
    itemFill(tile);
    for (const [x, y] of grip) set(tile, x, y, 146, 108, 62);
    for (const [x, y] of head) set(tile, x, y, color[0], color[1], color[2]);
  };
  const grip = [[8, 7], [9, 8], [10, 9], [11, 10], [12, 11], [13, 12]];
  const pick = [[3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [4, 5], [6, 5]];
  const axe = [[3, 3], [4, 3], [4, 4], [5, 4], [5, 5], [6, 5], [3, 4], [4, 5]];
  const shovel = [[6, 3], [7, 3], [8, 3], [7, 4], [7, 5]];
  const sword = [[6, 2], [7, 3], [8, 4], [9, 5], [7, 2], [8, 3], [9, 4]];
  const swordGrip = [[10, 8], [11, 9], [12, 10], [13, 11], [10, 7]];
  toolIcon(TILE.PICK_WOOD, pick, grip, woodC);
  toolIcon(TILE.PICK_STONE, pick, grip, stoneC);
  toolIcon(TILE.PICK_IRON, pick, grip, ironC);
  toolIcon(TILE.AXE_WOOD, axe, grip, woodC);
  toolIcon(TILE.AXE_STONE, axe, grip, stoneC);
  toolIcon(TILE.AXE_IRON, axe, grip, ironC);
  toolIcon(TILE.SHOVEL_WOOD, shovel, grip, woodC);
  toolIcon(TILE.SHOVEL_STONE, shovel, grip, stoneC);
  toolIcon(TILE.SHOVEL_IRON, shovel, grip, ironC);
  toolIcon(TILE.SWORD_WOOD, sword, swordGrip, woodC);
  toolIcon(TILE.SWORD_STONE, sword, swordGrip, stoneC);
  toolIcon(TILE.SWORD_IRON, sword, swordGrip, ironC);

  for (let stage = 0; stage < 10; stage++) {
    const tile = TILE.CRACK + stage;
    fill(tile, 0, 0, 0, 0);
    let x = 1 + (stage % 3);
    let y = 1;
    const steps = 4 + stage * 3;
    for (let i = 0; i < steps; i++) {
      set(tile, x, y, 24, 24, 28, 210);
      if (x + 1 < 16) set(tile, x + 1, y, 24, 24, 28, 120);
      const h = hash3(i, stage, 3, 8);
      const dir = h & 3;
      if (dir === 0) x = Math.min(15, x + 1);
      else if (dir === 1) x = Math.max(0, x - 1);
      else if (dir === 2) y = Math.min(15, y + 1);
      else y = Math.max(0, y - 1);
      if ((h & 7) === 0) {
        x = (x + 5) & 15;
        y = (y + 3) & 15;
      }
    }
  }

  fill(TILE.WHITE, 255, 255, 255, 255);
  ctx.putImageData(image, 0, 0);

  const water = document.createElement("canvas");
  water.width = 16;
  water.height = 16;
  const wctx = water.getContext("2d");
  const wimg = wctx.createImageData(16, 16);
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const wave = y % 5 === 1 || y % 5 === 2;
      const i = (y * 16 + x) * 4;
      wimg.data[i] = wave ? 62 : 36;
      wimg.data[i + 1] = wave ? 118 : 78;
      wimg.data[i + 2] = wave ? 214 : 186;
      wimg.data[i + 3] = 168;
    }
  }
  wctx.putImageData(wimg, 0, 0);

  const lava = document.createElement("canvas");
  lava.width = 16;
  lava.height = 16;
  const lctx = lava.getContext("2d");
  const limg = lctx.createImageData(16, 16);
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const n = hash3(x, y, 4, 70) & 7;
      const hot = n > 5;
      const i = (y * 16 + x) * 4;
      limg.data[i] = hot ? 255 : 210;
      limg.data[i + 1] = hot ? 196 : 92;
      limg.data[i + 2] = hot ? 48 : 16;
      limg.data[i + 3] = 255;
    }
  }
  lctx.putImageData(limg, 0, 0);

  const cloud = document.createElement("canvas");
  cloud.width = 64;
  cloud.height = 64;
  const cctx = cloud.getContext("2d");
  const cimg = cctx.createImageData(64, 64);
  const puff = (cx, cy, rx, ry) => {
    for (let y = 0; y < 64; y++) {
      for (let x = 0; x < 64; x++) {
        const nx = (x - cx) / rx;
        const ny = (y - cy) / ry;
        if (nx * nx + ny * ny > 1) continue;
        const i = (y * 64 + x) * 4;
        cimg.data[i] = 255;
        cimg.data[i + 1] = 255;
        cimg.data[i + 2] = 255;
        cimg.data[i + 3] = 230;
      }
    }
  };
  puff(16, 18, 12, 7);
  puff(28, 16, 10, 6);
  puff(22, 24, 8, 5);
  puff(46, 40, 14, 8);
  puff(54, 36, 8, 6);
  puff(40, 44, 9, 5);
  cctx.putImageData(cimg, 0, 0);

  const url = canvas.toDataURL();
  return {
    atlas: canvas,
    water,
    lava,
    cloud,
    url,
    cols: COLS,
    rows: ROWS,
    sample(tile, x, y) {
      const col = tile % COLS;
      const row = (tile / COLS) | 0;
      const px = col * T + (x & 15);
      const py = row * T + (y & 15);
      const i = (py * canvas.width + px) * 4;
      return [data[i], data[i + 1], data[i + 2], data[i + 3]];
    },
    iconStyle(tile) {
      const col = tile % COLS;
      const row = (tile / COLS) | 0;
      const x = COLS <= 1 ? 0 : (col / (COLS - 1)) * 100;
      const y = ROWS <= 1 ? 0 : (row / (ROWS - 1)) * 100;
      return `url("${url}") ${x}% ${y}% / ${COLS * 100}% ${ROWS * 100}% no-repeat`;
    },
  };
}
