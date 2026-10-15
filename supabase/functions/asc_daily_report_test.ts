import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { gunzipText, parseTsv } from "./_shared/store_import.ts";
import {
  aggregateEvents,
  aggregateSales,
  aggregateSubscription,
  buildAnalytics,
  claimBackoffMs,
  classifyUnavailable,
  createOngoingAnalyticsRequest,
  fillPlans,
  flashComment,
  formatHeadingDate,
  latestRowsForDate,
  nextClaim,
  oneLineExcerpt,
  ongoingAnalyticsRequestBody,
  pacificDateString,
  postWithBackoff,
  summarizeDiscovery,
  summarizeDownloads,
  summarizeReviews,
  withBackoff,
  type Backoff,
  type StoredPost,
} from "./asc-daily-report/parse.ts";
import { runAscDailyReport, type History, type ReportDeps, type ReportResponse } from "./asc-daily-report/report.ts";

const appId = "111";
const flashDate = "2026-10-16";
const nowIso = "2026-10-17T21:00:00Z";

const salesHeader = [
  "Provider",
  "Provider Country",
  "SKU",
  "Developer",
  "Title",
  "Version",
  "Product Type Identifier",
  "Units",
  "Developer Proceeds",
  "Begin Date",
  "End Date",
  "Customer Currency",
  "Country Code",
  "Currency of Proceeds",
  "Apple Identifier",
  "Customer Price",
  "Promo Code",
  "Parent Identifier",
  "Subscription",
  "Period",
  "Category",
  "CMB",
  "Device",
  "Supported Platforms",
  "Proceeds Reason",
  "Preserved Pricing",
  "Client",
  "Order Type",
].join("\t");

function salesRow(fields: Record<string, string>): string {
  const values = salesHeader.split("\t").map((header) => fields[header] ?? "");
  return values.join("\t");
}

const salesTsv = [
  salesHeader,
  salesRow({
    "Product Type Identifier": "1",
    Units: "10",
    "Developer Proceeds": "0",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": appId,
    "Customer Price": "0",
  }),
  salesRow({
    "Product Type Identifier": "3",
    Units: "4",
    "Developer Proceeds": "0",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": appId,
    "Customer Price": "0",
  }),
  salesRow({
    "Product Type Identifier": "7",
    Units: "20",
    "Developer Proceeds": "0",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": appId,
    "Customer Price": "0",
  }),
  salesRow({
    "Product Type Identifier": "1",
    Units: "100",
    "Developer Proceeds": "0",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": "999",
    "Customer Price": "0",
  }),
  salesRow({
    "Product Type Identifier": "IAY",
    Units: "2",
    "Developer Proceeds": "406",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": "555",
    "Customer Price": "580",
    "Parent Identifier": appId,
  }),
  salesRow({
    "Product Type Identifier": "IAY",
    Units: "1",
    "Developer Proceeds": "2.79",
    "Customer Currency": "USD",
    "Currency of Proceeds": "USD",
    "Apple Identifier": "555",
    "Customer Price": "3.99",
    "Parent Identifier": appId,
  }),
  salesRow({
    "Product Type Identifier": "IAY",
    Units: "-1",
    "Developer Proceeds": "406",
    "Customer Currency": "JPY",
    "Currency of Proceeds": "JPY",
    "Apple Identifier": "555",
    "Customer Price": "580",
    "Parent Identifier": appId,
  }),
].join("\n");

const subscriptionHeader = [
  "App Name",
  "App Apple ID",
  "Subscription Name",
  "Standard Subscription Duration",
  "Active Standard Price Subscriptions",
  "Active Free Trial Introductory Offer Subscriptions",
  "Active Pay Up Front Introductory Offer Subscriptions",
  "Active Pay as You Go Introductory Offer Subscriptions",
  "Free Trial Promotional Offer Subscriptions",
  "Pay Up Front Promotional Offer Subscriptions",
  "Pay As You Go Promotional Offer Subscriptions",
  "Free Trial Offer Code Subscriptions",
  "Pay Up Front Offer Code Subscriptions",
  "Pay As You Go Offer Code Subscriptions",
  "Free Trial Win-Back Offers",
  "Pay Up Front Win-Back Offers",
  "Pay As You Go Win-Back Offers",
].join("\t");

function subscriptionRow(fields: Record<string, string>): string {
  return subscriptionHeader.split("\t").map((header) => fields[header] ?? "0").join("\t");
}

const subscriptionTsv = [
  subscriptionHeader,
  subscriptionRow({
    "App Apple ID": appId,
    "Subscription Name": "月額",
    "Standard Subscription Duration": "1 Month",
    "Active Standard Price Subscriptions": "10",
    "Active Free Trial Introductory Offer Subscriptions": "3",
    "Active Pay Up Front Introductory Offer Subscriptions": "1",
  }),
  subscriptionRow({
    "App Apple ID": appId,
    "Subscription Name": "月額",
    "Standard Subscription Duration": "1 Month",
    "Active Standard Price Subscriptions": "2",
    "Active Free Trial Introductory Offer Subscriptions": "1",
  }),
  subscriptionRow({
    "App Apple ID": appId,
    "Subscription Name": "半年",
    "Standard Subscription Duration": "6 Months",
    "Active Standard Price Subscriptions": "4",
  }),
  subscriptionRow({
    "App Apple ID": appId,
    "Subscription Name": "年額",
    "Standard Subscription Duration": "1 Year",
    "Active Standard Price Subscriptions": "1",
    "Free Trial Promotional Offer Subscriptions": "2",
  }),
  subscriptionRow({
    "App Apple ID": "999",
    "Subscription Name": "他アプリ",
    "Standard Subscription Duration": "1 Month",
    "Active Standard Price Subscriptions": "50",
  }),
  subscriptionRow({
    "App Apple ID": appId,
    "Subscription Name": "7日",
    "Standard Subscription Duration": "7 Days",
    "Active Standard Price Subscriptions": "8",
    "Active Free Trial Introductory Offer Subscriptions": "1",
  }),
].join("\n");

const eventHeader = [
  "Event Date",
  "Event",
  "App Name",
  "App Apple ID",
  "Subscription Name",
  "Standard Subscription Duration",
  "Subscription Offer Type",
  "Cancellation Reason",
  "Quantity",
].join("\t");

function eventRow(fields: Record<string, string>): string {
  return eventHeader.split("\t").map((header) => fields[header] ?? "").join("\t");
}

const eventTsv = [
  eventHeader,
  eventRow({ Event: "Start Introductory Offer", "App Apple ID": appId, "Subscription Offer Type": "Free Trial", Quantity: "2" }),
  eventRow({ Event: "Start Introductory Price", "App Apple ID": appId, "Subscription Offer Type": "Free Trial", Quantity: "1" }),
  eventRow({ Event: "Start Introductory Offer", "App Apple ID": appId, "Subscription Offer Type": "Pay Up Front", Quantity: "9" }),
  eventRow({ Event: "Paid Subscription from Introductory Offer", "App Apple ID": appId, "Subscription Offer Type": "Free Trial", Quantity: "4" }),
  eventRow({ Event: "Paid Subscription from Introductory Price", "App Apple ID": appId, "Subscription Offer Type": "Free Trial", Quantity: "1" }),
  eventRow({ Event: "Upgrade From Introductory Offer", "App Apple ID": appId, "Subscription Offer Type": "Pay Up Front", Quantity: "7" }),
  eventRow({ Event: "Cancel", "App Apple ID": appId, Quantity: "3" }),
  eventRow({ Event: "Canceled from Billing Retry", "App Apple ID": appId, Quantity: "1" }),
  eventRow({ Event: "Renew", "App Apple ID": appId, Quantity: "20" }),
  eventRow({ Event: "Cancel", "App Apple ID": "999", Quantity: "8" }),
].join("\n");

const discoveryHeader = [
  "Date",
  "App Name",
  "App Apple Identifier",
  "Event",
  "Page Type",
  "Source Type",
  "Engagement Type",
  "Device",
  "Platform Version",
  "Territory",
  "Counts",
  "Unique Counts",
].join("\t");

function discoveryRow(fields: Record<string, string>): string {
  return discoveryHeader.split("\t").map((header) => fields[header] ?? "").join("\t");
}

const discoveryTsv = [
  discoveryHeader,
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": appId, Event: "Impression", "Page Type": "No page", "Source Type": "App Store search", Counts: "800", "Unique Counts": "500" }),
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": appId, Event: "Impression", "Page Type": "No page", "Source Type": "App Store browse", Counts: "300", "Unique Counts": "200" }),
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": appId, Event: "Impression", "Page Type": "No page", "Source Type": "Web referrer", Counts: "100", "Unique Counts": "80" }),
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": appId, Event: "Page view", "Page Type": "Product page", "Source Type": "App Store search", Counts: "250" }),
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": appId, Event: "Page view", "Page Type": "Store sheet", "Source Type": "App referrer", Counts: "40" }),
  discoveryRow({ Date: "2026-10-14", "App Apple Identifier": "999", Event: "Impression", "Page Type": "No page", "Source Type": "App Store search", Counts: "1000" }),
].join("\n");

const downloadHeader = [
  "Date",
  "App Name",
  "App Apple Identifier",
  "Download Type",
  "App Version",
  "Device",
  "Platform Version",
  "Source Type",
  "Page Type",
  "Pre-Order",
  "Territory",
  "Counts",
].join("\t");

function downloadRow(fields: Record<string, string>): string {
  return downloadHeader.split("\t").map((header) => fields[header] ?? "").join("\t");
}

const downloadTsv = [
  downloadHeader,
  downloadRow({ Date: "2026-10-14", "App Apple Identifier": appId, "Download Type": "First-time Download", "Source Type": "App Store search", "Page Type": "Product page", Counts: "80" }),
  downloadRow({ Date: "2026-10-14", "App Apple Identifier": appId, "Download Type": "Redownload", "Source Type": "App Store browse", "Page Type": "Product page", Counts: "20" }),
  downloadRow({ Date: "2026-10-14", "App Apple Identifier": appId, "Download Type": "Auto-update", "Source Type": "App Store browse", "Page Type": "No Page", Counts: "500" }),
  downloadRow({ Date: "2026-10-14", "App Apple Identifier": "999", "Download Type": "First-time Download", Counts: "70" }),
].join("\n");

async function gzip(text: string): Promise<Uint8Array> {
  const stream = new Blob([text]).stream().pipeThrough(new CompressionStream("gzip"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function rowsFromGzip(text: string): Promise<Record<string, string>[]> {
  return parseTsv(await gunzipText(await gzip(text)));
}

Deno.test("gzip sales TSV separates new downloads, redownloads, and JPY money", async () => {
  const summary = aggregateSales(await rowsFromGzip(salesTsv), appId);
  assertEquals(summary.newDownloads, 10);
  assertEquals(summary.redownloads, 4);
  assertEquals(summary.salesCents, 58000);
  assertEquals(summary.proceedsCents, 40600);
  assertEquals(summary.nonJpyCustomerRows, 1);
});

Deno.test("gzip subscription and event TSVs keep plans, trials, and cancellations", async () => {
  const plans = fillPlans(aggregateSubscription(await rowsFromGzip(subscriptionTsv), appId));
  assertEquals(plans.map((plan) => [plan.plan, plan.activePaid, plan.activeTrials]), [
    ["monthly", 13, 4],
    ["half_year", 4, 0],
    ["yearly", 1, 2],
    ["other", 8, 1],
  ]);
  assertEquals(aggregateEvents(await rowsFromGzip(eventTsv), appId), {
    trialStarts: 3,
    paidConversions: 5,
    cancellations: 4,
  });
});

Deno.test("gzip analytics TSV counts impressions, product pages, sources, and conversion", async () => {
  const discoveryRows = latestRowsForDate(
    [{ processingDate: "2026-10-17", rows: await rowsFromGzip(discoveryTsv) }],
    "2026-10-14",
    appId,
  ) ?? [];
  const downloadRows = latestRowsForDate(
    [{ processingDate: "2026-10-17", rows: await rowsFromGzip(downloadTsv) }],
    "2026-10-14",
    appId,
  ) ?? [];
  const discovery = summarizeDiscovery(discoveryRows);
  const downloads = summarizeDownloads(downloadRows);
  const summary = buildAnalytics(discovery, downloads);
  assertEquals(discovery, {
    impressions: 1200,
    productPageViews: 250,
    sourceSearch: 800,
    sourceOther: 400,
  });
  assertEquals(downloads, 100);
  assertEquals(summary.conversionRate, 0.0833);
  assertEquals(summary.searchIncludesAds, true);
});

Deno.test("a later analytics instance replaces the same date", () => {
  const rows = latestRowsForDate([
    { processingDate: "2026-10-15", rows: parseTsv(discoveryTsv) },
    {
      processingDate: "2026-10-16",
      rows: [discoveryRow({
        Date: "2026-10-14",
        "App Apple Identifier": appId,
        Event: "Impression",
        "Page Type": "No page",
        "Source Type": "App Store browse",
        Counts: "5",
      })].map((line) => {
        const headers = discoveryHeader.split("\t");
        const cells = line.split("\t");
        const row: Record<string, string> = {};
        headers.forEach((header, index) => {
          row[header] = cells[index] ?? "";
        });
        return row;
      }),
    },
  ], "2026-10-14", appId);
  assertEquals(rows?.length, 1);
  assertEquals(rows?.[0].Counts, "5");
});

Deno.test("reviews use the Pacific day and keep one redacted line", () => {
  const summary = summarizeReviews([
    {
      rating: 5,
      title: "",
      body: "使いやすい\n次の行",
      createdDate: "2026-10-17T06:30:00Z",
    },
    {
      rating: 4,
      title: "題",
      body: "連絡は person@example.com まで",
      createdDate: "2026-10-17T05:00:00Z",
    },
    {
      rating: 1,
      title: "",
      body: "別の日",
      createdDate: "2026-10-17T08:00:00Z",
    },
  ], flashDate);
  assertEquals(summary.reviewCount, 2);
  assertEquals(summary.averageRating, 4.5);
  assertEquals(summary.stars, [0, 0, 0, 1, 1]);
  assertEquals(summary.excerpt, "使いやすい");
  assertEquals(oneLineExcerpt("連絡は person@example.com まで", "").includes("@"), false);
  assertEquals(oneLineExcerpt("a<@U123>b", "").includes("<"), false);
  assertEquals(JSON.stringify(summary).includes("person@"), false);
});

Deno.test("unavailable reports stay missing unless Apple says there were no sales", () => {
  assertEquals(
    classifyUnavailable(404, "The report you requested is not available yet. Please try again later."),
    "missing",
  );
  assertEquals(classifyUnavailable(404, "There were no sales for the date specified."), "empty");
  assertEquals(classifyUnavailable(503, ""), "retry");
  assertEquals(classifyUnavailable(403, ""), "missing");
  assertEquals(classifyUnavailable(200, ""), "ready");
});

Deno.test("http retries use backoff and do not retry a not-ready report", async () => {
  const sleeps: number[] = [];
  const backoff: Backoff = { initialMs: 100, maxAttempts: 3, sleep: (ms) => {
    sleeps.push(ms);
    return Promise.resolve();
  } };
  let calls = 0;
  const recovered = await withBackoff(() => {
    calls += 1;
    return Promise.resolve({ status: calls < 3 ? 503 : 200 });
  }, backoff);
  assertEquals(recovered.status, 200);
  assertEquals(calls, 3);
  assertEquals(sleeps, [100, 200]);

  const blocked: number[] = [];
  let missingCalls = 0;
  const missing = await withBackoff(() => {
    missingCalls += 1;
    return Promise.resolve({ status: 404 });
  }, { ...backoff, sleep: (ms) => {
    blocked.push(ms);
    return Promise.resolve();
  } });
  assertEquals(missing.status, 404);
  assertEquals(missingCalls, 1);
  assertEquals(blocked, []);

  const slack: number[] = [];
  const posted = await postWithBackoff(() => {
    slack.push(slack.length);
    return Promise.resolve(slack.length < 2 ? 500 : 200);
  }, backoff);
  assertEquals(posted, true);
  assertEquals(slack.length, 2);
});

Deno.test("claim waits after failure and will not take a posted row", () => {
  assertEquals(claimBackoffMs(1), 30_000);
  assertEquals(claimBackoffMs(2), 60_000);
  assertEquals(nextClaim(null, 0).action, "insert");
  const failed: StoredPost = { status: "failed", attempt: 1, updatedAtMs: 0 };
  assertEquals(nextClaim(failed, 29_000).action, "skip");
  assertEquals(nextClaim(failed, 30_000), { action: "reclaim", attempt: 2 });
  assertEquals(nextClaim({ status: "posted", attempt: 1, updatedAtMs: 0 }, 999_999).action, "skip");
  assertEquals(nextClaim({ status: "reserved", attempt: 1, updatedAtMs: 0 }, 999_999).action, "skip");
});

Deno.test("ongoing request is prepared and not repeated", async () => {
  const body = ongoingAnalyticsRequestBody(appId);
  const data = body.data as { attributes: { accessType: string }; relationships: { app: { data: { id: string } } } };
  assertEquals(data.attributes.accessType, "ONGOING");
  assertEquals(data.relationships.app.data.id, appId);
  let created = 0;
  const exists = await createOngoingAnalyticsRequest({
    appAppleId: appId,
    listRequests: () => Promise.resolve([{ accessType: "ONGOING" }]),
    create: () => {
      created += 1;
      return Promise.resolve({ status: 201 });
    },
  });
  assertEquals(exists.action, "exists");
  assertEquals(created, 0);
  const made = await createOngoingAnalyticsRequest({
    appAppleId: appId,
    listRequests: () => Promise.resolve([]),
    create: () => {
      created += 1;
      return Promise.resolve({ status: 201 });
    },
  });
  assertEquals(made.action, "created");
  assertEquals(created, 1);
});

Deno.test("the scheduled entry does not create an ongoing request", async () => {
  const source = await Deno.readTextFile(new URL("./asc-daily-report/index.ts", import.meta.url));
  assertEquals(source.includes("createOngoingAnalyticsRequest"), false);
});

type Memory = {
  sales: History["sales"];
  subscriptions: History["subscriptions"];
  events: History["events"];
  reviews: History["reviews"];
  analytics: History["analytics"];
  posts: Map<string, StoredPost>;
};

function emptyHistory(): History {
  return { sales: [], subscriptions: [], events: [], reviews: [], analytics: [] };
}

function memory(): Memory {
  return { ...emptyHistory(), posts: new Map() };
}

function key(reportType: string, dataDate: string): string {
  return `${reportType}:${dataDate}`;
}

function depsFor(store: Memory, nowMs: { value: number }, slack: string[]): ReportDeps {
  const history = (): History => ({
    sales: store.sales,
    subscriptions: store.subscriptions,
    events: store.events,
    reviews: store.reviews,
    analytics: store.analytics,
  });
  return {
    now: () => new Date(nowMs.value),
    appAppleId: appId,
    backoff: { initialMs: 100, maxAttempts: 3, sleep: () => Promise.resolve() },
    getPost: (reportType, dataDate) => Promise.resolve(store.posts.get(key(reportType, dataDate)) ?? null),
    claim: (reportType, dataDate, at) => {
      const current = store.posts.get(key(reportType, dataDate)) ?? null;
      const decision = nextClaim(current, at);
      if (decision.action === "skip") return Promise.resolve(false);
      store.posts.set(key(reportType, dataDate), {
        status: "reserved",
        attempt: decision.attempt,
        updatedAtMs: at,
      });
      return Promise.resolve(true);
    },
    finish: (reportType, dataDate, status, at) => {
      const current = store.posts.get(key(reportType, dataDate));
      if (!current || current.status !== "reserved") return Promise.resolve();
      store.posts.set(key(reportType, dataDate), {
        status,
        attempt: current.attempt,
        updatedAtMs: at,
      });
      return Promise.resolve();
    },
    history: () => Promise.resolve(history()),
    saveSales: (dataDate, row) => {
      store.sales = store.sales.filter((item) => item.dataDate !== dataDate);
      store.sales.push({ dataDate, ...row });
      return Promise.resolve();
    },
    saveSubscription: (dataDate, plans) => {
      store.subscriptions = store.subscriptions.filter((item) => item.dataDate !== dataDate);
      store.subscriptions.push(...plans.map((plan) => ({ dataDate, ...plan })));
      return Promise.resolve();
    },
    saveEvents: (dataDate, row) => {
      store.events = store.events.filter((item) => item.dataDate !== dataDate);
      store.events.push({ dataDate, ...row });
      return Promise.resolve();
    },
    saveReviews: (dataDate, row) => {
      store.reviews = store.reviews.filter((item) => item.dataDate !== dataDate);
      store.reviews.push({ dataDate, ...row });
      return Promise.resolve();
    },
    saveAnalytics: (dataDate, row) => {
      store.analytics = store.analytics.filter((item) => item.dataDate !== dataDate);
      store.analytics.push({ dataDate, ...row });
      return Promise.resolve();
    },
    fetchSalesReport: (kind, dataDate) => Promise.resolve(reportFor(kind, dataDate, "ready")),
    fetchReviews: () => Promise.resolve({
      status: 200,
      errorBody: "",
      complete: true,
      reviews: [
        { rating: 5, title: "", body: "使いやすい\n次の行", createdDate: "2026-10-17T06:30:00Z" },
        { rating: 4, title: "", body: "ふつう", createdDate: "2026-10-17T05:00:00Z" },
      ],
    }),
    fetchAnalytics: () => Promise.resolve({
      state: "ready",
      discovery: [{ processingDate: "2026-10-17", rows: parseTsv(discoveryTsv) }],
      downloads: [{ processingDate: "2026-10-17", rows: parseTsv(downloadTsv) }],
    }),
    postSlack: (text) => {
      const reserved = store.posts.get(key(text.startsWith("📊") ? "flash" : "acquisition", text.startsWith("📊") ? flashDate : "2026-10-14"));
      assertEquals(reserved?.status, "reserved");
      slack.push(text);
      return Promise.resolve(true);
    },
  };
}

function reportFor(
  kind: "SALES" | "SUBSCRIPTION" | "SUBSCRIPTION_EVENT",
  dataDate: string,
  mode: "ready" | "missing" | "empty",
): ReportResponse {
  if (dataDate !== flashDate || mode === "missing") {
    return {
      status: 404,
      errorBody: "The report you requested is not available yet. Please try again later.",
      rows: [],
    };
  }
  if (mode === "empty") {
    return { status: 404, errorBody: "There were no sales for the date specified.", rows: [] };
  }
  if (kind === "SALES") return { status: 200, errorBody: "", rows: parseTsv(salesTsv) };
  if (kind === "SUBSCRIPTION") return { status: 200, errorBody: "", rows: parseTsv(subscriptionTsv) };
  return { status: 200, errorBody: "", rows: parseTsv(eventTsv) };
}

Deno.test("a complete day posts once in Japanese and a second run does not", async () => {
  const store = memory();
  store.sales.push({
    dataDate: "2026-10-15",
    newDownloads: 9,
    redownloads: 1,
    salesCents: 0,
    proceedsCents: 0,
    nonJpyCustomerRows: 0,
  });
  const slack: string[] = [];
  const clock = { value: Date.parse(nowIso) };
  const deps = depsFor(store, clock, slack);
  const first = await runAscDailyReport(deps);
  assertEquals(first.flashPosted, [flashDate]);
  assertEquals(first.acquisitionPosted, ["2026-10-14"]);
  assertEquals(slack.length, 2);
  const flash = slack[0];
  assertEquals(flash.includes("📊 カロナビ日次レポート｜10/16（金）分"), true);
  assertEquals(flash.includes("■ 獲得"), true);
  assertEquals(flash.includes("■ 課金"), true);
  assertEquals(flash.includes("■ レビュー"), true);
  assertEquals(flash.includes("■ ひとこと"), true);
  assertEquals(flash.includes("新規DL 10（前日 +1 / 今月 19）"), true);
  assertEquals(flash.includes("再DL 4（前日 +3 / 今月 5）"), true);
  assertEquals(flash.includes("売上 ¥580（前日 +¥580 / 今月 ¥580）"), true);
  assertEquals(flash.includes("手取り ¥406（前日 +¥406 / 今月 ¥406）"), true);
  assertEquals(flash.includes("月額 有効 13（前日 —） / トライアル中 4（前日 —）"), true);
  assertEquals(flash.includes("トライアル開始 3（前日 — / 今月 3）"), true);
  assertEquals(flash.includes("有料への切り替え 5（前日 — / 今月 5）"), true);
  assertEquals(flash.includes("解約 4（前日 — / 今月 4）"), true);
  assertEquals(flash.includes("本文つき 2件（前日 — / 今月 2件） / 平均 ★4.5"), true);
  assertEquals(flash.includes("「使いやすい」"), true);
  assertEquals(flash.includes("本文のない★だけの評価は API に含まれません。"), true);
  assertEquals(flash.includes("トライアル開始と、有料への切り替えが両方あります。"), true);
  assertEquals(slack[1].includes("📈 カロナビ集客｜10/14（水）分"), true);
  assertEquals(slack[1].includes("表示回数 1,200"), true);
  assertEquals(slack[1].includes("製品ページ閲覧 250"), true);
  assertEquals(slack[1].includes("検索 800（広告を含む） / 広告 検索と分かれて出ない / その他 400"), true);
  assertEquals(slack[1].includes("転換率 8.3%"), true);
  const second = await runAscDailyReport(deps);
  assertEquals(second.flashPosted, []);
  assertEquals(second.acquisitionPosted, []);
  assertEquals(slack.length, 2);
  assertEquals(store.posts.get(`flash:${flashDate}`)?.status, "posted");
});

Deno.test("a missing report does not post or reserve the day", async () => {
  const store = memory();
  const slack: string[] = [];
  const deps = depsFor(store, { value: Date.parse(nowIso) }, slack);
  deps.fetchSalesReport = (kind, dataDate) => Promise.resolve(reportFor(kind, dataDate, "missing"));
  deps.fetchAnalytics = () => Promise.resolve({ state: "not_created" });
  const result = await runAscDailyReport(deps);
  assertEquals(result.flashPosted, []);
  assertEquals(result.acquisition, "not_created");
  assertEquals(slack, []);
  assertEquals(store.posts.size, 0);
});

Deno.test("an empty sales file still posts when the other reports arrived", async () => {
  const store = memory();
  const slack: string[] = [];
  const deps = depsFor(store, { value: Date.parse(nowIso) }, slack);
  deps.fetchSalesReport = (kind, dataDate) => {
    if (kind === "SALES" && dataDate === flashDate) {
      return Promise.resolve({ status: 404, errorBody: "There were no sales for the date specified.", rows: [] });
    }
    return Promise.resolve(reportFor(kind, dataDate, "ready"));
  };
  deps.fetchAnalytics = () => Promise.resolve({ state: "not_created" });
  const result = await runAscDailyReport(deps);
  assertEquals(result.flashPosted, [flashDate]);
  assertEquals(slack[0].includes("新規DL 0（前日 — / 今月 0）"), true);
  assertEquals(slack[0].includes("大きな動きはありません。"), false);
  assertEquals(slack[0].includes("トライアル開始と、有料への切り替えが両方あります。"), true);
});

Deno.test("sales retries before the day is treated as missing", async () => {
  const store = memory();
  const slack: string[] = [];
  const sleeps: number[] = [];
  const deps = depsFor(store, { value: Date.parse(nowIso) }, slack);
  deps.backoff = {
    initialMs: 100,
    maxAttempts: 3,
    sleep: (ms) => {
      sleeps.push(ms);
      return Promise.resolve();
    },
  };
  deps.fetchAnalytics = () => Promise.resolve({ state: "not_created" });
  let salesCalls = 0;
  deps.fetchSalesReport = (kind, dataDate) => {
    if (kind === "SALES" && dataDate === flashDate) {
      salesCalls += 1;
      if (salesCalls < 3) return Promise.resolve({ status: 503, errorBody: "", rows: [] });
    }
    return Promise.resolve(reportFor(kind, dataDate, "ready"));
  };
  const result = await runAscDailyReport(deps);
  assertEquals(result.flashPosted, [flashDate]);
  assertEquals(salesCalls, 3);
  assertEquals(sleeps, [100, 200]);
});

Deno.test("a failed post is reserved first, then retried only after backoff", async () => {
  const store = memory();
  const slack: string[] = [];
  const clock = { value: Date.parse(nowIso) };
  const deps = depsFor(store, clock, slack);
  deps.fetchAnalytics = () => Promise.resolve({ state: "not_created" });
  let allow = false;
  deps.postSlack = (text) => {
    assertEquals(store.posts.get(`flash:${flashDate}`)?.status, "reserved");
    slack.push(text);
    return Promise.resolve(allow);
  };
  const failed = await runAscDailyReport(deps);
  assertEquals(failed.flashPosted, []);
  assertEquals(slack.length, 1);
  assertEquals(store.posts.get(`flash:${flashDate}`)?.status, "failed");
  clock.value += 29_000;
  await runAscDailyReport(deps);
  assertEquals(slack.length, 1);
  clock.value += 1_000;
  allow = true;
  const retried = await runAscDailyReport(deps);
  assertEquals(retried.flashPosted, [flashDate]);
  assertEquals(slack.length, 2);
  assertEquals(store.posts.get(`flash:${flashDate}`)?.status, "posted");
});

Deno.test("overlapping runs post the same day once", async () => {
  const store = memory();
  const slack: string[] = [];
  const clock = { value: Date.parse(nowIso) };
  let started = 0;
  let release = () => {};
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const deps = depsFor(store, clock, slack);
  deps.fetchAnalytics = () => Promise.resolve({ state: "not_created" });
  deps.fetchReviews = () => {
    started += 1;
    return gate.then(() => ({
      status: 200,
      errorBody: "",
      complete: true,
      reviews: [],
    }));
  };
  const first = runAscDailyReport(deps);
  const second = runAscDailyReport(deps);
  for (let i = 0; i < 500 && started < 2; i++) await Promise.resolve();
  release();
  await Promise.all([first, second]);
  assertEquals(slack.length, 1);
  assertEquals(store.posts.get(`flash:${flashDate}`)?.status, "posted");
});

Deno.test("the comment follows the numbers", () => {
  assertEquals(flashComment({
    newDownloads: 0,
    previousNewDownloads: null,
    trialStarts: 0,
    paidConversions: 0,
    cancellations: 0,
    reviewCount: 1,
    averageRating: 2,
  }), "低評価の本文つきレビューが来ています。");
  assertEquals(flashComment({
    newDownloads: 1,
    previousNewDownloads: 1,
    trialStarts: 0,
    paidConversions: 0,
    cancellations: 2,
    reviewCount: 0,
    averageRating: null,
  }), "解約が、トライアル開始と有料への切り替え以上です。");
  assertEquals(flashComment({
    newDownloads: 0,
    previousNewDownloads: 0,
    trialStarts: 0,
    paidConversions: 0,
    cancellations: 0,
    reviewCount: 0,
    averageRating: null,
  }), "大きな動きはありません。");
});

Deno.test("the report date is Apple's Pacific day", () => {
  assertEquals(pacificDateString(new Date(nowIso)), "2026-10-17");
  assertEquals(formatHeadingDate(flashDate), "10/16（金）");
});
