// 呼び出し確認。store_import.ts は読まない。
// 既存の STORE_IMPORT_SECRET を x-store-import-secret と突き合わせる。

export function authorizeStoreImport(request: Request): boolean {
  const header = request.headers.get("x-store-import-secret") ?? "";
  const secret = Deno.env.get("STORE_IMPORT_SECRET") ?? "";
  if (header.length < 32 || secret.length < 32 || header.length !== secret.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < header.length; i++) {
    mismatch |= header.charCodeAt(i) ^ secret.charCodeAt(i);
  }
  return mismatch === 0;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
