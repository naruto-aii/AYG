import {
  classifyUsage,
  combinedPublishable,
  deliveryDecision,
  formatCombinedMessage,
  reportPayload,
  salesPoint,
  snapshotHash,
  summarizeAppleSessions,
  summarizeCrashes,
  summarizeInstalls,
  type AppActivity,
  type CombinedDeltas,
  type CombinedView,
  type CountPoint,
  type MetricState,
} from "./metrics.ts";
import {
  addDays,
  aggregateEvents,
  addParentSkus,
  aggregateSales,
  observedParentSkus,
  aggregateSubscription,
  buildAnalytics,
  candidateFlashDates,
  classifyUnavailable,
  fillPlans,
  fileDecision,
  flashReady,
  latestRowsForDate,
  japanDateForPacificReport,
  monthStart,
  pacificReportBounds,
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
  | {
    state: "ready";
    discovery: AnalyticsInstance[];
    downloads: AnalyticsInstance[];
    installs: AnalyticsInstance[] | null;
    sessions: AnalyticsInstance[] | null;
    crashes: AnalyticsInstance[] | null;
  };

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
  getDelivery: (dataDate: string) => Promise<(StoredPost & { contentHash: string | null }) | null>;
  claimDelivery: (dataDate: string, contentHash: string, revise: boolean) => Promise<boolean>;
  saveUsage: (dataDate: string, row: UsageRow) => Promise<void>;
  saveAppActivity: (dataDate: string, startIso: string, endIso: string, row: AppActivity) => Promise<void>;
  saveSnapshot: (row: SnapshotRow) => Promise<void>;
  appActivity: (startIso: string, endIso: string) => Promise<AppActivity>;
  historyExtra: (from: string, to: string) => Promise<ExtraHistory>;
  knownParentSkus: string[];
  rememberParentSkus: (skus: string[], dataDate: string) => Promise<void>;
  backoff: Backoff;
};

export type UsageRow = {
  installs: number | null;
  uninstalls: number | null;
  installsState: MetricState;
  sessions: number | null;
  sessionDurationSeconds: number | null;
  uniqueDevices: number | null;
  sessionsState: MetricState;
  crashCount: number | null;
  crashesByVersion: { key: string; crashes: number }[] | null;
  crashesByDevice: { key: string; crashes: number }[] | null;
  crashesState: MetricState;
};

export type ExtraHistory = {
  usage: Array<UsageRow & { dataDate: string }>;
  activity: Array<AppActivity & { dataDate: string }>;
};

export type SnapshotRow = {
  dataDate: string;
  heading: string;
  slackText: string;
  payload: Record<string, unknown>;
  contentHash: string;
  publishable: boolean;
};

export type RunResult = {
  flashPosted: string[];
  acquisitionPosted: string[];
  prepared: string[];
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

function pointOf(state: MetricState, value: number): CountPoint {
  return state === "present" ? { state: "present", value } : { state, value: null };
}

function usageNumbers(
  bundle: AnalyticsBundle,
  reportDate: string,
  appAppleId: string,
): {
  usage: UsageRow;
  discovery: MetricState;
  downloads: MetricState;
  impressions: number;
  pageViews: number;
  sourceSearch: number;
  sourceOther: number;
} {
  const empty = {
    impressions: 0,
    productPageViews: 0,
    sourceSearch: 0,
    sourceOther: 0,
  };
  if (bundle.state !== "ready") {
    const pending: MetricState = "pending";
    return {
      usage: emptyUsage(pending),
      discovery: pending,
      downloads: pending,
      impressions: 0,
      pageViews: 0,
      sourceSearch: 0,
      sourceOther: 0,
    };
  }
  const discovery = classifyUsage(bundle.discovery, reportDate, appAppleId);
  const downloads = classifyUsage(bundle.downloads, reportDate, appAppleId);
  const installs = classifyUsage(bundle.installs, reportDate, appAppleId);
  const sessions = classifyUsage(bundle.sessions, reportDate, appAppleId);
  const crashes = classifyUsage(bundle.crashes, reportDate, appAppleId);
  const found = discovery.state === "present" ? summarizeDiscovery(discovery.rows) : empty;
  const installSummary = installs.state === "present" ? summarizeInstalls(installs.rows) : null;
  const sessionSummary = sessions.state === "present" ? summarizeAppleSessions(sessions.rows) : null;
  const crashSummary = crashes.state === "present" ? summarizeCrashes(crashes.rows) : null;
  return {
    discovery: discovery.state,
    downloads: downloads.state,
    impressions: found.impressions,
    pageViews: found.productPageViews,
    sourceSearch: found.sourceSearch,
    sourceOther: found.sourceOther,
    usage: {
      installs: installSummary?.installs ?? null,
      uninstalls: installSummary?.uninstalls ?? null,
      installsState: installs.state,
      sessions: sessionSummary?.sessions ?? null,
      sessionDurationSeconds: sessionSummary?.durationSeconds ?? null,
      uniqueDevices: sessionSummary?.uniqueDevices ?? null,
      sessionsState: sessions.state,
      crashCount: crashSummary?.total ?? null,
      crashesByVersion: crashSummary?.byVersion ?? null,
      crashesByDevice: crashSummary?.byDevice ?? null,
      crashesState: crashes.state,
    },
  };
}

function emptyUsage(state: MetricState): UsageRow {
  return {
    installs: null,
    uninstalls: null,
    installsState: state,
    sessions: null,
    sessionDurationSeconds: null,
    uniqueDevices: null,
    sessionsState: state,
    crashCount: null,
    crashesByVersion: null,
    crashesByDevice: null,
    crashesState: state,
  };
}

const planLabels: Record<string, string> = {
  monthly: "月額",
  half_year: "半年",
  yearly: "年額",
  other: "その他",
};

function historyPoint(
  row: UsageRow | undefined,
  state: MetricState | undefined,
  value: number | null | undefined,
): CountPoint | null {
  if (!row || state == null) return null;
  return state === "present" && value != null ? { state, value } : { state, value: null };
}

export async function runAscDailyReport(deps: ReportDeps): Promise<RunResult> {
  const now = deps.now();
  const nowMs = now.getTime();
  const writeLog = deps.log ?? (() => {});
  const prepared: string[] = [];
  let reviewsPromise: Promise<ReviewsResponse> | null = null;
  const reviews = () => {
    reviewsPromise ??= withBackoff(() => deps.fetchReviews(), deps.backoff);
    return reviewsPromise;
  };
  let bundle: AnalyticsBundle;
  try {
    bundle = await deps.fetchAnalytics();
  } catch {
    bundle = { state: "error" };
  }
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
    const existing = await deps.getDelivery(dataDate);
    const revisingAllowed = withinRevision(dataDate, now);
    if (existing?.status === "posted" && !revisingAllowed) continue;
    if (existing && existing.status !== "posted" && deliveryDecision(existing, nowMs, "", false) === "skip") {
      continue;
    }
    try {
      const sales = await load("SALES", reportDate);
      const subscription = await load("SUBSCRIPTION", reportDate);
      const events = await load("SUBSCRIPTION_EVENT", reportDate);
      const reviewResponse = await reviews();
      const reviewsReady = reviewResponse.status >= 200 && reviewResponse.status < 300 && reviewResponse.complete;
      const salesDecision = fileDecision(
        { state: sales.state, rows: sales.rows.length },
        await laterProductRows("SALES", reportDate),
      );
      const subscriptionDecision = fileDecision(
        { state: subscription.state, rows: subscription.rows.length },
        await laterProductRows("SUBSCRIPTION", reportDate),
      );
      const eventsDecision = fileDecision(
        { state: events.state, rows: events.rows.length },
        await laterProductRows("SUBSCRIPTION_EVENT", reportDate),
      );
      if (!flashReady(salesDecision, subscriptionDecision, eventsDecision) || !reviewsReady) continue;
      const seenSkus = observedParentSkus(sales.rows, deps.appAppleId);
      addParentSkus(deps.knownParentSkus, seenSkus);
      if (deps.knownParentSkus.length === 0) continue;
      if (seenSkus.length > 0) await deps.rememberParentSkus(seenSkus, dataDate);
      const salesSummary = aggregateSales(sales.rows, deps.appAppleId, deps.knownParentSkus);
      const plans = fillPlans(aggregateSubscription(subscription.rows, deps.appAppleId));
      const eventSummary = aggregateEvents(events.rows, deps.appAppleId);
      const reviewSummary = summarizeReviews(reviewResponse.reviews, dataDate);
      await deps.saveSales(dataDate, salesSummary);
      await deps.saveSubscription(dataDate, plans);
      await deps.saveEvents(dataDate, eventSummary);
      await deps.saveReviews(dataDate, reviewSummary);
      const usage = usageNumbers(bundle, reportDate, deps.appAppleId);
      if (usage.discovery === "present" && usage.downloads === "present" && bundle.state === "ready") {
        const discoveryRows = latestRowsForDate(bundle.discovery, reportDate, deps.appAppleId) ?? [];
        const downloadRows = latestRowsForDate(bundle.downloads, reportDate, deps.appAppleId) ?? [];
        await deps.saveAnalytics(
          dataDate,
          buildAnalytics(summarizeDiscovery(discoveryRows), summarizeDownloads(downloadRows)),
        );
      }
      await deps.saveUsage(dataDate, usage.usage);
      const bounds = pacificReportBounds(reportDate);
      const activity = await deps.appActivity(bounds.start.toISOString(), bounds.end.toISOString());
      await deps.saveAppActivity(dataDate, bounds.start.toISOString(), bounds.end.toISOString(), activity);
      const from = addDays(dataDate, -7) < releaseDate ? releaseDate : addDays(dataDate, -7);
      const history = await deps.history(from, dataDate);
      const extra = await deps.historyExtra(from, dataDate);
      const previousDate = addDays(dataDate, -1);
      const weekDate = addDays(dataDate, -7);
      const previousSales = previousDate < releaseDate
        ? null
        : history.sales.find((row) => row.dataDate === previousDate) ?? null;
      const weekSales = history.sales.find((row) => row.dataDate === weekDate) ?? null;
      const previousUsage = extra.usage.find((row) => row.dataDate === previousDate);
      const weekUsage = extra.usage.find((row) => row.dataDate === weekDate);
      const previousActivity = extra.activity.find((row) => row.dataDate === previousDate) ?? null;
      const weekActivity = extra.activity.find((row) => row.dataDate === weekDate) ?? null;
      const salesDeltas = (row: SalesSummary | null): Pick<CombinedDeltas, "newDownloads" | "redownloads" | "salesCents" | "proceedsCents"> | null => {
        if (!row) return null;
        return {
          newDownloads: { state: "present", value: row.newDownloads },
          redownloads: { state: "present", value: row.redownloads },
          salesCents: { state: "present", value: row.salesCents },
          proceedsCents: { state: "present", value: row.proceedsCents },
        };
      };
      const usageDeltas = (row: (UsageRow & { dataDate: string }) | undefined) => ({
        impressions: historyPoint(row, row?.installsState, null),
        pageViews: historyPoint(row, row?.installsState, null),
        installs: historyPoint(row, row?.installsState, row?.installs),
        uninstalls: historyPoint(row, row?.installsState, row?.uninstalls),
        appleSessions: historyPoint(row, row?.sessionsState, row?.sessions),
      });
      // 集客の前日は保存済みの analytics を使う。usage 行には表示回数を入れていない。
      const analyticsPoint = (date: string, pick: (row: AnalyticsSummary) => number): CountPoint | null => {
        const row = history.analytics.find((item) => item.dataDate === date);
        if (!row) return null;
        return { state: "present", value: pick(row) };
      };
      const previousSalesPart = salesDeltas(previousSales);
      const weekSalesPart = salesDeltas(weekSales);
      const view: CombinedView = {
        reportDate,
        correction: false,
        publishable: combinedPublishable({
          sales: salesDecision,
          subscription: subscriptionDecision,
          events: eventsDecision,
          reviewsReady,
          hasParentSku: true,
          discovery: usage.discovery,
          downloads: usage.downloads,
        }),
        newDownloads: salesPoint(salesDecision, salesSummary.newDownloads),
        redownloads: salesPoint(salesDecision, salesSummary.redownloads),
        salesCents: salesPoint(salesDecision, salesSummary.salesCents),
        proceedsCents: salesPoint(salesDecision, salesSummary.proceedsCents),
        impressions: pointOf(usage.discovery, usage.impressions),
        pageViews: pointOf(usage.discovery, usage.pageViews),
        sourceSearch: pointOf(usage.discovery, usage.sourceSearch),
        sourceOther: pointOf(usage.discovery, usage.sourceOther),
        installs: pointOf(usage.usage.installsState, usage.usage.installs ?? 0),
        uninstalls: pointOf(usage.usage.installsState, usage.usage.uninstalls ?? 0),
        appleSessions: pointOf(usage.usage.sessionsState, usage.usage.sessions ?? 0),
        appleDurationSeconds: pointOf(usage.usage.sessionsState, usage.usage.sessionDurationSeconds ?? 0),
        uniqueDevices: pointOf(usage.usage.sessionsState, usage.usage.uniqueDevices ?? 0),
        crashTotal: pointOf(usage.usage.crashesState, usage.usage.crashCount ?? 0),
        crashesByVersion: usage.usage.crashesByVersion,
        crashesByDevice: usage.usage.crashesByDevice,
        plans: plans.map((plan) => ({
          label: planLabels[plan.plan] ?? plan.plan,
          paid: plan.activePaid,
          trials: plan.activeTrials,
        })),
        appleTrialStarts: salesPoint(eventsDecision, eventSummary.trialStarts),
        paidConversions: salesPoint(eventsDecision, eventSummary.paidConversions),
        cancellations: salesPoint(eventsDecision, eventSummary.cancellations),
        reviewCount: reviewSummary.reviewCount,
        averageRating: reviewSummary.averageRating,
        stars: reviewSummary.stars,
        excerpt: reviewSummary.excerpt,
        activity,
        previous: {
          newDownloads: previousSalesPart?.newDownloads ?? null,
          redownloads: previousSalesPart?.redownloads ?? null,
          salesCents: previousSalesPart?.salesCents ?? null,
          proceedsCents: previousSalesPart?.proceedsCents ?? null,
          impressions: analyticsPoint(previousDate, (row) => row.impressions),
          pageViews: analyticsPoint(previousDate, (row) => row.productPageViews),
          installs: usageDeltas(previousUsage).installs,
          uninstalls: usageDeltas(previousUsage).uninstalls,
          appleSessions: usageDeltas(previousUsage).appleSessions,
          activity: previousActivity,
        },
        week: {
          newDownloads: weekSalesPart?.newDownloads ?? null,
          redownloads: weekSalesPart?.redownloads ?? null,
          salesCents: weekSalesPart?.salesCents ?? null,
          proceedsCents: weekSalesPart?.proceedsCents ?? null,
          impressions: analyticsPoint(weekDate, (row) => row.impressions),
          pageViews: analyticsPoint(weekDate, (row) => row.productPageViews),
          installs: usageDeltas(weekUsage).installs,
          uninstalls: usageDeltas(weekUsage).uninstalls,
          appleSessions: usageDeltas(weekUsage).appleSessions,
          activity: weekActivity,
        },
        nonJpyCustomerRows: salesSummary.nonJpyCustomerRows,
      };
      const hash = await snapshotHash(view);
      const action = deliveryDecision(existing, deps.now().getTime(), hash, revisingAllowed);
      if (action === "revise") view.correction = true;
      const slackText = formatCombinedMessage(view);
      const payload = reportPayload({ ...view });
      await deps.saveSnapshot({
        dataDate,
        heading: slackText.split("\n")[0] ?? "",
        slackText,
        payload,
        contentHash: hash,
        publishable: view.publishable,
      });
      if (!view.publishable || action === "skip") continue;
      const claimed = await deps.claimDelivery(dataDate, hash, action === "revise");
      if (claimed) prepared.push(dataDate);
    } catch {
      continue;
    }
  }

  return {
    flashPosted: [],
    acquisitionPosted: [],
    prepared,
    acquisition: bundle.state,
  };
}
