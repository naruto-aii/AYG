// 日本時間の前日を、キャンペーンとキーワードにまとめて文面にする。
// 検索語句は取らない。キーワードは広告主が設定した語句だけ。

export const readyLagMs = 6 * 60 * 60 * 1000;
export const lookbackDays = 7;
export const reservationLeaseMs = 30 * 60 * 1000;
export const pageLimit = 1000;
export const maxPages = 20;

const weekdays = ["日", "月", "火", "水", "木", "金", "土"];
const calonaviName = /カロナビ|calonavi/i;

export type Backoff = {
  initialMs: number;
  maxAttempts: number;
  sleep: (ms: number) => Promise<void>;
};

export type StoredPost = {
  status: "reserved" | "posted" | "failed";
  attempt: number;
  updatedAtMs: number;
};

export type Metrics = {
  impressions: number;
  taps: number;
  installs: number;
  spendCents: number;
  currency: string;
  installField: "totalInstalls" | "installs";
};

export type CampaignMetrics = Metrics & {
  campaignId: string;
  campaignName: string;
};

export type KeywordMetrics = Metrics & {
  campaignId: string;
  adGroupId: string;
  adGroupName: string;
  keywordId: string;
  keyword: string;
  matchType: string;
};

export type DayReport = {
  dataDate: string;
  campaigns: CampaignMetrics[];
  keywords: KeywordMetrics[];
};

export function claimBackoffMs(attempt: number): number {
  const exponent = Math.min(Math.max(attempt - 1, 0), 6);
  return Math.min(reservationLeaseMs, 30_000 * 2 ** exponent);
}

export function nextClaim(
  post: StoredPost | null,
  nowMs: number,
): { action: "insert" | "reclaim" | "skip"; attempt: number } {
  if (!post) return { action: "insert", attempt: 1 };
  if (post.status === "posted") return { action: "skip", attempt: post.attempt };
  if (post.status === "reserved") {
    if (nowMs - post.updatedAtMs < reservationLeaseMs) {
      return { action: "skip", attempt: post.attempt };
    }
    return { action: "reclaim", attempt: post.attempt + 1 };
  }
  if (nowMs - post.updatedAtMs < claimBackoffMs(post.attempt)) {
    return { action: "skip", attempt: post.attempt };
  }
  return { action: "reclaim", attempt: post.attempt + 1 };
}

export function jstDateString(instant: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const pick = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? "";
  return `${pick("year")}-${pick("month")}-${pick("day")}`;
}

export function addDays(isoDate: string, days: number): string {
  const [year, month, day] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

function jstMidnightMs(isoDate: string): number {
  return Date.parse(`${isoDate}T00:00:00+09:00`);
}

/// その日本時間の日付が終わってから 6 時間たったものだけ。当日分は含めない。
export function eligibleReportDates(now: Date, lookback = lookbackDays): string[] {
  const today = jstDateString(now);
  const dates: string[] = [];
  for (let age = lookback; age >= 1; age--) {
    const date = addDays(today, -age);
    if (now.getTime() >= jstMidnightMs(addDays(date, 1)) + readyLagMs) dates.push(date);
  }
  return dates;
}

export function isJapanOrgTimeZone(timeZone: string): boolean {
  return timeZone.trim() === "Asia/Tokyo";
}

export type ReportWindow = {
  mode: "daily" | "hourly";
  startTime: string;
  endTime: string;
  timeZone: "ORTZ" | "UTC";
  granularity: "DAILY" | "HOURLY";
};

export function reportWindow(dataDate: string, orgTimeZone: string): ReportWindow {
  if (isJapanOrgTimeZone(orgTimeZone)) {
    return {
      mode: "daily",
      startTime: dataDate,
      endTime: dataDate,
      timeZone: "ORTZ",
      granularity: "DAILY",
    };
  }
  return {
    mode: "hourly",
    startTime: addDays(dataDate, -1),
    endTime: dataDate,
    timeZone: "UTC",
    granularity: "HOURLY",
  };
}

export type OrgRecord = {
  found: boolean;
  timeZone: string;
  currency: string;
};

export function readOrg(body: unknown, orgId: string): OrgRecord {
  const empty = { found: false, timeZone: "", currency: "" };
  if (!body || typeof body !== "object") return empty;
  const data = (body as Record<string, unknown>).data;
  if (!Array.isArray(data)) return empty;
  for (const item of data) {
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    const id = row.orgId;
    const text = typeof id === "number" && Number.isSafeInteger(id) ? String(id) : typeof id === "string" ? id.trim() : "";
    if (text !== orgId) continue;
    const timeZone = typeof row.timeZone === "string" ? row.timeZone.trim() : "";
    const currency = cleanCurrency(row.currency);
    return { found: true, timeZone, currency };
  }
  return empty;
}

function cleanCurrency(value: unknown): string {
  if (typeof value !== "string") return "";
  const currency = value.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(currency) ? currency : "";
}

export type ReportPage = {
  rows: unknown[];
  total: number | null;
};

export function readReportPage(body: unknown): ReportPage | null {
  if (!body || typeof body !== "object") return null;
  const root = body as Record<string, unknown>;
  if (hasApiError(root.error)) return null;
  const data = root.data && typeof root.data === "object" ? root.data as Record<string, unknown> : root;
  const reporting = data.reportingDataResponse;
  if (!reporting || typeof reporting !== "object") return null;
  const rows = (reporting as Record<string, unknown>).row;
  if (!Array.isArray(rows)) return null;
  const pagination = (root.pagination ?? data.pagination) as Record<string, unknown> | null;
  const totalResults = pagination && typeof pagination === "object" ? pagination.totalResults : null;
  const total = typeof totalResults === "number" && Number.isFinite(totalResults) ? totalResults : null;
  return { rows, total };
}

function hasApiError(error: unknown): boolean {
  if (error == null) return false;
  if (typeof error !== "object") return true;
  const errors = (error as Record<string, unknown>).errors;
  if (Array.isArray(errors)) return errors.length > 0;
  return Object.keys(error as Record<string, unknown>).length > 0;
}

type ParseFailure = { ok: false };
type ParseSuccess<T> = { ok: true; rows: T[] };

function cleanText(value: string, max: number): string {
  const cleaned = value.replace(/[\u0000-\u001F\u007F]/g, " ").replace(/\s+/g, " ").trim();
  return cleaned.slice(0, max);
}

function readId(value: unknown): string | null {
  if (typeof value === "string" && /^[0-9]+$/.test(value)) {
    const trimmed = value.replace(/^0+(?=\d)/, "");
    return trimmed === "0" ? null : trimmed;
  }
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) return String(value);
  return null;
}

function moneyToCents(amount: string): number | null {
  if (!/^\d+(\.\d+)?$/.test(amount)) return null;
  const [whole, fraction = ""] = amount.split(".");
  const centsText = `${whole}${(fraction + "00").slice(0, 2)}`;
  if (!/^\d+$/.test(centsText)) return null;
  let cents = Number(centsText);
  if (!Number.isSafeInteger(cents)) return null;
  if (fraction.length > 2 && fraction.charCodeAt(2) >= 53) cents += 1;
  return cents;
}

function readCount(source: Record<string, unknown>, key: string): number | null {
  const value = source[key];
  if (typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 2_000_000_000) return value;
  if (typeof value === "string" && /^\d+$/.test(value)) {
    const number = Number(value);
    if (Number.isSafeInteger(number) && number <= 2_000_000_000) return number;
  }
  return null;
}

function metricSource(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  if (row.metrics && typeof row.metrics === "object") return row.metrics as Record<string, unknown>;
  return row;
}

function readMetrics(value: unknown, fallbackCurrency: string): Metrics | "empty" | null {
  const source = metricSource(value);
  if (!source) return "empty";
  const impressions = readCount(source, "impressions");
  const taps = readCount(source, "taps");
  const totalInstalls = readCount(source, "totalInstalls");
  const legacyInstalls = readCount(source, "installs");
  const spend = source.localSpend;
  const spendRecord = spend && typeof spend === "object" ? spend as Record<string, unknown> : null;
  const amount = spendRecord && typeof spendRecord.amount === "string" ? moneyToCents(spendRecord.amount) : null;
  const currency = spendRecord ? cleanCurrency(spendRecord.currency) : "";
  const present = [impressions, taps, totalInstalls ?? legacyInstalls, amount].filter((item) => item != null).length;
  if (present === 0) return "empty";
  if (impressions == null || taps == null || amount == null) return null;
  const installs = totalInstalls ?? legacyInstalls;
  if (installs == null) return null;
  const resolvedCurrency = currency || fallbackCurrency;
  if (!resolvedCurrency) return null;
  return {
    impressions,
    taps,
    installs,
    spendCents: amount,
    currency: resolvedCurrency,
    installField: totalInstalls != null ? "totalInstalls" : "installs",
  };
}

function zeroMetrics(currency: string): Metrics {
  return {
    impressions: 0,
    taps: 0,
    installs: 0,
    spendCents: 0,
    currency,
    installField: "totalInstalls",
  };
}

function addMetrics(left: Metrics, right: Metrics): Metrics | null {
  if (left.currency !== right.currency) return null;
  const impressions = left.impressions + right.impressions;
  const taps = left.taps + right.taps;
  const installs = left.installs + right.installs;
  const spendCents = left.spendCents + right.spendCents;
  if (impressions > 2_000_000_000 || taps > 2_000_000_000 || installs > 2_000_000_000) return null;
  if (!Number.isSafeInteger(spendCents)) return null;
  return {
    impressions,
    taps,
    installs,
    spendCents,
    currency: left.currency,
    installField: left.installField === "installs" || right.installField === "installs" ? "installs" : "totalInstalls",
  };
}

type Stamp = { year: number; month: number; day: number; hour: number; zoned: boolean };

function parseStamp(value: string): Stamp | null {
  const match = value.trim().match(
    /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2})(?::\d{2}(?::\d{2}(?:\.\d+)?)?)?(Z|[+-]\d{2}:?\d{2})?)?$/,
  );
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = match[4] == null ? null : Number(match[4]);
  if (month < 1 || month > 12 || day < 1 || day > 31 || (hour != null && hour > 23)) return null;
  return { year, month, day, hour: hour ?? 0, zoned: hour != null };
}

function stampUtcMs(stamp: Stamp, offset: string | null): number | null {
  if (!offset || offset === "Z") return Date.UTC(stamp.year, stamp.month - 1, stamp.day, stamp.hour);
  const match = offset.match(/^([+-])(\d{2}):?(\d{2})$/);
  if (!match) return null;
  const sign = match[1] === "+" ? 1 : -1;
  const minutes = sign * (Number(match[2]) * 60 + Number(match[3]));
  return Date.UTC(stamp.year, stamp.month - 1, stamp.day, stamp.hour) - minutes * 60_000;
}

function granularity(row: Record<string, unknown>): unknown[] {
  return Array.isArray(row.granularity) ? row.granularity : [];
}

function pointDate(point: unknown): string {
  if (!point || typeof point !== "object") return "";
  const date = (point as Record<string, unknown>).date;
  return typeof date === "string" ? date : "";
}

function inJapanDate(stampText: string, japanDate: string, mode: "daily" | "hourly"): boolean | null {
  if (mode === "daily") return stampText.trim().slice(0, 10) === japanDate ? true : false;
  const match = stampText.trim().match(
    /^(\d{4}-\d{2}-\d{2})[ T](\d{2})(?::\d{2}(?::\d{2}(?:\.\d+)?)?)?(Z|[+-]\d{2}:?\d{2})?$/,
  );
  if (!match) return null;
  const parsed = parseStamp(stampText);
  if (!parsed || !parsed.zoned) return null;
  const utc = stampUtcMs(parsed, match[3] ?? "Z");
  if (utc == null || Number.isNaN(utc)) return null;
  return jstDateString(new Date(utc)) === japanDate;
}

function sumPoints(
  points: unknown[],
  japanDate: string,
  mode: "daily" | "hourly",
  fallbackCurrency: string,
): Metrics | "empty" | null {
  let total: Metrics | null = null;
  let saw = false;
  for (const point of points) {
    const included = inJapanDate(pointDate(point), japanDate, mode);
    if (included == null) return null;
    if (!included) continue;
    saw = true;
    const metrics = readMetrics(point, fallbackCurrency);
    if (metrics == null) return null;
    if (metrics === "empty") continue;
    total = total ? addMetrics(total, metrics) : metrics;
    if (total == null) return null;
  }
  if (!saw) return "empty";
  return total ?? zeroMetrics(fallbackCurrency);
}

function belongsToCalonavi(appName: string, campaignName: string): boolean {
  return calonaviName.test(appName) || calonaviName.test(campaignName);
}

function campaignFromRow(
  row: unknown,
  mode: "daily" | "hourly",
  japanDate: string,
  fallbackCurrency: string,
): CampaignMetrics | "skip" | null {
  if (!row || typeof row !== "object") return null;
  const record = row as Record<string, unknown>;
  const metadata = record.metadata && typeof record.metadata === "object"
    ? record.metadata as Record<string, unknown>
    : null;
  if (!metadata) return "skip";
  const campaignId = readId(metadata.campaignId);
  if (!campaignId) return "skip";
  const app = metadata.app && typeof metadata.app === "object" ? metadata.app as Record<string, unknown> : null;
  const appName = app && typeof app.appName === "string" ? app.appName : "";
  const rawName = typeof metadata.campaignName === "string" ? metadata.campaignName : "";
  if (!belongsToCalonavi(appName, rawName)) return "skip";
  const name = cleanText(rawName, 200) || "（名称なし）";
  const points = granularity(record);
  let metrics: Metrics | "empty" | null;
  if (mode === "hourly") {
    if (points.length === 0) metrics = "empty";
    else metrics = sumPoints(points, japanDate, mode, fallbackCurrency);
  } else if (points.length === 0) {
    metrics = readMetrics(record.total, fallbackCurrency);
  } else {
    metrics = sumPoints(points, japanDate, mode, fallbackCurrency);
    if (metrics === "empty") return null;
  }
  if (metrics == null) return null;
  const resolved = metrics === "empty" ? zeroMetrics(fallbackCurrency) : metrics;
  if (!resolved.currency) return null;
  return { ...resolved, campaignId, campaignName: name };
}

export function campaignsFromReport(
  rows: unknown[],
  mode: "daily" | "hourly",
  japanDate: string,
  fallbackCurrency: string,
): ParseFailure | ParseSuccess<CampaignMetrics> {
  const byId = new Map<string, CampaignMetrics>();
  for (const row of rows) {
    const parsed = campaignFromRow(row, mode, japanDate, fallbackCurrency);
    if (parsed == null) return { ok: false };
    if (parsed === "skip") continue;
    const existing = byId.get(parsed.campaignId);
    if (!existing) {
      byId.set(parsed.campaignId, parsed);
      continue;
    }
    const summed = addMetrics(existing, parsed);
    if (!summed) return { ok: false };
    byId.set(parsed.campaignId, { ...existing, ...summed });
  }
  return { ok: true, rows: [...byId.values()] };
}

function keywordFromRow(
  row: unknown,
  campaignId: string,
  mode: "daily" | "hourly",
  japanDate: string,
  fallbackCurrency: string,
): KeywordMetrics | "skip" | null {
  if (!row || typeof row !== "object") return null;
  const record = row as Record<string, unknown>;
  const metadata = record.metadata && typeof record.metadata === "object"
    ? record.metadata as Record<string, unknown>
    : null;
  if (!metadata) return "skip";
  const keywordId = readId(metadata.keywordId);
  const adGroupId = readId(metadata.adGroupId);
  if (!keywordId || !adGroupId) return "skip";
  const rawKeyword = typeof metadata.keyword === "string" ? metadata.keyword : "";
  const keyword = cleanText(rawKeyword, 200);
  if (!keyword) return "skip";
  const matchType = cleanText(typeof metadata.matchType === "string" ? metadata.matchType : "", 40) || "UNKNOWN";
  const adGroupName = cleanText(typeof metadata.adGroupName === "string" ? metadata.adGroupName : "", 200);
  const points = granularity(record);
  let metrics: Metrics | "empty" | null;
  if (mode === "hourly") {
    metrics = points.length === 0 ? "empty" : sumPoints(points, japanDate, mode, fallbackCurrency);
  } else if (points.length === 0) {
    metrics = readMetrics(record.total, fallbackCurrency);
  } else {
    metrics = sumPoints(points, japanDate, mode, fallbackCurrency);
    if (metrics === "empty") return null;
  }
  if (metrics == null) return null;
  const resolved = metrics === "empty" ? zeroMetrics(fallbackCurrency) : metrics;
  if (!resolved.currency) return null;
  if (resolved.impressions + resolved.taps + resolved.installs + resolved.spendCents === 0) return "skip";
  return {
    ...resolved,
    campaignId,
    adGroupId,
    adGroupName,
    keywordId,
    keyword,
    matchType,
  };
}

export function keywordsFromReport(
  rows: unknown[],
  campaignId: string,
  mode: "daily" | "hourly",
  japanDate: string,
  fallbackCurrency: string,
): ParseFailure | ParseSuccess<KeywordMetrics> {
  const byId = new Map<string, KeywordMetrics>();
  for (const row of rows) {
    const parsed = keywordFromRow(row, campaignId, mode, japanDate, fallbackCurrency);
    if (parsed == null) return { ok: false };
    if (parsed === "skip") continue;
    const key = `${parsed.adGroupId}:${parsed.keywordId}`;
    const existing = byId.get(key);
    if (!existing) {
      byId.set(key, parsed);
      continue;
    }
    const summed = addMetrics(existing, parsed);
    if (!summed) return { ok: false };
    byId.set(key, { ...existing, ...summed });
  }
  return { ok: true, rows: [...byId.values()] };
}

export function formatHeadingDate(isoDate: string): string {
  const [year, month, day] = isoDate.split("-").map(Number);
  const weekday = weekdays[new Date(Date.UTC(year, month - 1, day)).getUTCDay()];
  return `${month}/${day}（${weekday}）`;
}

function formatCount(value: number): string {
  return value.toLocaleString("ja-JP");
}

export function formatMoney(cents: number, currency: string): string {
  const sign = cents < 0 ? "-" : "";
  const absolute = Math.abs(cents);
  const whole = Math.trunc(absolute / 100);
  const fraction = absolute % 100;
  const grouped = whole.toLocaleString("ja-JP");
  const body = fraction === 0 ? grouped : `${grouped}.${String(fraction).padStart(2, "0")}`;
  if (currency === "JPY") return `${sign}¥${body}`;
  return `${sign}${body} ${currency}`;
}

export function formatCpa(metrics: Metrics): string {
  if (metrics.installs <= 0) return "—";
  return formatMoney(Math.round(metrics.spendCents / metrics.installs), metrics.currency);
}

function metricLine(label: string, metrics: Metrics): string {
  return [
    label,
    `支出額 ${formatMoney(metrics.spendCents, metrics.currency)}`,
    `表示回数 ${formatCount(metrics.impressions)}`,
    `タップ数 ${formatCount(metrics.taps)}`,
    `インストール数 ${formatCount(metrics.installs)}`,
    `CPA ${formatCpa(metrics)}`,
  ].join(" / ");
}

function matchLabel(matchType: string): string {
  if (matchType === "EXACT") return "完全一致";
  if (matchType === "BROAD") return "部分一致";
  return matchType;
}

function bySpendDesc<T extends Metrics>(rows: T[]): T[] {
  return [...rows].sort((left, right) => right.spendCents - left.spendCents || right.installs - left.installs);
}

function totalsByCurrency(rows: Metrics[]): Metrics[] {
  const byCurrency = new Map<string, Metrics>();
  for (const row of rows) {
    const existing = byCurrency.get(row.currency);
    if (!existing) {
      byCurrency.set(row.currency, { ...row });
      continue;
    }
    const summed = addMetrics(existing, row);
    if (summed) byCurrency.set(row.currency, summed);
  }
  return bySpendDesc([...byCurrency.values()]);
}

export function formatDailyMessage(day: DayReport): string {
  const campaigns = bySpendDesc(day.campaigns);
  const activeCampaigns = campaigns.filter((row) => row.impressions + row.taps + row.installs + row.spendCents > 0);
  const keywords = bySpendDesc(day.keywords);
  const totals = totalsByCurrency(campaigns);
  const shownKeywords = keywords.slice(0, 30);
  const hiddenKeywords = keywords.length - shownKeywords.length;
  const duplicateLabels = new Set<string>();
  const seenLabels = new Set<string>();
  for (const row of shownKeywords) {
    const label = `${row.keyword}（${matchLabel(row.matchType)}）`;
    if (seenLabels.has(label)) duplicateLabels.add(label);
    seenLabels.add(label);
  }
  const installFields = new Set(campaigns.map((row) => row.installField));
  const installNote = installFields.size === 1 && installFields.has("totalInstalls")
    ? "インストール数はタップ経由と閲覧経由の合計（totalInstalls）です。"
    : "インストール数は API の installs を含みます。totalInstalls がある行はそちらを使います。";
  const totalLines = totals.length === 0
    ? ["支出額 —", "表示回数 0", "タップ数 0", "インストール数 0", "CPA —"]
    : totals.length === 1
    ? [
      `支出額 ${formatMoney(totals[0].spendCents, totals[0].currency)}`,
      `表示回数 ${formatCount(totals[0].impressions)}`,
      `タップ数 ${formatCount(totals[0].taps)}`,
      `インストール数 ${formatCount(totals[0].installs)}`,
      `CPA ${formatCpa(totals[0])}`,
    ]
    : totals.map((row) => metricLine(row.currency, row));
  const campaignLines = activeCampaigns.length === 0
    ? ["配信のあるキャンペーンはありません。"]
    : activeCampaigns.map((row) => `・${metricLine(row.campaignName, row)}`);
  const keywordLines = shownKeywords.length === 0
    ? ["配信のあるキーワードはありません。"]
    : shownKeywords.map((row) => {
      const base = `${row.keyword}（${matchLabel(row.matchType)}）`;
      const label = duplicateLabels.has(base) && row.adGroupName ? `${base} / ${row.adGroupName}` : base;
      return `・${metricLine(label, row)}`;
    });
  if (hiddenKeywords > 0) keywordLines.push(`ほか ${formatCount(hiddenKeywords)} 件`);
  return [
    `📊 カロナビ Apple Ads｜${formatHeadingDate(day.dataDate)}分　_日本時間_`,
    "（日本時間の 0:00〜23:59。日付が終わって 6 時間後の数字）",
    "",
    "■ 合計",
    ...totalLines,
    "",
    "■ キャンペーン",
    ...campaignLines,
    "",
    "■ キーワード",
    ...keywordLines,
    "",
    installNote,
    "CPA は支出額 ÷ インストール数です。検索語句は含みません。",
  ].join("\n");
}

export function centsToAmount(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const absolute = Math.abs(cents);
  return `${sign}${Math.trunc(absolute / 100)}.${String(absolute % 100).padStart(2, "0")}`;
}

export function shouldRetryStatus(status: number): boolean {
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

export async function withBackoff<T extends { status: number }>(
  run: () => Promise<T>,
  backoff: Backoff,
): Promise<T> {
  let wait = backoff.initialMs;
  let last = await run();
  for (let attempt = 1; attempt < backoff.maxAttempts; attempt++) {
    if (!shouldRetryStatus(last.status)) return last;
    await backoff.sleep(wait);
    wait *= 2;
    last = await run();
  }
  return last;
}
