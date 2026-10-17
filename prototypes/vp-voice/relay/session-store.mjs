import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { canUseLocalFile, createBlobStore, createFailingStore } from "./auth-store.mjs";

const SAFE_ID = /^[A-Za-z0-9-]{8,80}$/;

function assertId(id) {
  if (!SAFE_ID.test(String(id || ""))) throw new Error("sessionId が不正です");
}

export function createFileSessionStore(dir) {
  return {
    async read(id) {
      assertId(id);
      try {
        const text = await fs.readFile(path.join(dir, `${id}.json`), "utf8");
        return JSON.parse(text);
      } catch (error) {
        if (error?.code === "ENOENT") return null;
        throw error;
      }
    },
    async write(id, record) {
      assertId(id);
      await fs.mkdir(dir, { recursive: true });
      const file = path.join(dir, `${id}.json`);
      const tmp = `${file}.${process.pid}.tmp`;
      await fs.writeFile(tmp, JSON.stringify(record));
      await fs.rename(tmp, file);
    },
  };
}

export function createSessionStore(env = process.env, fetchImpl = globalThis.fetch) {
  if (env.BLOB_READ_WRITE_TOKEN) {
    return {
      async read(id) {
        assertId(id);
        const store = createBlobStore(env.BLOB_READ_WRITE_TOKEN, fetchImpl, `vp-voice/sessions/${id}.json`);
        const loaded = await store.read();
        return loaded.record;
      },
      async write(id, record) {
        assertId(id);
        const store = createBlobStore(env.BLOB_READ_WRITE_TOKEN, fetchImpl, `vp-voice/sessions/${id}.json`);
        await store.write(record, null);
      },
    };
  }
  if (!canUseLocalFile(env)) {
    return createFailingStore("BLOB_READ_WRITE_TOKEN がありません。打ち合わせの状態を残す場所がありません。");
  }
  const dir = env.VP_SESSION_DIR
    || path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../data/sessions");
  return createFileSessionStore(dir);
}
