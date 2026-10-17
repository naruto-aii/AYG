import { pemToPkcs8, signAppleJwt } from "./apple_jwt.ts";
import { authorizeDailyReportRead, authorizeStoreImport, gunzipText, json, parseTsv } from "./text.ts";
import {
  addDays,
  japanDateString,
  pacificDateString,
  planOngoingAnalyticsRequest,
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
import { preferStandardReport, type AppActivity, type ReportKind } from "./metrics.ts";
import {
  runAscDailyReport,
  type AnalyticsBundle,
  type ExtraHistory,
  type History,
  type ReportDeps,
  type ReviewsResponse,
  type UsageRow,
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
  return await callRpc("asc_daily_report_rpc", op, body);
}

async function ingest(op: string, body: unknown): Promise<unknown> {
  return await callRpc("daily_report_ingest_rpc", op, body);
}

async function callRpc(name: string, op: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${restBase()}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({ p_op: op, p_body: body }),
  });
  if (!response.ok) throw new Error(`rpc ${name} ${op} ${response.status}`);
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
  const cutoff = addDays(japanDateString(new Date()), -14);
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
      .map((instant) => japanDateString(instant))
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

function pickReport(rows: AppleResource[], kind: ReportKind): string {
  const picked = preferStandardReport(
    rows.map((row) => ({ name: reportName(row), row })),
    kind,
  );
  return picked ? resourceId(picked.row) : "";
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
  const installsId = pickReport(reports, "installs");
  const sessionsId = pickReport(reports, "sessions");
  const crashesId = pickReport(reports, "crashes");
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
  const installs = installsId ? await load(installsId) : null;
  const sessions = sessionsId ? await load(sessionsId) : null;
  const crashes = crashesId ? await load(crashesId) : null;
  if ((installsId && !installs) || (sessionsId && !sessions) || (crashesId && !crashes)) {
    return { state: "error" };
  }
  return { state: "ready", discovery, downloads, installs, sessions, crashes };
}

function liveDeps(): ReportDeps {
  return {
    now: () => new Date(),
    appAppleId: required("ASC_APP_APPLE_ID"),
    knownParentSkus: [],
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
    claim: async (reportType, dataDate, _nowMs, revise) => {
      const body = await rpc("claim", {
        report_type: reportType,
        data_date: dataDate,
        ...(revise ? { revise: true } : {}),
      }) as { result?: string };
      return body.result === "claimed";
    },
    log: (line) => console.log(line),
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
    getDelivery: async (dataDate) => {
      const body = await ingest("get_delivery", { data_date: dataDate }) as {
        status?: string;
        attempt?: number;
        updated_at_ms?: number;
        content_hash?: string | null;
      };
      if (body.status === "none" || body.status == null) return null;
      if (body.status !== "reserved" && body.status !== "posted" && body.status !== "failed") return null;
      return {
        status: body.status,
        attempt: asNumber(body.attempt) || 1,
        updatedAtMs: asNumber(body.updated_at_ms),
        contentHash: typeof body.content_hash === "string" ? body.content_hash : null,
      };
    },
    claimDelivery: async (dataDate, contentHash, revise) => {
      const body = await ingest("claim", {
        data_date: dataDate,
        content_hash: contentHash,
        ...(revise ? { revise: true } : {}),
      }) as { result?: string };
      return body.result === "claimed";
    },
    saveUsage: async (dataDate, row) => {
      await ingest("save_usage", usageBody(dataDate, row));
    },
    saveAppActivity: async (dataDate, startIso, endIso, row) => {
      await ingest("save_app_activity", {
        data_date: dataDate,
        window_start: startIso,
        window_end: endIso,
        ...activityBody(row),
      });
    },
    saveSnapshot: async (row) => {
      await ingest("save_snapshot", {
        data_date: row.dataDate,
        heading: row.heading,
        slack_text: row.slackText,
        payload: row.payload,
        content_hash: row.contentHash,
        publishable: row.publishable,
      });
    },
    appActivity: async (startIso, endIso) => {
      const body = await ingest("app_activity", { start: startIso, end: endIso });
      return activityFrom(body);
    },
    appActivityWindows: async (windows) => {
      const body = await ingest("app_activity_windows", { windows });
      const rows = Array.isArray(body) ? body : [];
      return rows.map((row) => {
        const record = row && typeof row === "object" ? row as Record<string, unknown> : {};
        return { reportDate: String(record.report_date ?? ""), ...activityFrom(record) };
      });
    },
    historyExtra: async (from, to) => mapExtra(await ingest("history_extra", { from, to })),
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

function usageBody(dataDate: string, row: UsageRow): Record<string, unknown> {
  return {
    data_date: dataDate,
    installs: row.installs,
    uninstalls: row.uninstalls,
    installs_state: row.installsState,
    sessions: row.sessions,
    session_duration_seconds: row.sessionDurationSeconds,
    unique_devices: row.uniqueDevices,
    sessions_state: row.sessionsState,
    crash_count: row.crashCount,
    crashes_by_version: row.crashesByVersion,
    crashes_by_device: row.crashesByDevice,
    crashes_state: row.crashesState,
  };
}

function activityBody(row: AppActivity): Record<string, unknown> {
  return {
    first_opens: row.firstOpens,
    first_opens_asa: row.firstOpensAsa,
    first_opens_other: row.firstOpensOther,
    first_opens_unknown: row.firstOpensUnknown,
    registrations: row.registrations,
    onboarding_completes: row.onboardingCompletes,
    first_meals: row.firstMeals,
    paywall_openers: row.paywallOpeners,
    trial_starts: row.trialStarts,
    sessions: row.sessions,
    session_duration_seconds: row.sessionDurationSeconds,
    searches: row.searches,
    search_users: row.searchUsers,
    siri_uses: row.siriUses,
    siri_users: row.siriUsers,
    widget_uses: row.widgetUses,
    widget_users: row.widgetUsers,
  };
}

function activityFrom(value: unknown): AppActivity {
  const row = value && typeof value === "object" ? value as Record<string, unknown> : {};
  return {
    firstOpens: asNumber(row.first_opens),
    firstOpensAsa: asNumber(row.first_opens_asa),
    firstOpensOther: asNumber(row.first_opens_other),
    firstOpensUnknown: asNumber(row.first_opens_unknown),
    registrations: asNumber(row.registrations),
    onboardingCompletes: asNumber(row.onboarding_completes),
    firstMeals: asNumber(row.first_meals),
    paywallOpeners: asNumber(row.paywall_openers),
    trialStarts: asNumber(row.trial_starts),
    sessions: asNumber(row.sessions),
    sessionDurationSeconds: asNumber(row.session_duration_seconds),
    searches: asNumber(row.searches),
    searchUsers: asNumber(row.search_users),
    siriUses: asNumber(row.siri_uses),
    siriUsers: asNumber(row.siri_users),
    widgetUses: asNumber(row.widget_uses),
    widgetUsers: asNumber(row.widget_users),
  };
}

function mapExtra(value: unknown): ExtraHistory {
  const body = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const list = (key: string) => Array.isArray(body[key]) ? body[key] as Record<string, unknown>[] : [];
  const state = (raw: unknown): UsageRow["installsState"] =>
    raw === "present" || raw === "absent" || raw === "pending" ? raw : "pending";
  const lines = (raw: unknown) =>
    Array.isArray(raw)
      ? raw.flatMap((item) => {
        if (!item || typeof item !== "object") return [];
        const row = item as Record<string, unknown>;
        return [{ key: String(row.key ?? ""), crashes: asNumber(row.crashes) }];
      })
      : null;
  return {
    usage: list("usage").map((row) => ({
      dataDate: String(row.data_date).slice(0, 10),
      installs: row.installs == null ? null : asNumber(row.installs),
      uninstalls: row.uninstalls == null ? null : asNumber(row.uninstalls),
      installsState: state(row.installs_state),
      sessions: row.sessions == null ? null : asNumber(row.sessions),
      sessionDurationSeconds: row.session_duration_seconds == null ? null : asNumber(row.session_duration_seconds),
      uniqueDevices: row.unique_devices == null ? null : asNumber(row.unique_devices),
      sessionsState: state(row.sessions_state),
      crashCount: row.crash_count == null ? null : asNumber(row.crash_count),
      crashesByVersion: lines(row.crashes_by_version),
      crashesByDevice: lines(row.crashes_by_device),
      crashesState: state(row.crashes_state),
    })),
    activity: list("activity").map((row) => ({
      dataDate: String(row.data_date).slice(0, 10),
      ...activityFrom(row),
    })),
  };
}

function storedParentSkus(value: unknown): string[] {
  const skus: string[] = [];
  if (!Array.isArray(value)) return skus;
  for (const item of value) {
    if (typeof item !== "string") continue;
    const trimmed = item.trim();
    if (trimmed && !skus.includes(trimmed)) skus.push(trimmed);
  }
  return skus;
}

async function loadParentSkus(): Promise<string[]> {
  const body = await rpc("list_parent_skus", {}) as { skus?: unknown };
  return storedParentSkus(body.skus);
}

async function readJsonBody(request: Request): Promise<Record<string, unknown>> {
  const text = await request.text();
  if (!text.trim()) return {};
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === "object" ? parsed as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

Deno.serve(async (request) => {
  const body = await readJsonBody(request);
  if (body.op === "outbox" || body.op === "finish") {
    if (!authorizeDailyReportRead(request)) return json({ ok: false }, 401);
    try {
      if (body.op === "outbox") {
        const listed = await ingest("outbox", {});
        const rows = listed && typeof listed === "object" && Array.isArray((listed as { rows?: unknown }).rows)
          ? (listed as { rows: unknown[] }).rows
          : [];
        return json({ ok: true, rows });
      }
      const dataDate = typeof body.data_date === "string" ? body.data_date : "";
      const status = body.status === "posted" || body.status === "failed" ? body.status : "";
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dataDate) || status === "") return json({ ok: false }, 400);
      const finished = await ingest("finish", { data_date: dataDate, status });
      const ok = Boolean(finished && typeof finished === "object" && (finished as { ok?: unknown }).ok === true);
      return json({ ok });
    } catch {
      console.error("asc-daily-report read failed");
      return json({ ok: false }, 500);
    }
  }
  if (!authorizeStoreImport(request)) return json({ ok: false }, 401);
  try {
    const deps = liveDeps();
    deps.knownParentSkus = await loadParentSkus();
    const result = await runAscDailyReport(deps);
    return json({
      ok: true,
      prepared: result.prepared,
      acquisition: result.acquisition,
    });
  } catch {
    console.error("asc-daily-report failed");
    return json({ ok: false }, 500);
  }
});
