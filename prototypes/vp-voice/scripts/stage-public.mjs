import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const web = path.join(root, "web");
const out = path.join(root, "public");
fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(web, out, { recursive: true });
