import crypto from "node:crypto";
import { promisify } from "node:util";

const scrypt = promisify(crypto.scrypt);

const SCRYPT = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const KEYLEN = 32;
const COOKIE = "vp_session";

export const AUTH_LIMITS = {
  maxFailures: 5,
  lockMs: 15 * 60 * 1000,
  sessionMs: 14 * 24 * 60 * 60 * 1000,
  passwordMin: 8,
  passwordMax: 200,
};

function b64url(bytes) {
  return Buffer.from(bytes).toString("base64url");
}

export async function hashSecret(secret) {
  const salt = crypto.randomBytes(16);
  const hash = await scrypt(String(secret), salt, KEYLEN, SCRYPT);
  return {
    salt: b64url(salt),
    hash: b64url(hash),
    N: SCRYPT.N,
    r: SCRYPT.r,
    p: SCRYPT.p,
  };
}

export async function verifySecret(secret, stored) {
  if (!stored || typeof stored.hash !== "string" || typeof stored.salt !== "string") return false;
  let salt;
  let expected;
  try {
    salt = Buffer.from(stored.salt, "base64url");
    expected = Buffer.from(stored.hash, "base64url");
  } catch {
    return false;
  }
  if (salt.length < 8 || expected.length < 16) return false;
  const actual = Buffer.from(
    await scrypt(String(secret), salt, expected.length, {
      N: stored.N || SCRYPT.N,
      r: stored.r || SCRYPT.r,
      p: stored.p || SCRYPT.p,
      maxmem: SCRYPT.maxmem,
    }),
  );
  if (actual.length !== expected.length) return false;
  return crypto.timingSafeEqual(actual, expected);
}

function tokenEqual(left, right) {
  const a = crypto.createHash("sha256").update(String(left)).digest();
  const b = crypto.createHash("sha256").update(String(right)).digest();
  return crypto.timingSafeEqual(a, b);
}

function emptyRecord() {
  return {
    version: 1,
    password: null,
    setupToken: null,
    sessionKey: null,
    failures: 0,
    lockedUntil: 0,
  };
}

function normalize(record) {
  const base = emptyRecord();
  if (!record || typeof record !== "object") return base;
  return {
    ...base,
    ...record,
    version: 1,
    failures: Number.isFinite(record.failures) ? record.failures : 0,
    lockedUntil: Number.isFinite(record.lockedUntil) ? record.lockedUntil : 0,
  };
}

function cookieValue(header, name) {
  const parts = String(header || "").split(";");
  for (const part of parts) {
    const index = part.indexOf("=");
    if (index < 0) continue;
    if (part.slice(0, index).trim() === name) return part.slice(index + 1).trim();
  }
  return "";
}

function sign(sessionKey, exp) {
  const body = Buffer.from(JSON.stringify({ exp })).toString("base64url");
  const sig = crypto.createHmac("sha256", Buffer.from(sessionKey, "base64url")).update(body).digest("base64url");
  return `${body}.${sig}`;
}

function readSession(cookie, sessionKey, now) {
  if (!sessionKey || !cookie) return false;
  const [body, sig] = String(cookie).split(".");
  if (!body || !sig) return false;
  const expected = crypto.createHmac("sha256", Buffer.from(sessionKey, "base64url")).update(body).digest("base64url");
  const left = Buffer.from(sig);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !crypto.timingSafeEqual(left, right)) return false;
  try {
    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
    return Number(payload.exp) > now;
  } catch {
    return false;
  }
}

function json(body, status, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...extraHeaders,
    },
  });
}

function setCookie(request, value, maxAge) {
  const secure = new URL(request.url).protocol === "https:" || request.headers.get("x-forwarded-proto") === "https";
  const parts = [
    `${COOKIE}=${value}`,
    "HttpOnly",
    "Path=/",
    "SameSite=Lax",
    `Max-Age=${maxAge}`,
  ];
  if (secure) parts.push("Secure");
  return parts.join("; ");
}

export function createAuth(options) {
  const store = options.store;
  const now = options.now || (() => Date.now());
  const limits = { ...AUTH_LIMITS, ...options.limits };
  const setupToken = () => {
    const value = typeof options.setupToken === "function" ? options.setupToken() : options.setupToken;
    return String(value || "");
  };

  let chain = Promise.resolve();
  function exclusive(task) {
    const run = chain.then(task, task);
    chain = run.then(
      () => {},
      () => {},
    );
    return run;
  }

  async function load() {
    const loaded = await store.read();
    return { record: normalize(loaded?.record), etag: loaded?.etag ?? null };
  }

  async function save(record, etag) {
    return store.write(record, etag);
  }

  function lockState(record, time) {
    if (record.lockedUntil > time) {
      return { locked: true, retryAfterSec: Math.ceil((record.lockedUntil - time) / 1000) };
    }
    return { locked: false, retryAfterSec: 0 };
  }

  async function mode(record) {
    const token = setupToken();
    if (!record.password) return { mode: token ? "setup" : "unconfigured", reset: false };
    if (!token) return { mode: "login", reset: false };
    const same = await verifySecret(token, record.setupToken);
    return same ? { mode: "login", reset: false } : { mode: "setup", reset: true };
  }

  async function fail(record, etag, time) {
    const next = { ...record, failures: record.failures + 1 };
    if (next.failures >= limits.maxFailures) {
      next.failures = 0;
      next.lockedUntil = time + limits.lockMs;
    }
    await save(next, etag);
    const locked = lockState(next, time);
    if (locked.locked) {
      return json({ message: "間違えた回数が多いので、しばらくロックしています。", retryAfterSec: locked.retryAfterSec }, 429);
    }
    const left = limits.maxFailures - next.failures;
    return json({ message: `違います。あと${left}回でロックします。` }, 401);
  }

  async function openSession(request, record, etag) {
    const sessionKey = b64url(crypto.randomBytes(32));
    const next = { ...record, sessionKey, failures: 0, lockedUntil: 0 };
    await save(next, etag);
    const exp = now() + limits.sessionMs;
    return json(
      { ok: true },
      200,
      { "set-cookie": setCookie(request, sign(sessionKey, exp), Math.floor(limits.sessionMs / 1000)) },
    );
  }

  return {
    async handle(request) {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/api/auth/status") return this.status(request);
      if (request.method === "POST" && url.pathname === "/api/auth/setup") return this.setup(request);
      if (request.method === "POST" && url.pathname === "/api/auth/login") return this.login(request);
      if (request.method === "POST" && url.pathname === "/api/auth/logout") return this.logout(request);
      if (!url.pathname.startsWith("/api/")) return null;
      if (await this.authed(request)) return null;
      return json({ message: "パスワードが必要です" }, 401);
    },

    async authed(request) {
      const { record } = await load();
      return readSession(cookieValue(request.headers.get("cookie"), COOKIE), record.sessionKey, now());
    },

    async status(request) {
      const time = now();
      const { record } = await load();
      const gate = await mode(record);
      const locked = lockState(record, time);
      return json({
        ...gate,
        ...locked,
        authed: readSession(cookieValue(request.headers.get("cookie"), COOKIE), record.sessionKey, time),
      });
    },

    setup(request) {
      return exclusive(async () => {
        const time = now();
        const { record, etag } = await load();
        const locked = lockState(record, time);
        if (locked.locked) {
          return json({ message: "間違えた回数が多いので、しばらくロックしています。", retryAfterSec: locked.retryAfterSec }, 429);
        }
        const gate = await mode(record);
        if (gate.mode !== "setup") {
          const message = gate.mode === "unconfigured"
            ? "サーバーに SETUP_TOKEN がありません。"
            : "パスワードは設定済みです。変えるときは SETUP_TOKEN を入れ替えてから、もう一度設定してください。";
          return json({ message }, gate.mode === "unconfigured" ? 503 : 403);
        }
        let body;
        try {
          body = await request.json();
        } catch {
          return json({ message: "送信を読めません" }, 400);
        }
        const token = String(body?.token || "");
        const password = String(body?.password || "");
        if (!tokenEqual(token, setupToken())) {
          return fail(record, etag, time);
        }
        if (password.length < limits.passwordMin || password.length > limits.passwordMax) {
          return json({ message: `パスワードは${limits.passwordMin}文字以上にしてください。` }, 400);
        }
        const next = {
          ...emptyRecord(),
          password: await hashSecret(password),
          setupToken: await hashSecret(setupToken()),
        };
        return openSession(request, next, etag);
      });
    },

    login(request) {
      return exclusive(async () => {
        const time = now();
        const { record, etag } = await load();
        const locked = lockState(record, time);
        if (locked.locked) {
          return json({ message: "間違えた回数が多いので、しばらくロックしています。", retryAfterSec: locked.retryAfterSec }, 429);
        }
        if (!record.password) return json({ message: "まだパスワードがありません。" }, 409);
        let body;
        try {
          body = await request.json();
        } catch {
          return json({ message: "送信を読めません" }, 400);
        }
        const password = String(body?.password || "");
        if (!(await verifySecret(password, record.password))) return fail(record, etag, time);
        return openSession(request, record, etag);
      });
    },

    logout() {
      return json({ ok: true }, 200, { "set-cookie": `${COOKIE}=; HttpOnly; Path=/; SameSite=Lax; Max-Age=0` });
    },
  };
}
