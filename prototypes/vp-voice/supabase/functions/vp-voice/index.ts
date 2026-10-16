// 本番の supabase/functions には置いていない。デプロイしない。
import { createAuth } from "../../../relay/auth.mjs";
import { createAuthStore } from "../../../relay/auth-store.mjs";
import { handleRequest } from "../../../relay/handler.mjs";
import { createRepo } from "../../../relay/repo.mjs";
import { createSessionStore } from "../../../relay/session-store.mjs";

const root = Deno.env.get("VP_REPO_ROOT") ?? "";

const repo = createRepo(root, {
  readFile(file) {
    return Deno.readTextFile(file);
  },
  async readdir(dir) {
    const entries = [];
    for await (const ent of Deno.readDir(dir)) {
      entries.push({
        name: ent.name,
        isDirectory: () => ent.isDirectory,
        isFile: () => ent.isFile,
      });
    }
    return entries;
  },
});

const env = {
  BLOB_READ_WRITE_TOKEN: Deno.env.get("BLOB_READ_WRITE_TOKEN") ?? "",
  VERCEL: Deno.env.get("VERCEL") ?? "",
  VERCEL_ENV: Deno.env.get("VERCEL_ENV") ?? "",
  VP_AUTH_FILE: Deno.env.get("VP_AUTH_FILE") ?? "",
  VP_SESSION_DIR: Deno.env.get("VP_SESSION_DIR") ?? "",
  SETUP_TOKEN: Deno.env.get("SETUP_TOKEN") ?? "",
};

const auth = createAuth({
  setupToken: () => env.SETUP_TOKEN,
  store: createAuthStore(env),
});

Deno.serve((request) =>
  handleRequest(request, {
    apiKey: Deno.env.get("ANTHROPIC_API_KEY") ?? "",
    cursorKey: Deno.env.get("CURSOR_API_KEY") ?? "",
    anthropicBase: Deno.env.get("VP_ANTHROPIC_BASE_URL") ?? "https://api.anthropic.com",
    cursorBase: Deno.env.get("VP_CURSOR_BASE_URL") ?? "https://api.cursor.com",
    repo,
    auth,
    sessions: createSessionStore(env),
  }).then((response) => response ?? new Response("not found", { status: 404 })),
);
