import {
  campaignsFromReport,
  centsToAmount,
  eligibleReportDates,
  formatDailyMessage,
  keywordsFromReport,
  nextClaim,
  maxPages,
  pageLimit,
  readOrg,
  readReportPage,
  reportWindow,
  withBackoff,
  type Backoff,
  type DayReport,
  type KeywordMetrics,
  type ReportWindow,
  type StoredPost,
} from "./parse.ts";

export class ReportError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

export type HttpResult = {
  status: number;
  body: unknown;
};

export type ReportCall = {
  kind: "campaigns" | "keywords";
  campaignId: string;
  startTime: string;
  endTime: string;
  timeZone: "ORTZ" | "UTC";
  granularity: "DAILY" | "HOURLY";
  offset: number;
  limit: number;
};

export type AsaDeps = {
  now: () => Date;
  orgId: string;
  getPost: (dataDate: string) => Promise<StoredPost | null>;
  claim: (dataDate: string) => Promise<boolean>;
  finish: (dataDate: string, status: "posted" | "failed") => Promise<void>;
  saveDay: (day: DayReport) => Promise<void>;
  fetchOrg: () => Promise<HttpResult>;
  fetchReport: (call: ReportCall) => Promise<HttpResult>;
  postSlack: (text: string) => Promise<boolean>;
  backoff: Backoff;
};

export type RunResult = {
  posted: string[];
  skipped: string[];
  stopped: string | null;
};

const maxCampaigns = 200;
const maxKeywords = 5000;

async function finishReliably(
  deps: AsaDeps,
  dataDate: string,
  status: "posted" | "failed",
): Promise<boolean> {
  const attempts = status === "posted" ? 5 : 3;
  let wait = deps.backoff.initialMs;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      await deps.finish(dataDate, status);
      return true;
    } catch {
      if (attempt === attempts - 1) return false;
      await deps.backoff.sleep(wait);
      wait *= 2;
    }
  }
  return false;
}

async function publish(deps: AsaDeps, dataDate: string, text: string): Promise<"posted" | "failed" | "skip"> {
  const claimed = await deps.claim(dataDate);
  if (!claimed) return "skip";
  let status: "posted" | "failed" = "failed";
  try {
    if (await deps.postSlack(text)) status = "posted";
  } catch {
    status = "failed";
  }
  const finished = await finishReliably(deps, dataDate, status);
  if (!finished) return "failed";
  return status;
}

async function loadRows(deps: AsaDeps, call: Omit<ReportCall, "offset" | "limit">): Promise<
  { state: "ok"; rows: unknown[] } | { state: "http" } | { state: "unreadable" }
> {
  const rows: unknown[] = [];
  let offset = 0;
  for (let page = 0; page < maxPages; page++) {
    const result = await withBackoff(
      () => deps.fetchReport({ ...call, offset, limit: pageLimit }),
      deps.backoff,
    );
    if (result.status !== 200) return { state: "http" };
    const parsed = readReportPage(result.body);
    if (!parsed) return { state: "unreadable" };
    rows.push(...parsed.rows);
    const loaded = offset + parsed.rows.length;
    const done = parsed.rows.length < pageLimit || (parsed.total != null && loaded >= parsed.total);
    if (done) return { state: "ok", rows };
    offset = loaded;
  }
  return { state: "unreadable" };
}

function callFor(kind: "campaigns" | "keywords", campaignId: string, window: ReportWindow): Omit<ReportCall, "offset" | "limit"> {
  return {
    kind,
    campaignId,
    startTime: window.startTime,
    endTime: window.endTime,
    timeZone: window.timeZone,
    granularity: window.granularity,
  };
}

async function loadDay(
  deps: AsaDeps,
  dataDate: string,
  timeZone: string,
  currency: string,
): Promise<{ state: "ready"; day: DayReport } | { state: "http" } | { state: "unreadable" } | { state: "no_calonavi" }> {
  const window = reportWindow(dataDate, timeZone);
  const campaignsPage = await loadRows(deps, callFor("campaigns", "", window));
  if (campaignsPage.state !== "ok") return campaignsPage;
  const campaigns = campaignsFromReport(campaignsPage.rows, window.mode, dataDate, currency);
  if (!campaigns.ok) return { state: "unreadable" };
  if (campaigns.rows.length === 0 || campaigns.rows.length > maxCampaigns) {
    return campaigns.rows.length === 0 ? { state: "no_calonavi" } : { state: "unreadable" };
  }
  const keywords: KeywordMetrics[] = [];
  for (const campaign of campaigns.rows) {
    const keywordPage = await loadRows(deps, callFor("keywords", campaign.campaignId, window));
    if (keywordPage.state !== "ok") return keywordPage;
    const parsed = keywordsFromReport(keywordPage.rows, campaign.campaignId, window.mode, dataDate, currency || campaign.currency);
    if (!parsed.ok) return { state: "unreadable" };
    keywords.push(...parsed.rows);
    if (keywords.length > maxKeywords) return { state: "unreadable" };
  }
  return { state: "ready", day: { dataDate, campaigns: campaigns.rows, keywords } };
}

export async function runAsaDailyReport(deps: AsaDeps): Promise<RunResult> {
  const now = deps.now();
  const dates = eligibleReportDates(now);
  const posted: string[] = [];
  const skipped: string[] = [];
  if (dates.length === 0) return { posted, skipped, stopped: null };

  const pending: string[] = [];
  for (const dataDate of dates) {
    const existing = await deps.getPost(dataDate);
    if (nextClaim(existing, now.getTime()).action === "skip") skipped.push(dataDate);
    else pending.push(dataDate);
  }
  if (pending.length === 0) return { posted, skipped, stopped: null };

  const orgResult = await withBackoff(() => deps.fetchOrg(), deps.backoff);
  if (orgResult.status !== 200) return { posted, skipped, stopped: "apple_http" };
  const org = readOrg(orgResult.body, deps.orgId);
  if (!org.found) return { posted, skipped, stopped: "org_not_found" };

  let sawNoCampaign = false;
  for (const dataDate of pending) {
    const loaded = await loadDay(deps, dataDate, org.timeZone, org.currency);
    if (loaded.state === "http") return { posted, skipped, stopped: "apple_http" };
    if (loaded.state === "unreadable") return { posted, skipped, stopped: "unreadable" };
    if (loaded.state === "no_calonavi") {
      sawNoCampaign = true;
      skipped.push(dataDate);
      continue;
    }
    await deps.saveDay(loaded.day);
    const published = await publish(deps, dataDate, formatDailyMessage(loaded.day));
    if (published === "posted") {
      posted.push(dataDate);
      continue;
    }
    if (published === "skip") {
      skipped.push(dataDate);
      continue;
    }
    return { posted, skipped, stopped: "slack_failed" };
  }
  if (posted.length === 0 && sawNoCampaign) return { posted, skipped, stopped: "no_calonavi" };
  return { posted, skipped, stopped: null };
}

export function dayPayload(day: DayReport): {
  report_type: "daily";
  data_date: string;
  campaigns: Record<string, string | number>[];
  keywords: Record<string, string | number>[];
} {
  return {
    report_type: "daily",
    data_date: day.dataDate,
    campaigns: day.campaigns.map((row) => ({
      campaign_id: row.campaignId,
      campaign_name: row.campaignName,
      impressions: row.impressions,
      taps: row.taps,
      installs: row.installs,
      spend: centsToAmount(row.spendCents),
      currency: row.currency,
    })),
    keywords: day.keywords.map((row) => ({
      campaign_id: row.campaignId,
      ad_group_id: row.adGroupId,
      ad_group_name: row.adGroupName,
      keyword_id: row.keywordId,
      keyword: row.keyword,
      match_type: row.matchType,
      impressions: row.impressions,
      taps: row.taps,
      installs: row.installs,
      spend: centsToAmount(row.spendCents),
      currency: row.currency,
    })),
  };
}
