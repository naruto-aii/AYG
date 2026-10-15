import {
  addDays,
  aggregateEvents,
  aggregateSales,
  observedParentSkus,
  aggregateSubscription,
  buildAnalytics,
  candidateAcquisitionDates,
  candidateFlashDates,
  classifyUnavailable,
  fillPlans,
  formatAcquisitionMessage,
  formatFlashMessage,
  latestRowsForDate,
  monthStart,
  nextClaim,
  summarizeDiscovery,
  summarizeDownloads,
  summarizeReviews,
  withBackoff,
  type AnalyticsInstance,
  type AnalyticsSummary,
  type Backoff,
  type EventSummary,
  type PlanSummary,
  type ReviewInput,
  type ReviewSummary,
  type SalesSummary,
  type StoredPost,
} from "./parse.ts";

export type History = {
  sales: Array<SalesSummary & { dataDate: string }>;
  subscriptions: Array<PlanSummary & { dataDate: string }>;
  events: Array<EventSummary & { dataDate: string }>;
  reviews: Array<ReviewSummary & { dataDate: string }>;
  analytics: Array<AnalyticsSummary & { dataDate: string }>;
};

export type ReportResponse = {
  status: number;
  errorBody: string;
  rows: Record<string, string>[];
};

export type ReviewsResponse = {
  status: number;
  errorBody: string;
  reviews: ReviewInput[];
  complete: boolean;
};

export type AnalyticsBundle =
  | { state: "not_created" }
  | { state: "stopped" }
  | { state: "error" }
  | { state: "ready"; discovery: AnalyticsInstance[]; downloads: AnalyticsInstance[] };

export type ReportDeps = {
  now: () => Date;
  appAppleId: string;
  getPost: (reportType: "flash" | "acquisition", dataDate: string) => Promise<StoredPost | null>;
  claim: (reportType: "flash" | "acquisition", dataDate: string, nowMs: number) => Promise<boolean>;
  finish: (
    reportType: "flash" | "acquisition",
    dataDate: string,
    status: "posted" | "failed",
    nowMs: number,
  ) => Promise<void>;
  history: (from: string, to: string) => Promise<History>;
  saveSales: (dataDate: string, row: SalesSummary) => Promise<void>;
  saveSubscription: (dataDate: string, plans: PlanSummary[]) => Promise<void>;
  saveEvents: (dataDate: string, row: EventSummary) => Promise<void>;
  saveReviews: (dataDate: string, row: ReviewSummary) => Promise<void>;
  saveAnalytics: (dataDate: string, row: AnalyticsSummary) => Promise<void>;
  fetchSalesReport: (
    kind: "SALES" | "SUBSCRIPTION" | "SUBSCRIPTION_EVENT",
    dataDate: string,
  ) => Promise<ReportResponse>;
  fetchReviews: () => Promise<ReviewsResponse>;
  fetchAnalytics: () => Promise<AnalyticsBundle>;
  postSlack: (text: string) => Promise<boolean>;
  knownParentSkus: readonly string[];
  rememberParentSkus: (skus: string[], dataDate: string) => Promise<void>;
  backoff: Backoff;
};

export type RunResult = {
  flashPosted: string[];
  acquisitionPosted: string[];
  acquisition: AnalyticsBundle["state"];
};

type ReportKind = "SALES" | "SUBSCRIPTION" | "SUBSCRIPTION_EVENT";

async function fetchReady(
  deps: ReportDeps,
  kind: ReportKind,
  dataDate: string,
): Promise<{ state: "ready" | "empty" | "missing"; rows: Record<string, string>[] }> {
  const response = await withBackoff(
    () => deps.fetchSalesReport(kind, dataDate),
    deps.backoff,
  );
  const state = classifyUnavailable(response.status, response.errorBody);
  if (state === "ready") return { state, rows: response.rows };
  if (state === "empty") return { state, rows: [] };
  return { state: "missing", rows: [] };
}

function historyStart(dataDate: string): string {
  const previous = addDays(dataDate, -1);
  const start = monthStart(dataDate);
  return previous < start ? previous : start;
}

function previousSales(history: History, dataDate: string): SalesSummary | null {
  return history.sales.find((row) => row.dataDate === addDays(dataDate, -1)) ?? null;
}

function monthSales(history: History, dataDate: string, today: SalesSummary): SalesSummary {
  const start = monthStart(dataDate);
  const prior = history.sales.filter((row) => row.dataDate >= start && row.dataDate < dataDate);
  return {
    newDownloads: sum(prior, (row) => row.newDownloads) + today.newDownloads,
    redownloads: sum(prior, (row) => row.redownloads) + today.redownloads,
    salesCents: sum(prior, (row) => row.salesCents) + today.salesCents,
    proceedsCents: sum(prior, (row) => row.proceedsCents) + today.proceedsCents,
    nonJpyCustomerRows: sum(prior, (row) => row.nonJpyCustomerRows) + today.nonJpyCustomerRows,
  };
}

function monthEvents(history: History, dataDate: string, today: EventSummary): EventSummary {
  const start = monthStart(dataDate);
  const prior = history.events.filter((row) => row.dataDate >= start && row.dataDate < dataDate);
  return {
    trialStarts: sum(prior, (row) => row.trialStarts) + today.trialStarts,
    paidConversions: sum(prior, (row) => row.paidConversions) + today.paidConversions,
    cancellations: sum(prior, (row) => row.cancellations) + today.cancellations,
  };
}

function sum<T>(rows: T[], pick: (row: T) => number): number {
  return rows.reduce((total, row) => total + pick(row), 0);
}

async function finishReliably(
  deps: ReportDeps,
  reportType: "flash" | "acquisition",
  dataDate: string,
  status: "posted" | "failed",
): Promise<boolean> {
  // Slack 成功のあとに完了更新が一度失敗すると、予約期限のあと二重投稿になる。
  // 成功時は失敗時より多くやり直す。成功した投稿を failed には戻さない。
  const attempts = status === "posted" ? 5 : 3;
  let wait = deps.backoff.initialMs;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      await deps.finish(reportType, dataDate, status, deps.now().getTime());
      return true;
    } catch {
      if (attempt === attempts - 1) return false;
      await deps.backoff.sleep(wait);
      wait *= 2;
    }
  }
  return false;
}

async function publish(
  deps: ReportDeps,
  reportType: "flash" | "acquisition",
  dataDate: string,
  text: string,
  nowMs: number,
): Promise<"posted" | "failed" | "skip"> {
  const claimed = await deps.claim(reportType, dataDate, nowMs);
  if (!claimed) return "skip";
  let status: "posted" | "failed" = "failed";
  try {
    if (await deps.postSlack(text)) status = "posted";
  } catch {
    status = "failed";
  }
  const finished = await finishReliably(deps, reportType, dataDate, status);
  if (!finished) return "failed";
  return status;
}

export async function runAscDailyReport(deps: ReportDeps): Promise<RunResult> {
  const now = deps.now();
  const nowMs = now.getTime();
  const flashPosted: string[] = [];
  let reviewsPromise: Promise<ReviewsResponse> | null = null;
  const reviews = () => {
    reviewsPromise ??= withBackoff(() => deps.fetchReviews(), deps.backoff);
    return reviewsPromise;
  };

  for (const dataDate of candidateFlashDates(now)) {
    const existing = await deps.getPost("flash", dataDate);
    if (nextClaim(existing, nowMs).action === "skip") continue;
    try {
      const sales = await fetchReady(deps, "SALES", dataDate);
      const subscription = await fetchReady(deps, "SUBSCRIPTION", dataDate);
      const events = await fetchReady(deps, "SUBSCRIPTION_EVENT", dataDate);
      const reviewResponse = await reviews();
      const reviewsReady = reviewResponse.status >= 200 &&
        reviewResponse.status < 300 &&
        reviewResponse.complete;
      if (
        sales.state === "missing" ||
        subscription.state === "missing" ||
        events.state === "missing" ||
        !reviewsReady
      ) {
        continue;
      }
      const salesSummary = aggregateSales(sales.rows, deps.appAppleId, deps.knownParentSkus);
      const seenSkus = observedParentSkus(sales.rows, deps.appAppleId);
      if (seenSkus.length > 0) await deps.rememberParentSkus(seenSkus, dataDate);
      const plans = fillPlans(aggregateSubscription(subscription.rows, deps.appAppleId));
      const eventSummary = aggregateEvents(events.rows, deps.appAppleId);
      const reviewSummary = summarizeReviews(reviewResponse.reviews, dataDate);
      const history = await deps.history(historyStart(dataDate), dataDate);
      await deps.saveSales(dataDate, salesSummary);
      await deps.saveSubscription(dataDate, plans);
      await deps.saveEvents(dataDate, eventSummary);
      await deps.saveReviews(dataDate, reviewSummary);
      const previous = previousSales(history, dataDate);
      const text = formatFlashMessage({
        dataDate,
        sales: salesSummary,
        plans,
        events: eventSummary,
        reviews: reviewSummary,
        previousSales: previous,
        previousPlans: history.subscriptions.filter((row) => row.dataDate === addDays(dataDate, -1)),
        previousEvents: history.events.find((row) => row.dataDate === addDays(dataDate, -1)) ?? null,
        previousReviewCount: history.reviews.find((row) => row.dataDate === addDays(dataDate, -1))?.reviewCount ??
          null,
        monthSales: monthSales(history, dataDate, salesSummary),
        monthEvents: monthEvents(history, dataDate, eventSummary),
        monthReviewCount: sum(
          history.reviews.filter((row) => row.dataDate >= monthStart(dataDate) && row.dataDate < dataDate),
          (row) => row.reviewCount,
        ) + reviewSummary.reviewCount,
      });
      const outcome = await publish(deps, "flash", dataDate, text, nowMs);
      if (outcome === "failed") break;
      if (outcome === "posted") flashPosted.push(dataDate);
    } catch {
      continue;
    }
  }

  const acquisitionPosted: string[] = [];
  let bundle: AnalyticsBundle;
  try {
    bundle = await deps.fetchAnalytics();
  } catch {
    bundle = { state: "error" };
  }
  if (bundle.state === "ready") {
    for (const dataDate of candidateAcquisitionDates(now)) {
      const existing = await deps.getPost("acquisition", dataDate);
      if (nextClaim(existing, deps.now().getTime()).action === "skip") continue;
      const discoveryRows = latestRowsForDate(bundle.discovery, dataDate, deps.appAppleId);
      const downloadRows = latestRowsForDate(bundle.downloads, dataDate, deps.appAppleId);
      if (!discoveryRows || !downloadRows) continue;
      const summary = buildAnalytics(summarizeDiscovery(discoveryRows), summarizeDownloads(downloadRows));
      const history = await deps.history(addDays(dataDate, -1), dataDate);
      await deps.saveAnalytics(dataDate, summary);
      const text = formatAcquisitionMessage({
        dataDate,
        today: summary,
        previous: history.analytics.find((row) => row.dataDate === addDays(dataDate, -1)) ?? null,
      });
      const outcome = await publish(deps, "acquisition", dataDate, text, deps.now().getTime());
      if (outcome === "failed") break;
      if (outcome === "posted") acquisitionPosted.push(dataDate);
    }
  }

  return {
    flashPosted,
    acquisitionPosted,
    acquisition: bundle.state,
  };
}
