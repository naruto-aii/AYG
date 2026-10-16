import fs from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import fsSync from "node:fs";
import { createAuth } from "./auth.mjs";
import { createAuthStore } from "./auth-store.mjs";
import { handleRequest } from "./handler.mjs";
import { createRepo } from "./repo.mjs";
import { createSessionStore } from "./session-store.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const prototypeRoot = path.resolve(here, "..");
const webRoot = path.join(prototypeRoot, "web");
const repoRoot = path.resolve(prototypeRoot, "../..");

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

export function nodeRepo(root = repoRoot) {
  return createRepo(root, {
    async readFile(file) {
      return fs.readFile(file, "utf8");
    },
    async readdir(dir) {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      return entries.map((ent) => ({
        name: ent.name,
        isDirectory: () => ent.isDirectory(),
        isFile: () => ent.isFile(),
      }));
    },
  });
}

async function toWeb(req, host) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value == null) continue;
    headers.set(key, Array.isArray(value) ? value.join(", ") : value);
  }
  return new Request(`http://${host}${req.url}`, {
    method: req.method,
    headers,
    body: body.length ? body : undefined,
  });
}

async function writeWeb(nodeRes, webRes) {
  const headers = {};
  webRes.headers.forEach((value, key) => {
    headers[key] = value;
  });
  nodeRes.writeHead(webRes.status, headers);
  if (!webRes.body) {
    nodeRes.end();
    return;
  }
  const reader = webRes.body.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!nodeRes.write(value)) {
      await new Promise((resolve) => nodeRes.once("drain", resolve));
    }
  }
  nodeRes.end();
}

async function serveStatic(req, res) {
  const url = new URL(req.url || "/", "http://127.0.0.1");
  const requested = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
  const file = path.normalize(path.join(webRoot, requested));
  if (!file.startsWith(webRoot)) {
    res.writeHead(403);
    res.end();
    return;
  }
  try {
    const data = await fs.readFile(file);
    const ext = path.extname(file);
    res.writeHead(200, { "content-type": TYPES[ext] || "application/octet-stream" });
    res.end(data);
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("not found");
  }
}

export function detectRepoRoot() {
  if (fsSync.existsSync(path.join(repoRoot, "pubspec.yaml"))) return repoRoot;
  return prototypeRoot;
}

export function createRuntime(env = process.env) {
  return {
    apiKey: env.ANTHROPIC_API_KEY ?? "",
    cursorKey: env.CURSOR_API_KEY ?? "",
    anthropicBase: env.VP_ANTHROPIC_BASE_URL ?? "https://api.anthropic.com",
    cursorBase: env.VP_CURSOR_BASE_URL ?? "https://api.cursor.com",
    repo: nodeRepo(env.VP_REPO_ROOT || detectRepoRoot()),
    auth: createAuth({
      setupToken: () => String(env.SETUP_TOKEN ?? ""),
      store: createAuthStore(env),
    }),
    sessions: createSessionStore(env),
  };
}

export function createApp(options = {}) {
  const deps = {
    apiKey: options.apiKey ?? process.env.ANTHROPIC_API_KEY ?? "",
    cursorKey: options.cursorKey ?? process.env.CURSOR_API_KEY ?? "",
    anthropicBase: options.anthropicBase ?? process.env.VP_ANTHROPIC_BASE_URL ?? "https://api.anthropic.com",
    cursorBase: options.cursorBase ?? process.env.VP_CURSOR_BASE_URL ?? "https://api.cursor.com",
    repo: options.repo ?? nodeRepo(options.repoRoot ?? repoRoot),
    auth: options.auth === false ? null : options.auth ?? null,
    sessions: options.sessions === false ? null : options.sessions ?? null,
  };
  return http.createServer(async (req, res) => {
    try {
      const host = req.headers.host || "127.0.0.1";
      const webReq = await toWeb(req, host);
      const handled = await handleRequest(webReq, deps);
      if (handled) {
        await writeWeb(res, handled);
        return;
      }
      if (req.method === "GET" || req.method === "HEAD") {
        await serveStatic(req, res);
        return;
      }
      res.writeHead(404, { "content-type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ message: "not found" }));
    } catch (error) {
      console.error("vp-voice", error?.name || "error");
      if (!res.headersSent) {
        res.writeHead(500, { "content-type": "application/json; charset=utf-8" });
      }
      res.end(JSON.stringify({ message: "中継で失敗しました" }));
    }
  });
}

export function startServer(options = {}) {
  const server = createApp(options);
  const port = options.port ?? Number(process.env.VP_PORT || 8787);
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        server,
        url: `http://127.0.0.1:${address.port}`,
      });
    });
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const runtime = createRuntime();
  runtime.repo.warm().catch(() => {});
  startServer(runtime).then(({ url }) => {
    console.log(`VP音声通話 ${url}`);
  });
}
