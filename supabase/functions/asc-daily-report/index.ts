import { pemToPkcs8, signAppleJwt } from "./apple_jwt.ts";
import { configuredParentSkus, parentSkusToUse } from "./sku.ts";
import { authorizeStoreImport, gunzipText, json, parseTsv } from "./text.ts";
import {
  addDays,
  pacificDateString,
  planOngoingAnalyticsRequest,
  postWithBackoff,
  withBackoff,
  type AnalyticsInstance,
  type AnalyticsSummary,
  type Backoff,
  type EventSummary,
  type PlanName,
  type ReviewInput,
  type ReviewSummary,
  type StoredPost,
} from "./parse.ts";
import {
  runAscDailyReport,
  type AnalyticsBundle,
  type History,
  type ReportDeps,
  type ReviewsResponse,
} from "./report.ts";

// この入口は分析レポートの依頼を作らない。依頼の作成は承認後に別途行う。

const appleApi = "https://api.appstoreconnect.apple.com";

const backoff: Backoff = {
  initialMs: 500,
  maxAttempts: 3,
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

function hasAdminKey(): boolean {
  return Boolean(Deno.env.get("ASC_ADMIN_KEY_ID")?.trim() && Deno.env.get("ASC_ADMIN_PRIVATE_KEY")?.trim());
}

async function appleToken(kind: "admin" | "reports"): Promise<string> {
  const keyName = kind === "admin" ? "ASC_ADMIN_PRIVATE_KEY" : "ASC_REPORTS_PRIVATE_KEY";
  const idName = kind === "admin" ? "ASC_ADMIN_KEY_ID" : "ASC_REPORTS_KEY_ID";
  return await signAppleJwt({
    issuer: required("ASC_ISSUER_ID"),
    keyId: required(idName),
    pkcs8: pemToPkcs8(required(keyName).replaceAll("\\n", "\n")),
    nowSeconds: Math.floor(Date.now() / 1000),
  });
}

async function appleFetch(kind: "admin" | "reports", path: string): Promise<Response> {
  const headers = new Headers();
  headers.set("Authorization", `Bearer ${await appleToken(kind)}`);
  const url = path.startsWith("http") ? path : `${appleApi}${path}`;
  return await fetch(url, { headers });
}

async function appleFetchReady(kind: "admin" | "reports", path: string): Promise<Response> {
  return await withBackoff(() => appleFetch(kind, path), backoff);
}

function serviceHeaders(): Headers {
  const key = required("SUPABASE_SERVICE_ROLE_KEY");
  const headers = new Headers();
  headers.set("apikey", key);
  headers.set("authorization", `Bearer ${key}`);
  headers.set("content-type", "application/json");
  return headers;
}

function restBase(): string {
  return required("SUPABASE_URL").replace(/\/$/, "");
}

async function rpc(op: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${restBase()}/rest/v1/rpc/asc_daily_report_rpc`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({ p_op: op, p_body: body }),
  });
  if (!response.ok) throw new Error(`rpc ${op} ${response.status}`);
  return await response.json();
}

function asNumber(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : 0;
}

function yen(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const absolute = Math.abs(cents);
  return `${sign}${Math.trunc(absolute / 100)}.${String(absolute % 100).padStart(2, "0")}`;
}

function isGzip(bytes: Uint8Array): boolean {
  return bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b;
}

async function fetchSalesReport(
  kind: "SALES" | "SUBSCRIPTION" | "SUBSCRIPTION_EVENT",
  dataDate: string,
): Promise<{ status: number; errorBody: string; rows: Record<string, string>[] }> {
  const version = kind === "SALES" ? "1_0" : "1_3";
  const query = new URLSearchParams({
    "filter[reportType]": kind,
    "filter[reportSubType]": "SUMMARY",
    "filter[frequency]": "DAILY",
    "filter[reportDate]": dataDate,
    "filter[vendorNumber]": required("ASC_VENDOR_NUMBER"),
    "filter[version]": version,
  });
  const response = await appleFetch("reports", `/v1/salesReports?${query}`);
  if (response.status === 404) {
    return { status: 404, errorBody: await response.text(), rows: [] };
  }
  if (!response.ok) return { status: response.status, errorBody: "", rows: [] };
  const bytes = new Uint8Array(await response.arrayBuffer());
  const text = isGzip(bytes) ? await gunzipText(bytes) : new TextDecoder().decode(bytes);
  return { status: 200, errorBody: "", rows: parseTsv(text) };
}

function reviewFrom(row: Record<string, unknown>): ReviewInput | null {
  const attributes = row.attributes;
  if (!attributes || typeof attributes !== "object") return null;
  const record = attributes as Record<string, unknown>;
  const createdDate = typeof record.createdDate === "string" ? record.createdDate : "";
  const rating = asNumber(record.rating);
  if (!createdDate) return null;
  return {
    rating,
    title: typeof record.title === "string" ? record.title : "",
    body: typeof record.body === "string" ? record.body : "",
    createdDate,
  };
}

async function readReviewPages(kind: "admin" | "reports"): Promise<ReviewsResponse> {
  const cutoff = addDays(pacificDateString(new Date()), -14);
  let path = `/v1/apps/${required("ASC_APP_APPLE_ID")}/customerReviews?sort=-createdDate&limit=200`;
  const reviews: ReviewInput[] = [];
  for (let page = 0; page < 10 && path; page++) {
    const response = await appleFetch(kind, path);
    if (!response.ok) return { status: response.status, errorBody: "", reviews: [], complete: false };
    const body = await response.json();
    const data = Array.isArray(body?.data) ? body.data as Record<string, unknown>[] : [];
    const batch = data.map(reviewFrom).filter((review): review is ReviewInput => review !== null);
    reviews.push(...batch);
    const oldest = batch
      .map((review) => new Date(review.createdDate))
      .filter((instant) => !Number.isNaN(instant.getTime()))
      .map((instant) => pacificDateString(instant))
      .sort()[0];
    const next = typeof body?.links?.next === "string" ? body.links.next : "";
    if (!next || (oldest !== undefined && oldest < cutoff)) {
      return { status: 200, errorBody: "", reviews, complete: true };
    }
    path = next;
    if (page === 9) return { status: 200, errorBody: "", reviews, complete: false };
  }
  return { status: 200, errorBody: "", reviews, complete: true };
}

async function fetchReviews(): Promise<ReviewsResponse> {
  const first = await readReviewPages("reports");
  if (first.status === 403 && hasAdminKey()) return await readReviewPages("admin");
  return first;
}

type AppleResource = { id?: unknown; attributes?: Record<string, unknown> };

function resourceId(row: AppleResource): string {
  return typeof row.id === "string" ? row.id : String(row.id ?? "");
}

async function applePages(kind: "admin" | "reports", path: string): Promise<AppleResource[] | null> {
  const rows: AppleResource[] = [];
  let next = path;
  while (next) {
    const response = await appleFetchReady(kind, next);
    if (!response.ok) return null;
    const body = await response.json();
    const data = Array.isArray(body?.data) ? body.data as AppleResource[] : [];
    rows.push(...data);
    next = typeof body?.links?.next === "string" ? body.links.next : "";
  }
  return rows;
}

function reportName(row: AppleResource): string {
  const name = row.attributes?.name;
  return typeof name === "string" ? name : "";
}

function pickReport(rows: AppleResource[], kind: "discovery" | "downloads"): string {
  const matches = rows.filter((row) => {
    const name = reportName(row).toLowerCase();
    if (kind === "discovery") {
      return name.includes("discovery") && name.includes("engagement") && !name.includes("web preview");
    }
    return name.includes("download") && !name.includes("discovery");
  });
  const standard = matches.find((row) => reportName(row).toLowerCase().includes("standard"));
  return resourceId((standard ?? matches[0]) ?? {});
}

async function downloadInstance(instance: AppleResource): Promise<AnalyticsInstance | null> {
  const processingDate = typeof instance.attributes?.processingDate === "string"
    ? instance.attributes.processingDate
    : "";
  const segments = await applePages("reports", `/v1/analyticsReportInstances/${resourceId(instance)}/segments`);
  if (!segments) return null;
  const rows: Record<string, string>[] = [];
  for (const segment of segments) {
    const url = segment.attributes?.url;
    if (typeof url !== "string" || !url) continue;
    const response = await withBackoff(() => fetch(url), backoff);
    if (!response.ok) return null;
    const bytes = new Uint8Array(await response.arrayBuffer());
    const text = isGzip(bytes) ? await gunzipText(bytes) : new TextDecoder().decode(bytes);
    rows.push(...parseTsv(text));
  }
  return { processingDate, rows };
}

async function fetchAnalytics(): Promise<AnalyticsBundle> {
  const appId = required("ASC_APP_APPLE_ID");
  const requests = await applePages("reports", `/v1/apps/${appId}/analyticsReportRequests`);
  if (!requests) return { state: "error" };
  const described = requests.map((row) => ({
    id: resourceId(row),
    accessType: typeof row.attributes?.accessType === "string" ? row.attributes.accessType : "",
    stoppedDueToInactivity: row.attributes?.stoppedDueToInactivity === true,
  }));
  const plan = planOngoingAnalyticsRequest(described);
  if (plan === "create") return { state: "not_created" };
  if (plan === "stopped") return { state: "stopped" };
  const active = described.find((row) => row.accessType === "ONGOING" && !row.stoppedDueToInactivity);
  if (!active) return { state: "not_created" };
  const reports = await applePages("reports", `/v1/analyticsReportRequests/${active.id}/reports`);
  if (!reports) return { state: "error" };
  const discoveryId = pickReport(reports, "discovery");
  const downloadsId = pickReport(reports, "downloads");
  if (!discoveryId || !downloadsId) return { state: "error" };
  const cutoff = addDays(pacificDateString(new Date()), -21);
  const load = async (reportId: string): Promise<AnalyticsInstance[] | null> => {
    const instances = await applePages(
      "reports",
      `/v1/analyticsReports/${reportId}/instances?filter[granularity]=DAILY`,
    );
    if (!instances) return null;
    const loaded: AnalyticsInstance[] = [];
    for (const instance of instances) {
      const processingDate = typeof instance.attributes?.processingDate === "string"
        ? instance.attributes.processingDate
        : "";
      if (processingDate && processingDate < cutoff) continue;
      const downloaded = await downloadInstance(instance);
      if (!downloaded) return null;
      loaded.push(downloaded);
    }
    return loaded;
  };
  const discovery = await load(discoveryId);
  const downloads = await load(downloadsId);
  if (!discovery || !downloads) return { state: "error" };
  return { state: "ready", discovery, downloads };
}

function liveDeps(): ReportDeps {
  return {
    now: () => new Date(),
    appAppleId: required("ASC_APP_APPLE_ID"),
    knownParentSkus: [...configuredParentSkus],
    rememberParentSkus: async (skus, dataDate) => {
      await rpc("save_parent_skus", { skus, data_date: dataDate });
    },
    backoff,
    getPost: async (reportType, dataDate) => {
      const body = await rpc("get_post", { report_type: reportType, data_date: dataDate }) as {
        status?: string;
        attempt?: number;
        updated_at_ms?: number;
      };
      if (body.status === "none" || body.status == null) return null;
      if (body.status !== "reserved" && body.status !== "posted" && body.status !== "failed") return null;
      const post: StoredPost = {
        status: body.status,
        attempt: asNumber(body.attempt) || 1,
        updatedAtMs: asNumber(body.updated_at_ms),
      };
      return post;
    },
    claim: async (reportType, dataDate) => {
      const body = await rpc("claim", { report_type: reportType, data_date: dataDate }) as { result?: string };
      return body.result === "claimed";
    },
    finish: async (reportType, dataDate, status) => {
      await rpc("finish", { report_type: reportType, data_date: dataDate, status });
    },
    history: async (from, to) => mapHistory(await rpc("history", { from, to })),
    saveSales: async (dataDate, row) => {
      await rpc("save_sales", {
        data_date: dataDate,
        new_downloads: row.newDownloads,
        redownloads: row.redownloads,
        sales_jpy: yen(row.salesCents),
        proceeds_jpy: yen(row.proceedsCents),
        non_jpy_customer_rows: row.nonJpyCustomerRows,
      });
    },
    saveSubscription: async (dataDate, plans) => {
      await rpc("save_subscription", {
        data_date: dataDate,
        plans: plans.map((plan) => ({
          plan: plan.plan,
          active_paid: plan.activePaid,
          active_trials: plan.activeTrials,
        })),
      });
    },
    saveEvents: async (dataDate, row) => {
      await rpc("save_events", {
        data_date: dataDate,
        trial_starts: row.trialStarts,
        paid_conversions: row.paidConversions,
        cancellations: row.cancellations,
      });
    },
    saveReviews: async (dataDate, row) => {
      await rpc("save_reviews", {
        data_date: dataDate,
        review_count: row.reviewCount,
        average_rating: row.averageRating,
        star_1: row.stars[0],
        star_2: row.stars[1],
        star_3: row.stars[2],
        star_4: row.stars[3],
        star_5: row.stars[4],
        excerpt: row.excerpt,
      });
    },
    saveAnalytics: async (dataDate, row) => {
      await rpc("save_analytics", {
        data_date: dataDate,
        impressions: row.impressions,
        product_page_views: row.productPageViews,
        source_search: row.sourceSearch,
        source_other: row.sourceOther,
        downloads: row.downloads,
        conversion_rate: row.conversionRate,
        search_includes_ads: true,
      });
    },
    fetchSalesReport,
    fetchReviews,
    fetchAnalytics,
    postSlack: async (text) => {
      const url = required("SLACK_DAILY_REPORT_WEBHOOK_URL");
      return await postWithBackoff(async () => {
        const response = await fetch(url, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ text }),
        });
        return response.status;
      }, backoff);
    },
  };
}

function mapHistory(value: unknown): History {
  const body = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const list = (key: string) => Array.isArray(body[key]) ? body[key] as Record<string, unknown>[] : [];
  return {
    sales: list("sales").map((row) => ({
      dataDate: String(row.data_date).slice(0, 10),
      newDownloads: asNumber(row.new_downloads),
      redownloads: asNumber(row.redownloads),
      salesCents: Math.round(asNumber(row.sales_jpy) * 100),
      proceedsCents: Math.round(asNumber(row.proceeds_jpy) * 100),
      nonJpyCustomerRows: asNumber(row.non_jpy_customer_rows),
    })),
    subscriptions: list("subscriptions").map((row) => ({
      dataDate: String(row.data_date).slice(0, 10),
      plan: String(row.plan) as PlanName,
      activePaid: asNumber(row.active_paid),
      activeTrials: asNumber(row.active_trials),
    })),
    events: list("events").map((row): EventSummary & { dataDate: string } => ({
      dataDate: String(row.data_date).slice(0, 10),
      trialStarts: asNumber(row.trial_starts),
      paidConversions: asNumber(row.paid_conversions),
      cancellations: asNumber(row.cancellations),
    })),
    reviews: list("reviews").map((row): ReviewSummary & { dataDate: string } => ({
      dataDate: String(row.data_date).slice(0, 10),
      reviewCount: asNumber(row.review_count),
      averageRating: row.average_rating == null ? null : asNumber(row.average_rating),
      stars: [
        asNumber(row.star_1),
        asNumber(row.star_2),
        asNumber(row.star_3),
        asNumber(row.star_4),
        asNumber(row.star_5),
      ],
      excerpt: typeof row.excerpt === "string" ? row.excerpt : "",
    })),
    analytics: list("analytics").map((row): AnalyticsSummary & { dataDate: string } => ({
      dataDate: String(row.data_date).slice(0, 10),
      impressions: asNumber(row.impressions),
      productPageViews: asNumber(row.product_page_views),
      sourceSearch: asNumber(row.source_search),
      sourceOther: asNumber(row.source_other),
      downloads: asNumber(row.downloads),
      conversionRate: row.conversion_rate == null ? null : asNumber(row.conversion_rate),
      searchIncludesAds: true,
    })),
  };
}

async function loadParentSkus(): Promise<string[]> {
  const body = await rpc("list_parent_skus", {}) as { skus?: unknown };
  const stored = Array.isArray(body.skus)
    ? body.skus.filter((sku): sku is string => typeof sku === "string")
    : [];
  return parentSkusToUse(configuredParentSkus, stored);
}

Deno.serve(async (request) => {
  if (!authorizeStoreImport(request)) return json({ ok: false }, 401);
  try {
    const deps = liveDeps();
    deps.knownParentSkus = await loadParentSkus();
    const result = await runAscDailyReport(deps);
    return json({
      ok: true,
      flash_posted: result.flashPosted,
      acquisition_posted: result.acquisitionPosted,
      acquisition: result.acquisition,
    });
  } catch {
    console.error("asc-daily-report failed");
    return json({ ok: false }, 500);
  }
});
