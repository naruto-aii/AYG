import { gunzipText, parseTsv } from "./store_import.ts";
import type { AnalyticsDeps, AnalyticsSegment } from "../store-analytics-import/import.ts";
import type { SalesDeps } from "../store-sales-import/import.ts";

const appleApi = "https://api.appstoreconnect.apple.com";

type AppleKey = "admin" | "reports";

const salesSubtype: Record<string, string> = {
  SALES: "SUMMARY",
  SUBSCRIPTION: "SUMMARY",
  SUBSCRIPTION_EVENT: "SUMMARY",
  SUBSCRIBER: "DETAILED",
};

export function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/// App Store Connect の JWT。有効期限は 20 分未満。秘密は戻り値以外に出さない。
export async function signAppleJwt(input: {
  issuer: string;
  keyId: string;
  pkcs8: ArrayBuffer;
  nowSeconds: number;
}): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    input.pkcs8,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: input.keyId, typ: "JWT" })),
  );
  const payload = base64Url(
    new TextEncoder().encode(JSON.stringify({
      iss: input.issuer,
      iat: input.nowSeconds,
      exp: input.nowSeconds + 19 * 60,
      aud: "appstoreconnect-v1",
    })),
  );
  const signed = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${base64Url(new Uint8Array(signed))}`;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`missing ${name}`);
  }
  return value;
}

async function appleToken(kind: AppleKey): Promise<string> {
  const keyName = kind === "admin" ? "ASC_ADMIN_PRIVATE_KEY" : "ASC_REPORTS_PRIVATE_KEY";
  const idName = kind === "admin" ? "ASC_ADMIN_KEY_ID" : "ASC_REPORTS_KEY_ID";
  return await signAppleJwt({
    issuer: requiredEnv("ASC_ISSUER_ID"),
    keyId: requiredEnv(idName),
    pkcs8: pemToPkcs8(requiredEnv(keyName).replaceAll("\\n", "\n")),
    nowSeconds: Math.floor(Date.now() / 1000),
  });
}

async function appleFetch(
  kind: AppleKey,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const token = await appleToken(kind);
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${token}`);
  return await fetch(path.startsWith("http") ? path : `${appleApi}${path}`, {
    ...init,
    headers,
  });
}

async function applePages(kind: AppleKey, path: string): Promise<Array<Record<string, unknown>>> {
  const rows: Array<Record<string, unknown>> = [];
  let next: string | null = path;
  while (next) {
    const response = await appleFetch(kind, next);
    if (!response.ok) {
      throw new Error(`apple ${response.status} ${path}`);
    }
    const body = await response.json();
    const data = Array.isArray(body?.data) ? body.data : [];
    rows.push(...data);
    next = typeof body?.links?.next === "string" ? body.links.next : null;
  }
  return rows;
}

function serviceHeaders(extra?: Record<string, string>): Headers {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const headers = new Headers(extra);
  headers.set("apikey", key);
  headers.set("Authorization", `Bearer ${key}`);
  return headers;
}

function restUrl(path: string): string {
  return `${requiredEnv("SUPABASE_URL").replace(/\/$/, "")}/rest/v1/${path}`;
}

async function rest(path: string, init: RequestInit = {}): Promise<Response> {
  const headers = serviceHeaders();
  new Headers(init.headers).forEach((value, key) => headers.set(key, value));
  if (!headers.has("content-type") && init.body) {
    headers.set("content-type", "application/json");
  }
  return await fetch(restUrl(path), { ...init, headers });
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export async function userExists(userId: string): Promise<boolean> {
  const response = await fetch(
    `${requiredEnv("SUPABASE_URL").replace(/\/$/, "")}/auth/v1/admin/users/${userId}`,
    { headers: serviceHeaders() },
  );
  return response.status === 200;
}

export async function notificationExists(notificationUuid: string): Promise<boolean> {
  const response = await rest(
    `store_server_notifications?notification_uuid=eq.${encodeURIComponent(notificationUuid)}&select=notification_uuid&limit=1`,
  );
  if (!response.ok) {
    throw new Error(`notification lookup ${response.status}`);
  }
  const rows = await response.json();
  return Array.isArray(rows) && rows.length > 0;
}

/// 生の app_events は 90 日で消える。照合は対応表だけを見る。
export function storeOriginalTransactionPath(originalTransactionId: string): string {
  return `store_original_transactions?original_transaction_id=eq.${encodeURIComponent(originalTransactionId)}&select=user_id&limit=1`;
}

/// 退会すると public.users.deleted_at が入る。その利用者へ対応を作り直さない。
export function accountIsClosed(deletedAt: unknown): boolean {
  return deletedAt != null;
}

export async function boundStoreUser(originalTransactionId: string): Promise<string | null> {
  const tx = originalTransactionId.trim();
  if (!tx) {
    return null;
  }
  const response = await rest(storeOriginalTransactionPath(tx));
  if (!response.ok) {
    throw new Error(`transaction lookup ${response.status}`);
  }
  const rows = await response.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  const userId = row && typeof row === "object" ? (row as { user_id?: unknown }).user_id : null;
  return typeof userId === "string" && userId.length > 0 ? userId : null;
}

export async function readPlusEntitlement(
  userId: string,
  productId: string,
): Promise<{ expiresAt: string | null; status: string } | null> {
  if (!isUuid(userId) || !productId) {
    return null;
  }
  const response = await rest(
    `calonavi_plus_entitlements?user_id=eq.${encodeURIComponent(userId)}&product_id=eq.${encodeURIComponent(productId)}&select=expires_at,status&limit=1`,
  );
  if (!response.ok) {
    throw new Error(`entitlement read ${response.status}`);
  }
  const rows = await response.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  if (!row || typeof row !== "object") {
    return null;
  }
  const expires = (row as { expires_at?: unknown }).expires_at;
  const status = (row as { status?: unknown }).status;
  return {
    expiresAt: typeof expires === "string" ? expires : null,
    status: typeof status === "string" ? status : "",
  };
}

export async function upsertPlusEntitlement(row: {
  user_id: string;
  product_id: string;
  expires_at: string | null;
  status: string;
  advertising_use: false;
}): Promise<void> {
  const response = await rest(
    "calonavi_plus_entitlements?on_conflict=user_id,product_id",
    {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify(row),
    },
  );
  if (!response.ok) {
    throw new Error(`entitlement write ${response.status}`);
  }
}

export async function rememberOriginalTransaction(
  originalTransactionId: string,
  userId: string,
  productId?: string | null,
): Promise<void> {
  const tx = originalTransactionId.trim();
  if (!tx || !isUuid(userId)) {
    return;
  }
  const response = await rest("rpc/remember_store_original_transaction", {
    method: "POST",
    body: JSON.stringify({
      p_original_transaction_id: tx,
      p_user_id: userId.toLowerCase(),
      p_product_id: productId ?? null,
    }),
  });
  if (!response.ok) {
    throw new Error(`remember transaction ${response.status}`);
  }
}

async function accountClosed(userId: string): Promise<boolean> {
  const response = await rest(
    `users?id=eq.${encodeURIComponent(userId)}&select=deleted_at&limit=1`,
  );
  if (!response.ok) {
    throw new Error(`user lookup ${response.status}`);
  }
  const rows = await response.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  return accountIsClosed(row?.deleted_at);
}

export type StoreUserChoice = {
  userId: string | null;
  deleted: boolean;
  source: "original_transaction" | "app_account_token" | "none";
};

/// 購入の対応表があるときはその利用者。無いときだけ appAccountToken を見る。
/// 対応表の利用者が退会済みなら、別のトークンへ付け替えない。
export function chooseStoreUser(input: {
  originalUserId: string | null;
  originalExists: boolean;
  originalDeleted: boolean;
  appAccountToken: string | null;
  tokenExists: boolean;
  tokenDeleted: boolean;
}): StoreUserChoice {
  if (isUuid(input.originalUserId)) {
    if (input.originalExists && !input.originalDeleted) {
      return {
        userId: input.originalUserId.toLowerCase(),
        deleted: false,
        source: "original_transaction",
      };
    }
    return { userId: null, deleted: true, source: "original_transaction" };
  }
  if (isUuid(input.appAccountToken)) {
    if (input.tokenExists && !input.tokenDeleted) {
      return {
        userId: input.appAccountToken.toLowerCase(),
        deleted: false,
        source: "app_account_token",
      };
    }
    return { userId: null, deleted: true, source: "app_account_token" };
  }
  return { userId: null, deleted: false, source: "none" };
}

export async function matchStoreUser(input: {
  appAccountToken?: string | null;
  originalTransactionId?: string | null;
  productId?: string | null;
}): Promise<{ userId: string | null; deleted: boolean }> {
  const token = input.appAccountToken ?? null;
  const original = input.originalTransactionId?.trim() ?? "";
  let originalUserId: string | null = null;
  if (original) {
    const response = await rest(storeOriginalTransactionPath(original));
    if (!response.ok) {
      throw new Error(`transaction lookup ${response.status}`);
    }
    const rows = await response.json();
    const mapped = Array.isArray(rows) ? rows[0]?.user_id : null;
    originalUserId = isUuid(mapped) ? mapped : null;
  }
  const originalExists = originalUserId != null && await userExists(originalUserId);
  const originalDeleted = originalUserId != null &&
    (!originalExists || await accountClosed(originalUserId));
  const tokenIsUser = isUuid(token);
  const tokenExists = tokenIsUser && originalUserId == null && await userExists(token);
  const tokenDeleted = tokenIsUser && originalUserId == null &&
    (!tokenExists || await accountClosed(token));
  const choice = chooseStoreUser({
    originalUserId,
    originalExists,
    originalDeleted,
    appAccountToken: originalUserId == null ? token : null,
    tokenExists,
    tokenDeleted,
  });
  if (choice.userId) {
    await rememberOriginalTransaction(original, choice.userId, input.productId);
  }
  return { userId: choice.userId, deleted: choice.deleted };
}

export async function insertNotification(row: Record<string, unknown>): Promise<void> {
  const body = { ...row };
  if (!isUuid(body.app_account_token)) {
    body.app_account_token = null;
  }
  if (!isUuid(body.user_id)) {
    body.user_id = null;
  }
  const response = await rest("store_server_notifications", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`notification insert ${response.status}`);
  }
}

export async function insertFailedNotification(signedPayload: string): Promise<void> {
  const response = await rest("store_server_notifications", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      notification_uuid: crypto.randomUUID(),
      notification_type: "UNVERIFIED",
      verification_status: "failed",
      signed_payload: signedPayload,
    }),
  });
  if (!response.ok) {
    throw new Error(`failed notification insert ${response.status}`);
  }
}

function runStatus(status: string): string {
  return status === "success" ? "succeeded" : status;
}

async function startRun(job: string): Promise<string> {
  const response = await rest("store_import_runs", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ job, status: "running" }),
  });
  if (!response.ok) {
    throw new Error(`start run ${response.status}`);
  }
  const rows = await response.json();
  const runId = rows?.[0]?.run_id;
  if (typeof runId !== "string") {
    throw new Error("start run missing id");
  }
  return runId;
}

async function finishRun(
  runId: string,
  status: string,
  detail: string | undefined,
  rowsImported: number,
): Promise<void> {
  const response = await rest(`store_import_runs?run_id=eq.${runId}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      status: runStatus(status),
      finished_at: new Date().toISOString(),
      rows_imported: rowsImported,
      detail: detail ? { message: detail } : {},
    }),
  });
  if (!response.ok) {
    throw new Error(`finish run ${response.status}`);
  }
}

type SegmentMeta = {
  id: string;
  instanceId: string;
  reportId: string;
  reportName: string;
  reportCategory: string;
  granularity: string;
  processingDate: string;
  checksum: string;
  sizeBytes: number | null;
};

export function analyticsDeps(): AnalyticsDeps {
  const meta = new Map<string, SegmentMeta>();
  const reportMeta = new Map<string, { name: string; category: string }>();
  const instanceMeta = new Map<string, { reportId: string; granularity: string; processingDate: string }>();
  let current: SegmentMeta | null = null;
  let rowCursor = 0;
  let inserted = 0;
  return {
    now: () => Date.now(),
    budgetMs: 100_000,
    listRequests: async () => {
      const appId = requiredEnv("ASC_APP_APPLE_ID");
      const rows = await applePages("reports", `/v1/apps/${appId}/analyticsReportRequests`);
      return rows.map((row) => ({
        id: String(row.id),
        stoppedDueToInactivity: Boolean(
          (row.attributes as { stoppedDueToInactivity?: boolean } | undefined)?.stoppedDueToInactivity,
        ),
      }));
    },
    listReports: async (requestId) => {
      const rows = await applePages("reports", `/v1/analyticsReportRequests/${requestId}/reports`);
      return rows.map((row) => {
        const attributes = row.attributes as { name?: string; category?: string } | undefined;
        reportMeta.set(String(row.id), {
          name: attributes?.name ?? "unknown",
          category: attributes?.category ?? "unknown",
        });
        return { id: String(row.id) };
      });
    },
    listInstances: async (reportId, granularity) => {
      const rows = await applePages(
        "reports",
        `/v1/analyticsReports/${reportId}/instances?filter[granularity]=${granularity}`,
      );
      return rows.map((row) => {
        const attributes = row.attributes as { granularity?: string; processingDate?: string } | undefined;
        instanceMeta.set(String(row.id), {
          reportId,
          granularity: attributes?.granularity ?? granularity,
          processingDate: attributes?.processingDate ?? "1970-01-01",
        });
        return { id: String(row.id) };
      });
    },
    listSegments: async (instanceId) => {
      const rows = await applePages("reports", `/v1/analyticsReportInstances/${instanceId}/segments`);
      const instance = instanceMeta.get(instanceId);
      const report = reportMeta.get(instance?.reportId ?? "");
      return rows.map((row) => {
        const attributes = row.attributes as {
          url?: string;
          checksum?: string;
          sizeInBytes?: number;
        } | undefined;
        const segment: AnalyticsSegment = {
          id: String(row.id),
          url: attributes?.url ?? "",
          checksum: attributes?.checksum ?? String(row.id),
        };
        meta.set(segment.id, {
          id: segment.id,
          instanceId,
          reportId: instance?.reportId ?? "",
          reportName: report?.name ?? "unknown",
          reportCategory: report?.category ?? "unknown",
          granularity: instance?.granularity ?? "DAILY",
          processingDate: instance?.processingDate ?? "1970-01-01",
          checksum: segment.checksum,
          sizeBytes: attributes?.sizeInBytes ?? null,
        });
        return segment;
      });
    },
    alreadyImported: async (checksum) => {
      const response = await rest(
        `store_analytics_segments?checksum=eq.${encodeURIComponent(checksum)}&status=eq.imported&select=segment_id&limit=1`,
      );
      if (!response.ok) {
        throw new Error(`segment lookup ${response.status}`);
      }
      const rows = await response.json();
      return Array.isArray(rows) && rows.length > 0;
    },
    download: async (segment) => {
      current = meta.get(segment.id) ?? null;
      rowCursor = 0;
      const response = await fetch(segment.url);
      if (!response.ok) {
        throw new Error(`segment download ${response.status}`);
      }
      const bytes = new Uint8Array(await response.arrayBuffer());
      const text = bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b
        ? await gunzipText(bytes)
        : new TextDecoder().decode(bytes);
      return parseTsv(text);
    },
    insertRows: async (rows) => {
      const segment = current;
      if (!segment) {
        throw new Error("missing segment");
      }
      await upsertSegment(segment, "pending", rows.length);
      const body = rows.map((data, index) => ({
        segment_id: segment.id,
        row_number: rowCursor + index,
        report_name: segment.reportName,
        granularity: segment.granularity,
        row_date: data.Date || data["Processing Date"] || null,
        data,
      }));
      rowCursor += rows.length;
      inserted += rows.length;
      if (body.length === 0) {
        return;
      }
      const response = await rest("store_analytics_rows", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(body),
      });
      if (!response.ok) {
        throw new Error(`analytics rows ${response.status}`);
      }
    },
    markImported: async (segment) => {
      const stored = meta.get(segment.id);
      if (!stored) {
        throw new Error("missing segment meta");
      }
      await upsertSegment(stored, "imported", null);
    },
    startRun: () => startRun("analytics"),
    finishRun: (runId, status, detail) => finishRun(runId, status, detail, inserted),
  };
}

async function upsertSegment(segment: SegmentMeta, status: string, rowCount: number | null): Promise<void> {
  const response = await rest("store_analytics_segments", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({
      segment_id: segment.id,
      instance_id: segment.instanceId,
      report_id: segment.reportId,
      report_name: segment.reportName,
      report_category: segment.reportCategory,
      granularity: segment.granularity,
      processing_date: segment.processingDate,
      checksum: segment.checksum,
      size_bytes: segment.sizeBytes,
      row_count: rowCount,
      status,
      imported_at: status === "imported" ? new Date().toISOString() : null,
    }),
  });
  if (!response.ok) {
    throw new Error(`segment upsert ${response.status}`);
  }
}

export function recentReportDates(now = new Date()): string[] {
  const dates: string[] = [];
  for (let ago = 1; ago <= 14; ago++) {
    const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - ago));
    dates.push(day.toISOString().slice(0, 10));
  }
  return dates;
}

export function analyticsRequestBody(appAppleId: string): Record<string, unknown> {
  return {
    data: {
      type: "analyticsReportRequests",
      attributes: { accessType: "ONGOING" },
      relationships: {
        app: { data: { type: "apps", id: appAppleId } },
      },
    },
  };
}

export async function setupOngoingAnalytics(): Promise<{ created: boolean; requestId: string }> {
  const appAppleId = requiredEnv("ASC_APP_APPLE_ID");
  const existing = await applePages("admin", `/v1/apps/${appAppleId}/analyticsReportRequests`);
  const ongoing = existing.find((row) => {
    const attributes = row.attributes as { accessType?: string } | undefined;
    return attributes?.accessType === "ONGOING";
  });
  let requestId = ongoing ? String(ongoing.id) : "";
  let created = false;
  if (!requestId) {
    const response = await appleFetch("admin", "/v1/analyticsReportRequests", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(analyticsRequestBody(appAppleId)),
    });
    if (!response.ok) {
      throw new Error(`analytics request ${response.status}`);
    }
    const body = await response.json();
    requestId = String(body?.data?.id ?? "");
    created = true;
  }
  if (!requestId) {
    throw new Error("analytics request missing id");
  }
  const saved = await rest("store_analytics_report_requests", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({
      request_id: requestId,
      app_apple_id: appAppleId,
      access_type: "ONGOING",
      stopped_due_to_inactivity: false,
      last_checked_at: new Date().toISOString(),
    }),
  });
  if (!saved.ok) {
    throw new Error(`request record ${saved.status}`);
  }
  return { created, requestId };
}

type SalesFileState = {
  reportType: string;
  reportSubType: string;
  frequency: string;
  reportDate: string;
  version: string;
};

export function salesDeps(): SalesDeps {
  let current: SalesFileState | null = null;
  let rowCursor = 0;
  return {
    dates: () => recentReportDates(),
    fetchReport: async (file) => {
      const subtype = salesSubtype[file.reportType] ?? "SUMMARY";
      current = {
        reportType: file.reportType,
        reportSubType: subtype,
        frequency: file.frequency,
        reportDate: file.reportDate,
        version: file.version,
      };
      rowCursor = 0;
      const vendor = requiredEnv("ASC_VENDOR_NUMBER");
      const query = new URLSearchParams({
        "filter[reportType]": file.reportType,
        "filter[reportSubType]": subtype,
        "filter[frequency]": file.frequency,
        "filter[reportDate]": file.reportDate,
        "filter[vendorNumber]": vendor,
        "filter[version]": file.version,
      });
      const response = await appleFetch("reports", `/v1/salesReports?${query}`);
      if (response.status === 404) {
        return { status: 404, rows: [] };
      }
      if (!response.ok) {
        return { status: response.status, rows: [] };
      }
      const bytes = new Uint8Array(await response.arrayBuffer());
      const text = bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b
        ? await gunzipText(bytes)
        : new TextDecoder().decode(bytes);
      return { status: response.status, rows: parseTsv(text) };
    },
    alreadyImported: async (key) => {
      const file = salesFileFromKey(key);
      const response = await rest(
        `store_sales_report_files?report_type=eq.${file.reportType}&report_sub_type=eq.${file.reportSubType}&frequency=eq.${file.frequency}&report_date=eq.${file.reportDate}&version=eq.${file.version}&status=eq.imported&select=report_type&limit=1`,
      );
      if (!response.ok) {
        throw new Error(`sales lookup ${response.status}`);
      }
      const rows = await response.json();
      return Array.isArray(rows) && rows.length > 0;
    },
    mark: async (key, status) => {
      const file = salesFileFromKey(key);
      await upsertSalesFile(file, status, null);
    },
    insertRows: async (rows) => {
      const file = current;
      if (!file) {
        throw new Error("missing sales file");
      }
      await upsertSalesFile(file, "pending", rows.length);
      if (rows.length === 0) {
        return;
      }
      const body = rows.map((data, index) => ({
        report_type: file.reportType,
        report_sub_type: file.reportSubType,
        frequency: file.frequency,
        report_date: file.reportDate,
        version: file.version,
        row_number: rowCursor + index,
        data,
      }));
      rowCursor += rows.length;
      const response = await rest("store_sales_rows", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(body),
      });
      if (!response.ok) {
        throw new Error(`sales rows ${response.status}`);
      }
    },
  };
}

function salesFileFromKey(key: string): SalesFileState {
  const [reportType, frequency, reportDate, version] = key.split(":");
  return {
    reportType,
    reportSubType: salesSubtype[reportType] ?? "SUMMARY",
    frequency,
    reportDate,
    version,
  };
}

async function upsertSalesFile(
  file: SalesFileState,
  status: string,
  rowCount: number | null,
): Promise<void> {
  const response = await rest("store_sales_report_files", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({
      report_type: file.reportType,
      report_sub_type: file.reportSubType,
      frequency: file.frequency,
      report_date: file.reportDate,
      version: file.version,
      status,
      row_count: rowCount,
      imported_at: status === "imported" ? new Date().toISOString() : null,
    }),
  });
  if (!response.ok) {
    throw new Error(`sales file ${response.status}`);
  }
}
