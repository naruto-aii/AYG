const SKIP_DIR = new Set([
  ".git",
  "node_modules",
  "build",
  ".dart_tool",
  "Pods",
  "DerivedData",
  ".gradle",
  "vendor",
]);

const TEXT_EXT = new Set([
  ".dart",
  ".md",
  ".ts",
  ".js",
  ".mjs",
  ".swift",
  ".html",
  ".yaml",
  ".yml",
  ".css",
  ".sql",
  ".txt",
  ".toml",
]);

const DENY_BASE = new Set([
  ".env",
  "dart_defines.local.json",
  "GoogleService-Info.plist",
  "google-services.json",
]);

export function isDenied(rel) {
  const norm = String(rel || "").replaceAll("\\", "/").replace(/^\/+/, "");
  if (!norm || norm.split("/").includes("..")) return true;
  const parts = norm.split("/");
  if (parts.some((part) => part === ".git" || part === "node_modules")) return true;
  const base = parts.at(-1) || "";
  if (base === ".env" || base.startsWith(".env.")) return true;
  if (DENY_BASE.has(base)) return true;
  if (/\.(pem|p8|key|jks|keystore)$/i.test(base)) return true;
  if (/credentials|service[_-]?role|secret/i.test(base)) return true;
  return false;
}

export function redact(text) {
  return String(text)
    .replace(/sk-ant-[A-Za-z0-9_-]{8,}/g, "[redacted]")
    .replace(/-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----/g, "[redacted]")
    .replace(
      /(api[_-]?key|secret|private[_-]?key|password|token|service_role)\s*[:=]\s*["']?[^\s"']+/gi,
      "$1=[redacted]",
    );
}

function extname(name) {
  const index = name.lastIndexOf(".");
  return index >= 0 ? name.slice(index).toLowerCase() : "";
}

export function createRepo(root, io) {
  let index = null;

  async function walk(abs, rel) {
    let entries = [];
    try {
      entries = await io.readdir(abs);
    } catch {
      return;
    }
    for (const ent of entries) {
      if (index.length >= 900) return;
      const name = ent.name;
      const childRel = rel ? `${rel}/${name}` : name;
      if (isDenied(childRel) || childRel.startsWith("docs/lingo")) continue;
      if (ent.isDirectory()) {
        if (SKIP_DIR.has(name)) continue;
        await walk(`${abs}/${name}`, childRel);
        continue;
      }
      if (!ent.isFile() || !TEXT_EXT.has(extname(name))) continue;
      let text = "";
      try {
        text = await io.readFile(`${abs}/${name}`);
      } catch {
        continue;
      }
      if (!text || text.includes("\u0000") || text.length > 200_000) continue;
      index.push({ path: childRel, excerpt: redact(text.slice(0, 1800)) });
    }
  }

  async function build() {
    if (index) return index;
    index = [];
    if (root) await walk(root.replace(/\/+$/, ""), "");
    return index;
  }

  return {
    warm() {
      return build();
    },
    async search(query) {
      const items = await build();
      const q = String(query || "").trim().toLowerCase();
      if (!q) return "query か path が必要。";
      const scored = [];
      for (const item of items) {
        const hay = `${item.path}\n${item.excerpt}`.toLowerCase();
        let score = 0;
        if (item.path.toLowerCase().includes(q)) score += 6;
        if (hay.includes(q)) score += 4;
        for (const part of q.split(/\s+/)) {
          if (part.length >= 2 && hay.includes(part)) score += 1;
        }
        if (score > 0) scored.push({ score, item });
      }
      scored.sort((a, b) => b.score - a.score);
      const top = scored.slice(0, 3);
      if (!top.length) return "一致するファイルは見つからない。";
      return top
        .map(({ item }) => `## ${item.path}\n${item.excerpt.slice(0, 900)}`)
        .join("\n\n")
        .slice(0, 2800);
    },
    async read(rel) {
      const norm = String(rel || "").replaceAll("\\", "/").replace(/^\/+/, "");
      if (!root || isDenied(norm)) return "このパスは秘密か対象外なので読まない。";
      let text = "";
      try {
        text = await io.readFile(`${root.replace(/\/+$/, "")}/${norm}`);
      } catch {
        return "そのファイルは見つからない。";
      }
      if (text.includes("\u0000")) return "テキストではないので読まない。";
      return `## ${norm}\n${redact(text.slice(0, 1200))}`;
    },
  };
}

export function lookupRepo(repo, input) {
  const path = String(input?.path || "").trim();
  const query = String(input?.query || "").trim();
  if (path) return repo.read(path);
  if (query) return repo.search(query);
  return Promise.resolve("query か path が必要。");
}
