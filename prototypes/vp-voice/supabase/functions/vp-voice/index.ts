// 本番の supabase/functions には置いていない。デプロイしない。
import { handleRequest } from "../../../relay/handler.mjs";
import { createRepo } from "../../../relay/repo.mjs";

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

Deno.serve((request) =>
  handleRequest(request, {
    apiKey: Deno.env.get("ANTHROPIC_API_KEY") ?? "",
    cursorKey: Deno.env.get("CURSOR_API_KEY") ?? "",
    anthropicBase: Deno.env.get("VP_ANTHROPIC_BASE_URL") ?? "https://api.anthropic.com",
    cursorBase: Deno.env.get("VP_CURSOR_BASE_URL") ?? "https://api.cursor.com",
    repo,
  }).then((response) => response ?? new Response("not found", { status: 404 })),
);
