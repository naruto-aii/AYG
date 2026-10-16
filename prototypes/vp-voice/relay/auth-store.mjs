import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const PATHNAME = "vp-voice/auth.json";
const API = "https://vercel.com/api/blob";

function storeIdFromToken(token) {
  return String(token || "").split("_")[3] || "";
}

async function readBody(response) {
  const text = await response.text();
  if (!text) return null;
  return JSON.parse(text);
}

export function createFileStore(file) {
  let revision = "";
  return {
    async read() {
      try {
        const text = await fs.readFile(file, "utf8");
        revision = crypto.createHash("sha256").update(text).digest("hex");
        return { record: JSON.parse(text), etag: revision };
      } catch (error) {
        if (error?.code === "ENOENT") return { record: null, etag: null };
        throw error;
      }
    },
    async write(record, etag) {
      if (etag && revision && etag !== revision) {
        const error = new Error("conflict");
        error.code = "CONFLICT";
        throw error;
      }
      await fs.mkdir(path.dirname(file), { recursive: true });
      const text = JSON.stringify(record);
      const tmp = `${file}.${process.pid}.tmp`;
      await fs.writeFile(tmp, text);
      await fs.rename(tmp, file);
      revision = crypto.createHash("sha256").update(text).digest("hex");
      return { etag: revision };
    },
  };
}

export function canUseLocalFile(env) {
  return !(env.VERCEL && env.VERCEL_ENV !== "development");
}

export function createBlobStore(token, fetchImpl = globalThis.fetch, pathname = PATHNAME) {
  const storeId = storeIdFromToken(token);
  if (!storeId) throw new Error("BLOB_READ_WRITE_TOKEN からストアを判別できません");
  const blobUrl = `https://${storeId}.private.blob.vercel-storage.com/${pathname}`;

  async function read() {
    const response = await fetchImpl(`${blobUrl}?cache=0`, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (response.status === 404) return { record: null, etag: null };
    if (!response.ok) throw new Error(`パスワードの読み取りに失敗しました (${response.status})`);
    return { record: await readBody(response), etag: response.headers.get("etag") };
  }

  async function write(record, etag) {
    const headers = {
      authorization: `Bearer ${token}`,
      "x-api-version": "12",
      "x-vercel-blob-access": "private",
      "x-content-type": "application/json",
      "x-allow-overwrite": "1",
      "x-add-random-suffix": "0",
      "x-cache-control-max-age": "60",
    };
    if (etag) headers["x-if-match"] = etag;
    const response = await fetchImpl(`${API}/?pathname=${encodeURIComponent(pathname)}`, {
      method: "PUT",
      headers,
      body: JSON.stringify(record),
    });
    if (response.status === 409 || response.status === 412) {
      const error = new Error("conflict");
      error.code = "CONFLICT";
      throw error;
    }
    if (!response.ok) throw new Error(`パスワードの保存に失敗しました (${response.status})`);
    const saved = await readBody(response);
    return { etag: saved?.etag || response.headers.get("etag") };
  }

  return {
    async read() {
      return read();
    },
    async write(record, etag) {
      try {
        return await write(record, etag);
      } catch (error) {
        if (error?.code !== "CONFLICT") throw error;
        const latest = await read();
        return write(record, latest.etag);
      }
    },
  };
}

export function createFailingStore(message) {
  const fail = async () => {
    throw new Error(message);
  };
  return { read: fail, write: fail };
}

export function createAuthStore(env = process.env, fetchImpl = globalThis.fetch) {
  if (env.BLOB_READ_WRITE_TOKEN) return createBlobStore(env.BLOB_READ_WRITE_TOKEN, fetchImpl);
  if (!canUseLocalFile(env)) {
    return createFailingStore("BLOB_READ_WRITE_TOKEN がありません。パスワードを残す場所がありません。");
  }
  const file = env.VP_AUTH_FILE || path.resolve(path.dirname(new URL(import.meta.url).pathname), "../data/auth.json");
  return createFileStore(file);
}
