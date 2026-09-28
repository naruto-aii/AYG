import assert from "node:assert/strict";
import test from "node:test";
import { AIR, BEDROCK, GRASS, LOG, PLANKS, STICK, STONE, TABLE, WATER } from "../js/blocks.js";
import { matchCraft } from "../js/crafting.js";
import { generateChunk, findSpawnColumn } from "../js/generator.js";
import { buildMesh } from "../js/mesher.js";
import { HEIGHT, SIZE, idx } from "../js/constants.js";

test("crafting matches planks, sticks, and a table", () => {
  const planks = matchCraft([LOG, 0, 0, 0], 2);
  assert.equal(planks.id, PLANKS);
  assert.equal(planks.count, 4);
  const sticks = matchCraft([PLANKS, 0, PLANKS, 0], 2);
  assert.equal(sticks.id, STICK);
  assert.equal(sticks.count, 4);
  const table = matchCraft([PLANKS, PLANKS, PLANKS, PLANKS], 2);
  assert.equal(table.id, TABLE);
  assert.equal(matchCraft([0, 0, 0, 0], 2), null);
});

test("a chunk has grass, dirt-depth stone, water, and bedrock", () => {
  const { blocks } = generateChunk(123456, 0, 0, []);
  const seen = new Set(blocks);
  assert.ok(seen.has(BEDROCK));
  assert.ok(seen.has(STONE));
  assert.ok(seen.has(GRASS) || seen.has(WATER));
  let solid = 0;
  for (let i = 0; i < blocks.length; i++) if (blocks[i] !== AIR) solid++;
  assert.ok(solid > SIZE * SIZE * 8);
  const again = generateChunk(123456, 0, 0, []);
  assert.deepEqual(again.blocks, blocks);
});

test("spawn stands on land above the sea", () => {
  const spawn = findSpawnColumn(123456);
  assert.equal(typeof spawn.x, "number");
  assert.ok(spawn.y > 40 && spawn.y < HEIGHT);
});

test("one stone cube emits six outward faces", () => {
  const at = { x: 2, y: 40, z: 2 };
  const mesh = buildMesh(0, 0, (x, y, z) => (x === at.x && y === at.y && z === at.z ? STONE : AIR), () => ({ sky: 15, block: 0 }), () => 0);
  assert.equal(mesh.opaque.indices.length, 36);
  const v = mesh.opaque.verts;
  const ix = mesh.opaque.indices;
  const normals = [];
  for (let i = 0; i < ix.length; i += 6) {
    const a = ix[i] * 9;
    const b = ix[i + 1] * 9;
    const c = ix[i + 2] * 9;
    const e1 = [v[b] - v[a], v[b + 1] - v[a + 1], v[b + 2] - v[a + 2]];
    const e2 = [v[c] - v[a], v[c + 1] - v[a + 1], v[c + 2] - v[a + 2]];
    const n = [
      e1[1] * e2[2] - e1[2] * e2[1],
      e1[2] * e2[0] - e1[0] * e2[2],
      e1[0] * e2[1] - e1[1] * e2[0],
    ];
    const len = Math.hypot(n[0], n[1], n[2]) || 1;
    normals.push(n.map((p) => Math.round(p / len)));
  }
  const key = (n) => n.join(",");
  const unique = [...new Set(normals.map(key))].sort();
  assert.deepEqual(unique, ["-1,0,0", "0,-1,0", "0,0,-1", "0,0,1", "0,1,0", "1,0,0"]);
  void idx;
});
