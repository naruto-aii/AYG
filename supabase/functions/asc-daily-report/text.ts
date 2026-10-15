// この関数が使う TSV と gzip と呼び出し確認。
// 共有の store_import.ts は Deno 2.9 の型検査で Blob に Uint8Array を渡せない。
// 既存ファイルは変えず、ここへ必要な部分だけを写す。gzip の中身は ArrayBuffer にして渡す。

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

export function parseTsv(text: string): Record<string, string>[] {
  const lines = text.replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.length > 0);
  if (lines.length === 0) return [];
  const headers = lines[0].split("\t");
  return lines.slice(1).map((line) => {
    const cells = line.split("\t");
    const row: Record<string, string> = {};
    headers.forEach((header, index) => {
      row[header] = cells[index] ?? "";
    });
    return row;
  });
}

export async function gunzipText(bytes: Uint8Array): Promise<string> {
  const copy = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(copy).set(bytes);
  const stream = new Blob([copy]).stream().pipeThrough(new DecompressionStream("gzip"));
  return await new Response(stream).text();
}
