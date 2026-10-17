import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const routes = [
  "api/health.mjs",
  "api/chat.mjs",
  "api/minutes.mjs",
  "api/auth/status.mjs",
  "api/auth/setup.mjs",
  "api/auth/login.mjs",
  "api/auth/logout.mjs",
  "api/cursor/draft.mjs",
  "api/cursor/launch.mjs",
];

const source = (depth) => `import { dispatch } from "${"../".repeat(depth)}relay/http.mjs";

export const maxDuration = 120;

export function GET(request) {
  return dispatch(request);
}

export function POST(request) {
  return dispatch(request);
}

export function OPTIONS(request) {
  return dispatch(request);
}
`;

for (const route of routes) {
  const file = path.join(root, route);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const depth = route.split("/").length - 1;
  fs.writeFileSync(file, source(depth));
}
