import { generateChunk } from "./generator.js";

self.onmessage = (event) => {
  const { cx, cz, seed, mods } = event.data;
  const { blocks, biomes } = generateChunk(seed, cx, cz, mods);
  self.postMessage({ cx, cz, blocks, biomes }, [blocks.buffer, biomes.buffer]);
};
