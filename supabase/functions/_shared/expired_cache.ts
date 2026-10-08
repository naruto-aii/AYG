// 期限切れの推定キャッシュを、呼び出しのたびに少しだけ消す。
// 1回で表全体は消さない。

export const expiredCacheDeleteLimit = 20;

export type ExpiredCacheTable = "ai_food_estimate_cache" | "cook_coach_cache";

export function expiredCacheListQuery(table: ExpiredCacheTable, now: Date): string {
  const select = table === "cook_coach_cache" ? "cache_key" : "user_id,query_key";
  return `${table}?expires_at=lt.${encodeURIComponent(now.toISOString())}` +
    `&select=${select}&order=expires_at.asc&limit=${expiredCacheDeleteLimit}`;
}

export function expiredCacheDeleteQuery(
  table: ExpiredCacheTable,
  row: { user_id?: unknown; query_key?: unknown; cache_key?: unknown },
): string | null {
  if (table === "cook_coach_cache") {
    const key = typeof row.cache_key === "string" ? row.cache_key : "";
    if (!/^[0-9a-f]{64}$/.test(key)) {
      return null;
    }
    return `${table}?cache_key=eq.${key}`;
  }
  const userId = typeof row.user_id === "string" ? row.user_id : "";
  const queryKey = typeof row.query_key === "string" ? row.query_key : "";
  if (!/^[0-9a-f-]{36}$/i.test(userId) || queryKey.length < 1 || queryKey.length > 80) {
    return null;
  }
  return `${table}?user_id=eq.${encodeURIComponent(userId)}` +
    `&query_key=eq.${encodeURIComponent(queryKey)}`;
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export async function purgeExpiredCache(input: {
  base: string;
  serviceKey: string;
  fetchImpl: FetchLike;
  table: ExpiredCacheTable;
  now: Date;
}): Promise<number> {
  const base = input.base.replace(/\/$/, "");
  if (!base || !input.serviceKey) {
    return 0;
  }
  const headers = {
    apikey: input.serviceKey,
    Authorization: `Bearer ${input.serviceKey}`,
  };
  const listed = await input.fetchImpl(
    `${base}/rest/v1/${expiredCacheListQuery(input.table, input.now)}`,
    { headers },
  );
  if (!listed.ok) {
    return 0;
  }
  const body = await listed.json();
  const rows = Array.isArray(body) ? body.slice(0, expiredCacheDeleteLimit) : [];
  let deleted = 0;
  for (const row of rows) {
    if (row == null || typeof row !== "object") {
      continue;
    }
    const query = expiredCacheDeleteQuery(input.table, row as {
      user_id?: unknown;
      query_key?: unknown;
      cache_key?: unknown;
    });
    if (!query) {
      continue;
    }
    const removed = await input.fetchImpl(`${base}/rest/v1/${query}`, {
      method: "DELETE",
      headers,
    });
    if (removed.ok) {
      deleted += 1;
    }
  }
  return deleted;
}
