export const salesSummaryVersion = "1_0";
export const subscriptionReportVersion = "1_3";

export type StoreRunStatus = "success" | "failed" | "partial" | "not_available";

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
  if (lines.length === 0) {
    return [];
  }
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

export function gunzipBytes(bytes: Uint8Array): string {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
  return new Response(stream).text() as unknown as string;
}

export async function gunzipText(bytes: Uint8Array): Promise<string> {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
  return await new Response(stream).text();
}
