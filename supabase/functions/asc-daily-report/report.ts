import {
  addDays,
  aggregateEvents,
  addParentSkus,
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
  fileDecision,
  flashReady,
  latestRowsForDate,
  japanDateForPacificReport,
  monthStart,
  nextClaim,
  releaseDate,
  reportLogLine,
  summarizeDiscovery,
  summarizeDownloads,
  summarizeReviews,
  withBackoff,
  withinRevision,
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
  claim: (
    reportType: "flash" | "acquisition",
    dataDate: string,
    nowMs: number,
    revise?: boolean,
  ) => Promise<boolean>;
  log?: (line: string) => void;
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
  knownParentSkus: string[];
  rememberParentSkus: (skus: string[], dataDate: string) => Promise<void>;
  backoff: Backoff;
};

export type RunResult = {
  flashPosted: string[];
  acquisitionPosted: string[];
  acquisition: AnalyticsBundle["state"];
};

type ReportKind = "SALES" | "SUBSCRIPTION" | "SUBSCRIPTION_EVENT";

type FetchedReport = { state: "ready" | "empty" | "missing"; rows: Record<string, string>[] };

function sameSales(stored: SalesSummary, next: SalesSummary): boolean {
  return stored.newDownloads === next.newDownloads &&
    stored.redownloads === next.redownloads &&
    stored.salesCents === next.salesCents &&
    stored.proceedsCents === next.proceedsCents &&
    stored.nonJpyCustomerRows === next.nonJpyCustomerRows;
}

function samePlans(stored: PlanSummary[], next: PlanSummary[]): boolean {
  const line = (plan: PlanSummary) => `${plan.plan}:${plan.activePaid}:${plan.activeTrials}`;
  return stored.map(line).sort().join("|") === next.map(line).sort().join("|");
}

function sameEvents(stored: EventSummary, next: EventSummary): boolean {
  return stored.trialStarts === next.trialStarts &&
    stored.paidConversions === next.paidConversions &&
    stored.cancellations === next.cancellations;
}

function sameReviews(stored: ReviewSummary, next: ReviewSummary): boolean {
  return stored.reviewCount === next.reviewCount &&
    stored.averageRating === next.averageRating &&
    stored.excerpt === next.excerpt &&
    stored.stars.join(",") === next.stars.join(",");
}

function sameAnalytics(stored: AnalyticsSummary, next: AnalyticsSummary): boolean {
  return stored.impressions === next.impressions &&
    stored.productPageViews === next.productPageViews &&
    stored.sourceSearch === next.sourceSearch &&
    stored.sourceOther === next.sourceOther &&
    stored.downloads === next.downloads &&
    stored.conversionRate === next.conversionRate &&
    stored.searchIncludesAds === next.searchIncludesAds;
}

function historyStart(dataDate: string): string {
  const previous = addDays(dataDate, -1);
  const start = monthStart(dataDate);
  const from = previous < start ? previous : start;
  return from < releaseDate ? releaseDate : from;
}

function previousDate(dataDate: string): string | null {
  const previous = addDays(dataDate, -1);
  return previous < releaseDate ? null : previous;
}

function previousSales(history: History, dataDate: string): SalesSummary | null {
  const previous = previousDate(dataDate);
  if (!previous) return null;
  return history.sales.find((row) => row.dataDate === previous) ?? null;
}

function monthSales(history: History, dataDate: string, today: SalesSummary): SalesSummary {
  const start = monthStart(dataDate);
  const prior = history.sales.filter((row) =>
    row.dataDate >= start && row.dataDate >= releaseDate && row.dataDate < dataDate
  );
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
  const prior = history.events.filter((row) =>
    row.dataDate >= start && row.dataDate >= releaseDate && row.dataDate < dataDate
  );
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
  revise = false,
): Promise<"posted" | "failed" | "skip"> {
  const claimed = await deps.claim(reportType, dataDate, nowMs, revise);
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
  const writeLog = deps.log ?? (() => {});
  const flashPosted: string[] = [];
  let reviewsPromise: Promise<ReviewsResponse> | null = null;
  const reviews = () => {
    reviewsPromise ??= withBackoff(() => deps.fetchReviews(), deps.backoff);
    return reviewsPromise;
  };
  const cache = new Map<string, FetchedReport>();
  const dates = candidateFlashDates(now);

  async function load(kind: ReportKind, reportDate: string): Promise<FetchedReport> {
    const key = `${kind}:${reportDate}`;
    const cached = cache.get(key);
    if (cached) return cached;
    const response = await withBackoff(async () => {
      const result = await deps.fetchSalesReport(kind, reportDate);
      writeLog(reportLogLine(kind, reportDate, result.status, result.rows.length));
      return result;
    }, deps.backoff);
    const classified = classifyUnavailable(response.status, response.errorBody);
    let state: FetchedReport["state"] = "missing";
    if (classified === "ready" || classified === "empty") state = classified;
    const value: FetchedReport = { state, rows: state === "ready" ? response.rows : [] };
    cache.set(key, value);
    return value;
  }

  async function laterProductRows(kind: ReportKind, reportDate: string): Promise<number> {
    let rows = 0;
    for (const later of dates) {
      if (later <= reportDate) continue;
      const file = await load(kind, later);
      if (file.state === "ready") rows += file.rows.length;
    }
    return rows;
  }

  for (const reportDate of dates) {
    const dataDate = japanDateForPacificReport(reportDate);
    if (dataDate < releaseDate) continue;
    const existing = await deps.getPost("flash", dataDate);
    const revising = existing?.status === "posted" && withinRevision(dataDate, now);
    if (!revising && nextClaim(existing, nowMs).action === "skip") continue;
    try {
      const sales = await load("SALES", reportDate);
      const subscription = await load("SUBSCRIPTION", reportDate);
      const events = await load("SUBSCRIPTION_EVENT", reportDate);
      const reviewResponse = await reviews();
      const reviewsReady = reviewResponse.status >= 200 &&
        reviewResponse.status < 300 &&
        reviewResponse.complete;
      const ready = flashReady(
        fileDecision({ state: sales.state, rows: sales.rows.length }, await laterProductRows("SALES", reportDate)),
        fileDecision(
          { state: subscription.state, rows: subscription.rows.length },
          await laterProductRows("SUBSCRIPTION", reportDate),
        ),
        fileDecision(
          { state: events.state, rows: events.rows.length },
          await laterProductRows("SUBSCRIPTION_EVENT", reportDate),
        ),
      );
      if (!ready || !reviewsReady) continue;
      const seenSkus = observedParentSkus(sales.rows, deps.appAppleId);
      addParentSkus(deps.knownParentSkus, seenSkus);
      if (deps.knownParentSkus.length === 0) continue;
      if (seenSkus.length > 0) await deps.rememberParentSkus(seenSkus, dataDate);
      const salesSummary = aggregateSales(sales.rows, deps.appAppleId, deps.knownParentSkus);
      const plans = fillPlans(aggregateSubscription(subscription.rows, deps.appAppleId));
      const eventSummary = aggregateEvents(events.rows, deps.appAppleId);
      const reviewSummary = summarizeReviews(reviewResponse.reviews, dataDate);
      const history = await deps.history(historyStart(dataDate), dataDate);
      const storedSales = history.sales.find((row) => row.dataDate === dataDate);
      const storedEvents = history.events.find((row) => row.dataDate === dataDate);
      const storedReviews = history.reviews.find((row) => row.dataDate === dataDate);
      const storedPlans = history.subscriptions.filter((row) => row.dataDate === dataDate);
      const unchanged = revising &&
        storedSales !== undefined &&
        storedEvents !== undefined &&
        storedReviews !== undefined &&
        sameSales(storedSales, salesSummary) &&
        sameEvents(storedEvents, eventSummary) &&
        sameReviews(storedReviews, reviewSummary) &&
        samePlans(storedPlans, plans);
      if (unchanged) continue;
      await deps.saveSales(dataDate, salesSummary);
      await deps.saveSubscription(dataDate, plans);
      await deps.saveEvents(dataDate, eventSummary);
      await deps.saveReviews(dataDate, reviewSummary);
      const previous = previousSales(history, dataDate);
      const text = formatFlashMessage({
        dataDate,
        correction: revising,
        sales: salesSummary,
        plans,
        events: eventSummary,
        reviews: reviewSummary,
        previousSales: previous,
        previousPlans: history.subscriptions.filter((row) => row.dataDate === previousDate(dataDate)),
        previousEvents: history.events.find((row) => row.dataDate === previousDate(dataDate)) ?? null,
        previousReviewCount: history.reviews.find((row) => row.dataDate === previousDate(dataDate))?.reviewCount ??
          null,
        monthSales: monthSales(history, dataDate, salesSummary),
        monthEvents: monthEvents(history, dataDate, eventSummary),
        monthReviewCount: sum(
          history.reviews.filter((row) =>
            row.dataDate >= monthStart(dataDate) && row.dataDate >= releaseDate && row.dataDate < dataDate
          ),
          (row) => row.reviewCount,
        ) + reviewSummary.reviewCount,
      });
      const outcome = await publish(deps, "flash", dataDate, text, nowMs, revising);
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
    for (const reportDate of candidateAcquisitionDates(now)) {
      const dataDate = japanDateForPacificReport(reportDate);
      if (dataDate < releaseDate) continue;
      const existing = await deps.getPost("acquisition", dataDate);
      const revising = existing?.status === "posted" && withinRevision(dataDate, now);
      if (!revising && nextClaim(existing, deps.now().getTime()).action === "skip") continue;
      const discoveryRows = latestRowsForDate(bundle.discovery, reportDate, deps.appAppleId);
      const downloadRows = latestRowsForDate(bundle.downloads, reportDate, deps.appAppleId);
      if (!discoveryRows || !downloadRows) continue;
      const summary = buildAnalytics(summarizeDiscovery(discoveryRows), summarizeDownloads(downloadRows));
      const history = await deps.history(historyStart(dataDate), dataDate);
      const stored = history.analytics.find((row) => row.dataDate === dataDate);
      if (revising && stored && sameAnalytics(stored, summary)) continue;
      await deps.saveAnalytics(dataDate, summary);
      const text = formatAcquisitionMessage({
        dataDate,
        correction: revising,
        today: summary,
        previous: history.analytics.find((row) => row.dataDate === previousDate(dataDate)) ?? null,
      });
      const outcome = await publish(deps, "acquisition", dataDate, text, deps.now().getTime(), revising);
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
