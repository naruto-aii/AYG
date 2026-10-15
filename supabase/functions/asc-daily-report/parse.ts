// App Store Connect の日次ファイルを、Slack に出す数へまとめる。
// 秘密は受け取らない。レビューのニックネームは残さない。

export type Backoff = {
  initialMs: number;
  maxAttempts: number;
  sleep: (ms: number) => Promise<void>;
};

export type SalesSummary = {
  newDownloads: number;
  redownloads: number;
  salesCents: number;
  proceedsCents: number;
  nonJpyCustomerRows: number;
};

export type PlanName = "monthly" | "half_year" | "yearly" | "other";

export type PlanSummary = {
  plan: PlanName;
  activePaid: number;
  activeTrials: number;
};

export type EventSummary = {
  trialStarts: number;
  paidConversions: number;
  cancellations: number;
};

export type ReviewInput = {
  rating: number;
  title: string;
  body: string;
  createdDate: string;
};

export type ReviewSummary = {
  reviewCount: number;
  averageRating: number | null;
  stars: [number, number, number, number, number];
  excerpt: string;
};

export type AnalyticsSummary = {
  impressions: number;
  productPageViews: number;
  sourceSearch: number;
  sourceOther: number;
  downloads: number;
  conversionRate: number | null;
  searchIncludesAds: true;
};

export type Availability = "ready" | "empty" | "missing" | "retry";

const newDownloadTypes = new Set(["1", "1-b", "1e", "1ep", "1eu", "1f", "1t", "f1", "f1-b"]);
const redownloadTypes = new Set(["3", "3f"]);

const paidActiveColumns = [
  "Active Standard Price Subscriptions",
  "Active Pay Up Front Introductory Offer Subscriptions",
  "Active Pay as You Go Introductory Offer Subscriptions",
  "Pay Up Front Promotional Offer Subscriptions",
  "Pay As You Go Promotional Offer Subscriptions",
  "Pay Up Front Offer Code Subscriptions",
  "Pay As You Go Offer Code Subscriptions",
  "Pay Up Front Win-Back Offers",
  "Pay As You Go Win-Back Offers",
];

const trialColumns = [
  "Active Free Trial Introductory Offer Subscriptions",
  "Free Trial Promotional Offer Subscriptions",
  "Free Trial Offer Code Subscriptions",
  "Free Trial Win-Back Offers",
];

const trialStartEvents = new Set([
  "start introductory offer",
  "start introductory price",
]);

const trialConversionEvents = new Set([
  "paid subscription from introductory offer",
  "paid subscription from introductory price",
  "crossgrade from introductory offer",
  "downgrade from introductory offer",
  "upgrade from introductory offer",
]);

const cancelEvents = new Set([
  "cancel",
  "canceled from billing retry",
  "canceled from billing grace period",
  "canceled after renewal extension",
]);

const planOrder: PlanName[] = ["monthly", "half_year", "yearly"];

const weekdays = ["日", "月", "火", "水", "木", "金", "土"];

export function normalizeHeader(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

export function cell(row: Record<string, string>, name: string): string {
  const want = normalizeHeader(name);
  for (const [key, value] of Object.entries(row)) {
    if (normalizeHeader(key) === want) return value ?? "";
  }
  return "";
}

function hasCell(row: Record<string, string>, name: string): boolean {
  const want = normalizeHeader(name);
  return Object.keys(row).some((key) => normalizeHeader(key) === want);
}

export function numberCell(row: Record<string, string>, name: string): number {
  const raw = cell(row, name).replaceAll(",", "").trim();
  if (!raw) return 0;
  const value = Number(raw);
  return Number.isFinite(value) ? value : 0;
}

function firstNumber(row: Record<string, string>, names: string[]): number {
  for (const name of names) {
    if (hasCell(row, name)) return numberCell(row, name);
  }
  return 0;
}

export function moneyCents(price: number, units: number): number {
  return Math.round(price * 100 * units);
}

/// 返金行は Customer Price と Units がどちらも負で、Developer Proceeds は正。
/// 売上は単価の大きさに数量の符号だけを掛ける。両方の負を掛けると返金が売上に足される。
export function salesCents(price: number, units: number): number {
  const direction = units < 0 ? -1 : 1;
  return Math.round(Math.abs(price) * 100 * Math.abs(units)) * direction;
}

/// reserved のまま finish まで届かなかった行を、この時間が過ぎたら取り直す。
export const reservationLeaseMs = 30 * 60 * 1000;

export function classifyUnavailable(status: number, body: string): Availability {
  if (status >= 200 && status < 300) return "ready";
  if (status === 404) {
    const text = body.toLowerCase();
    if (
      text.includes("no sales") ||
      text.includes("none were found") ||
      text.includes("there were no")
    ) {
      return "empty";
    }
    return "missing";
  }
  if (status === 429 || status >= 500) return "retry";
  return "missing";
}

export async function withBackoff<T extends { status: number }>(
  run: () => Promise<T>,
  backoff: Backoff,
): Promise<T> {
  let wait = backoff.initialMs;
  let last = await run();
  for (let attempt = 1; attempt < backoff.maxAttempts; attempt++) {
    if (classifyUnavailable(last.status, "") !== "retry") return last;
    await backoff.sleep(wait);
    wait *= 2;
    last = await run();
  }
  return last;
}

export async function postWithBackoff(
  send: () => Promise<number>,
  backoff: Backoff,
): Promise<boolean> {
  const result = await withBackoff(async () => ({ status: await send() }), backoff);
  return result.status >= 200 && result.status < 300;
}

export function claimBackoffMs(attempt: number): number {
  const exponent = Math.min(Math.max(attempt - 1, 0), 6);
  return Math.min(30 * 60 * 1000, 30_000 * 2 ** exponent);
}

export type StoredPost = {
  status: "reserved" | "posted" | "failed";
  attempt: number;
  updatedAtMs: number;
};

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

export function pacificDateString(instant: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Los_Angeles",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const pick = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return `${pick("year")}-${pick("month")}-${pick("day")}`;
}

export function addDays(isoDate: string, days: number): string {
  const [year, month, day] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

export function monthStart(isoDate: string): string {
  return `${isoDate.slice(0, 7)}-01`;
}

export function candidateFlashDates(now: Date): string[] {
  const today = pacificDateString(now);
  const dates: string[] = [];
  for (let ago = 14; ago >= 1; ago--) dates.push(addDays(today, -ago));
  return dates;
}

/// Discovery は 3 日以内に揃う、と Apple が書いている。それより新しい日は待たせる。
export function candidateAcquisitionDates(now: Date): string[] {
  const today = pacificDateString(now);
  const dates: string[] = [];
  for (let ago = 14; ago >= 3; ago--) dates.push(addDays(today, -ago));
  return dates;
}

export function formatHeadingDate(isoDate: string): string {
  const [year, month, day] = isoDate.split("-").map(Number);
  const weekday = weekdays[new Date(Date.UTC(year, month - 1, day)).getUTCDay()];
  return `${month}/${day}（${weekday}）`;
}

function sameId(value: string, appAppleId: string): boolean {
  return value.trim() !== "" && value.trim() === appAppleId.trim();
}

function appSkus(rows: Record<string, string>[], appAppleId: string): Set<string> {
  const skus = new Set<string>();
  for (const row of rows) {
    if (!sameId(cell(row, "Apple Identifier"), appAppleId)) continue;
    const sku = cell(row, "SKU").trim();
    if (sku) skus.add(sku);
  }
  return skus;
}

/// アプリ行（Apple Identifier がアプリの Apple ID）の SKU。アプリ内課金の行は含めない。
export function observedParentSkus(rows: Record<string, string>[], appAppleId: string): string[] {
  return [...appSkus(rows, appAppleId)];
}

/// 同じ実行の残りの日付からも見えるよう、見つけた SKU をその場で足す。
export function addParentSkus(known: string[], seen: readonly string[]): void {
  for (const sku of seen) {
    const trimmed = sku.trim();
    if (trimmed && !known.includes(trimmed)) known.push(trimmed);
  }
}

/// Parent Identifier は親アプリの SKU。Apple ID とは比べない。
/// knownParentSkus は保存済みの SKU と、この実行で既に見た SKU。アプリ行が無い日も使う。
function salesRowForApp(
  row: Record<string, string>,
  appAppleId: string,
  skus: Set<string>,
): boolean {
  if (sameId(cell(row, "Apple Identifier"), appAppleId)) return true;
  const parent = cell(row, "Parent Identifier").trim();
  return parent !== "" && skus.has(parent);
}

export function aggregateSales(
  rows: Record<string, string>[],
  appAppleId: string,
  knownParentSkus: readonly string[] = [],
): SalesSummary {
  const summary: SalesSummary = {
    newDownloads: 0,
    redownloads: 0,
    salesCents: 0,
    proceedsCents: 0,
    nonJpyCustomerRows: 0,
  };
  const skus = appSkus(rows, appAppleId);
  for (const sku of knownParentSkus) {
    const trimmed = sku.trim();
    if (trimmed) skus.add(trimmed);
  }
  for (const row of rows) {
    if (!salesRowForApp(row, appAppleId, skus)) continue;
    const units = numberCell(row, "Units");
    const productType = cell(row, "Product Type Identifier").trim().toLowerCase();
    if (newDownloadTypes.has(productType)) summary.newDownloads += units;
    if (redownloadTypes.has(productType)) summary.redownloads += units;
    const customerCurrency = cell(row, "Customer Currency").trim().toUpperCase();
    const proceedsCurrency = cell(row, "Currency of Proceeds").trim().toUpperCase();
    const price = firstNumber(row, ["Customer Price"]);
    const proceeds = firstNumber(row, ["Developer Proceeds", "Developer Proceeds (per unit)"]);
    if (customerCurrency === "JPY") summary.salesCents += salesCents(price, units);
    else if (units !== 0) summary.nonJpyCustomerRows += 1;
    if (proceedsCurrency === "JPY") summary.proceedsCents += moneyCents(proceeds, units);
  }
  return summary;
}

function planOf(duration: string): PlanName {
  switch (duration.trim().toLowerCase()) {
    case "1 month":
      return "monthly";
    case "6 months":
      return "half_year";
    case "1 year":
      return "yearly";
    default:
      return "other";
  }
}

function sumNamed(row: Record<string, string>, names: string[]): number {
  return names.reduce((total, name) => total + numberCell(row, name), 0);
}

export function aggregateSubscription(
  rows: Record<string, string>[],
  appAppleId: string,
): PlanSummary[] {
  const totals = new Map<PlanName, PlanSummary>();
  for (const row of rows) {
    if (!sameId(cell(row, "App Apple ID"), appAppleId)) continue;
    const plan = planOf(cell(row, "Standard Subscription Duration"));
    const current = totals.get(plan) ?? { plan, activePaid: 0, activeTrials: 0 };
    current.activePaid += sumNamed(row, paidActiveColumns);
    current.activeTrials += sumNamed(row, trialColumns);
    totals.set(plan, current);
  }
  return [...totals.values()];
}

export function fillPlans(plans: PlanSummary[]): PlanSummary[] {
  const byName = new Map(plans.map((plan) => [plan.plan, plan]));
  const filled = planOrder.map((plan) => byName.get(plan) ?? { plan, activePaid: 0, activeTrials: 0 });
  const other = byName.get("other");
  if (other && (other.activePaid > 0 || other.activeTrials > 0)) filled.push(other);
  return filled;
}

function offerType(row: Record<string, string>): string {
  return (cell(row, "Subscription Offer Type") || cell(row, "Introductory Price Type")).trim().toLowerCase();
}

export function aggregateEvents(rows: Record<string, string>[], appAppleId: string): EventSummary {
  const summary: EventSummary = { trialStarts: 0, paidConversions: 0, cancellations: 0 };
  for (const row of rows) {
    if (!sameId(cell(row, "App Apple ID"), appAppleId)) continue;
    const event = cell(row, "Event").trim().toLowerCase();
    const quantity = numberCell(row, "Quantity");
    const freeTrial = offerType(row) === "free trial";
    if (trialStartEvents.has(event) && freeTrial) summary.trialStarts += quantity;
    if (trialConversionEvents.has(event) && freeTrial) summary.paidConversions += quantity;
    if (cancelEvents.has(event)) summary.cancellations += quantity;
  }
  return summary;
}

export function oneLineExcerpt(body: string, title: string): string {
  const source = body.trim() || title.trim();
  const line = source.split(/\r?\n/).map((part) => part.trim()).find((part) => part.length > 0) ?? "";
  const redacted = line.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "…");
  const safe = redacted.replaceAll("<", "＜").replaceAll(">", "＞").replaceAll("&", "＆");
  const chars = Array.from(safe);
  if (chars.length <= 80) return chars.join("");
  return `${chars.slice(0, 80).join("")}…`;
}

export function summarizeReviews(reviews: ReviewInput[], dataDate: string): ReviewSummary {
  const stars: [number, number, number, number, number] = [0, 0, 0, 0, 0];
  const matched = reviews.filter((review) => {
    const instant = new Date(review.createdDate);
    return !Number.isNaN(instant.getTime()) && pacificDateString(instant) === dataDate;
  }).sort((left, right) => new Date(right.createdDate).getTime() - new Date(left.createdDate).getTime());
  for (const review of matched) {
    const rating = Math.round(review.rating);
    if (rating >= 1 && rating <= 5) stars[rating - 1] += 1;
  }
  const reviewCount = stars.reduce((total, count) => total + count, 0);
  let excerpt = "";
  for (const review of matched) {
    const line = oneLineExcerpt(review.body, review.title);
    if (line) {
      excerpt = line;
      break;
    }
  }
  return {
    reviewCount,
    averageRating: averageRating(stars),
    stars,
    excerpt,
  };
}

function averageRating(stars: [number, number, number, number, number]): number | null {
  const count = stars.reduce((total, value) => total + value, 0);
  if (count === 0) return null;
  const weighted = stars.reduce((total, value, index) => total + value * (index + 1), 0);
  return Math.round((weighted / count) * 10) / 10;
}

export type AnalyticsInstance = {
  processingDate: string;
  rows: Record<string, string>[];
};

export function latestRowsForDate(
  instances: AnalyticsInstance[],
  dataDate: string,
  appAppleId: string,
): Record<string, string>[] | null {
  const sorted = [...instances].sort((left, right) => left.processingDate.localeCompare(right.processingDate));
  let found: Record<string, string>[] | null = null;
  for (const instance of sorted) {
    const rows = instance.rows.filter((row) =>
      cell(row, "Date") === dataDate && sameId(cell(row, "App Apple Identifier"), appAppleId)
    );
    if (rows.length > 0) found = rows;
  }
  return found;
}

export function summarizeDiscovery(rows: Record<string, string>[]): {
  impressions: number;
  productPageViews: number;
  sourceSearch: number;
  sourceOther: number;
} {
  let impressions = 0;
  let productPageViews = 0;
  let sourceSearch = 0;
  let sourceOther = 0;
  for (const row of rows) {
    const event = cell(row, "Event").trim().toLowerCase();
    const counts = numberCell(row, "Counts");
    if (event === "impression") {
      impressions += counts;
      if (cell(row, "Source Type").trim().toLowerCase() === "app store search") sourceSearch += counts;
      else sourceOther += counts;
    }
    if (event === "page view" && cell(row, "Page Type").trim().toLowerCase() === "product page") {
      productPageViews += counts;
    }
  }
  return { impressions, productPageViews, sourceSearch, sourceOther };
}

export function summarizeDownloads(rows: Record<string, string>[]): number {
  let downloads = 0;
  for (const row of rows) {
    const kind = cell(row, "Download Type").trim().toLowerCase();
    if (kind === "first-time download" || kind === "redownload") {
      downloads += numberCell(row, "Counts");
    }
  }
  return downloads;
}

export function buildAnalytics(
  discovery: ReturnType<typeof summarizeDiscovery>,
  downloads: number,
): AnalyticsSummary {
  const conversionRate = discovery.impressions === 0
    ? null
    : Math.round((downloads / discovery.impressions) * 10000) / 10000;
  return {
    impressions: discovery.impressions,
    productPageViews: discovery.productPageViews,
    sourceSearch: discovery.sourceSearch,
    sourceOther: discovery.sourceOther,
    downloads,
    conversionRate,
    searchIncludesAds: true,
  };
}

export function formatYenFromCents(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const absolute = Math.abs(cents);
  const whole = Math.trunc(absolute / 100);
  const fraction = absolute % 100;
  const grouped = whole.toLocaleString("en-US");
  if (fraction === 0) return `${sign}¥${grouped}`;
  return `${sign}¥${grouped}.${String(fraction).padStart(2, "0")}`;
}

export function formatDelta(
  today: number,
  previous: number | null,
  format: (value: number) => string = (value) => String(value),
): string {
  if (previous == null) return "前日 —";
  const diff = today - previous;
  if (diff > 0) return `前日 +${format(diff)}`;
  return `前日 ${format(diff)}`;
}

export function formatPercent(rate: number | null): string {
  if (rate == null) return "—";
  return `${(Math.round(rate * 1000) / 10).toFixed(1)}%`;
}

export function flashComment(input: {
  newDownloads: number;
  previousNewDownloads: number | null;
  trialStarts: number;
  paidConversions: number;
  cancellations: number;
  reviewCount: number;
  averageRating: number | null;
}): string {
  if (input.reviewCount > 0 && input.averageRating != null && input.averageRating <= 2) {
    return "低評価の本文つきレビューが来ています。";
  }
  if (
    input.cancellations > 0 &&
    input.cancellations >= input.trialStarts &&
    input.cancellations >= input.paidConversions
  ) {
    return "解約が、トライアル開始と有料への切り替え以上です。";
  }
  const previous = input.previousNewDownloads;
  if (previous != null && input.newDownloads - previous >= 3 && input.newDownloads >= previous * 1.5) {
    return "新規DLが前日よりかなり増えています。";
  }
  if (previous != null && previous - input.newDownloads >= 3 && input.newDownloads * 2 <= previous) {
    return "新規DLが前日より減っています。";
  }
  if (input.trialStarts > 0 && input.paidConversions > 0) {
    return "トライアル開始と、有料への切り替えが両方あります。";
  }
  if (input.trialStarts > 0) return "トライアル開始がありました。";
  if (input.paidConversions > 0) return "有料への切り替えがありました。";
  if (
    input.newDownloads === 0 &&
    input.reviewCount === 0 &&
    input.trialStarts === 0 &&
    input.paidConversions === 0 &&
    input.cancellations === 0
  ) {
    return "大きな動きはありません。";
  }
  return "数字は上の通りです。";
}

const planLabels: Record<PlanName, string> = {
  monthly: "月額",
  half_year: "半年",
  yearly: "年額",
  other: "その他",
};

export type FlashView = {
  dataDate: string;
  sales: SalesSummary;
  plans: PlanSummary[];
  events: EventSummary;
  reviews: ReviewSummary;
  previousSales: SalesSummary | null;
  previousPlans: PlanSummary[];
  previousEvents: EventSummary | null;
  previousReviewCount: number | null;
  monthSales: SalesSummary;
  monthEvents: EventSummary;
  monthReviewCount: number;
  salesConfirmed?: boolean;
};

function monthLine(today: number, previous: number | null, month: number, format?: (value: number) => string): string {
  const value = format ? format(today) : String(today);
  const delta = formatDelta(today, previous, format);
  const total = format ? format(month) : String(month);
  return `${value}（${delta} / 今月 ${total}）`;
}

export function formatFlashMessage(view: FlashView): string {
  const date = formatHeadingDate(view.dataDate);
  const salesLines = view.salesConfirmed === false
    ? [
      `新規DL ${monthLine(view.sales.newDownloads, view.previousSales?.newDownloads ?? null, view.monthSales.newDownloads)}`,
      `再DL ${monthLine(view.sales.redownloads, view.previousSales?.redownloads ?? null, view.monthSales.redownloads)}`,
      "売上未確定",
      "手取り未確定",
      "親 SKU がまだ無いので、円は確定していません。",
    ]
    : [
      `新規DL ${monthLine(view.sales.newDownloads, view.previousSales?.newDownloads ?? null, view.monthSales.newDownloads)}`,
      `再DL ${monthLine(view.sales.redownloads, view.previousSales?.redownloads ?? null, view.monthSales.redownloads)}`,
      `売上 ${monthLine(view.sales.salesCents, view.previousSales?.salesCents ?? null, view.monthSales.salesCents, formatYenFromCents)}`,
      `手取り ${monthLine(view.sales.proceedsCents, view.previousSales?.proceedsCents ?? null, view.monthSales.proceedsCents, formatYenFromCents)}`,
      "売上は顧客通貨が JPY の行だけ、手取りは受取通貨が JPY の行だけです。他の通貨は円にしていません。",
    ];
  const planLines = view.plans.map((plan) => {
    const previous = view.previousPlans.find((row) => row.plan === plan.plan) ?? null;
    const paidDelta = formatDelta(plan.activePaid, previous ? previous.activePaid : null);
    const trialDelta = formatDelta(plan.activeTrials, previous ? previous.activeTrials : null);
    return `${planLabels[plan.plan]} 有効 ${plan.activePaid}（${paidDelta}） / トライアル中 ${plan.activeTrials}（${trialDelta}）`;
  });
  const eventLines = [
    `トライアル開始 ${monthLine(view.events.trialStarts, view.previousEvents?.trialStarts ?? null, view.monthEvents.trialStarts)}`,
    `有料への切り替え ${monthLine(view.events.paidConversions, view.previousEvents?.paidConversions ?? null, view.monthEvents.paidConversions)}`,
    `解約 ${monthLine(view.events.cancellations, view.previousEvents?.cancellations ?? null, view.monthEvents.cancellations)}`,
  ];
  const average = view.reviews.averageRating == null ? "—" : `★${view.reviews.averageRating.toFixed(1)}`;
  const reviewLines = [
    `本文つき ${view.reviews.reviewCount}件（${formatDelta(view.reviews.reviewCount, view.previousReviewCount)} / 今月 ${view.monthReviewCount}件） / 平均 ${average}`,
    `★5 ${view.reviews.stars[4]}　★4 ${view.reviews.stars[3]}　★3 ${view.reviews.stars[2]}　★2 ${view.reviews.stars[1]}　★1 ${view.reviews.stars[0]}`,
  ];
  if (view.reviews.excerpt) reviewLines.push(`「${view.reviews.excerpt}」`);
  reviewLines.push("本文のない★だけの評価は API に含まれません。");
  const comment = flashComment({
    newDownloads: view.sales.newDownloads,
    previousNewDownloads: view.previousSales?.newDownloads ?? null,
    trialStarts: view.events.trialStarts,
    paidConversions: view.events.paidConversions,
    cancellations: view.events.cancellations,
    reviewCount: view.reviews.reviewCount,
    averageRating: view.reviews.averageRating,
  });
  return [
    `📊 カロナビ日次レポート｜${date}分　_太平洋時間の暦日_`,
    "（App Store の集計日。太平洋時間の 0:00〜23:59）",
    "",
    "■ 獲得",
    ...salesLines,
    "",
    "■ 課金",
    ...planLines,
    ...eventLines,
    "",
    "■ レビュー",
    ...reviewLines,
    "",
    "■ ひとこと",
    comment,
  ].join("\n");
}

export function formatAcquisitionMessage(input: {
  dataDate: string;
  today: AnalyticsSummary;
  previous: AnalyticsSummary | null;
}): string {
  const date = formatHeadingDate(input.dataDate);
  const impressions = formatDelta(input.today.impressions, input.previous?.impressions ?? null);
  const pages = formatDelta(input.today.productPageViews, input.previous?.productPageViews ?? null);
  const conversion = formatPercent(input.today.conversionRate);
  const previousConversion = input.previous ? formatPercent(input.previous.conversionRate) : null;
  const conversionDelta = previousConversion == null ? "前日 —" : `前日 ${previousConversion}`;
  return [
    `📈 カロナビ集客｜${date}分　_太平洋時間の暦日_`,
    "（Analytics。集計日の 3 日後以降に、出ている日だけ投稿）",
    "",
    `表示回数 ${input.today.impressions.toLocaleString("en-US")}（${impressions}）`,
    `製品ページ閲覧 ${input.today.productPageViews.toLocaleString("en-US")}（${pages}）`,
    `流入（表示回数） 検索 ${input.today.sourceSearch.toLocaleString("en-US")}（広告を含む） / 広告 検索と分かれて出ない / その他 ${input.today.sourceOther.toLocaleString("en-US")}`,
    `転換率 ${conversion}（総ダウンロード ÷ 表示回数、${conversionDelta}）`,
  ].join("\n");
}

export function ongoingAnalyticsRequestBody(appAppleId: string): Record<string, unknown> {
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

export function planOngoingAnalyticsRequest(
  requests: Array<{ accessType: string; stoppedDueToInactivity?: boolean }>,
): "create" | "exists" | "stopped" {
  const ongoing = requests.filter((row) => row.accessType === "ONGOING");
  if (ongoing.length === 0) return "create";
  if (ongoing.every((row) => row.stoppedDueToInactivity)) return "stopped";
  return "exists";
}

/// 定期実行からは呼ばない。社長が管理者鍵の使用を承認したあと、手で使う。
export async function createOngoingAnalyticsRequest(deps: {
  listRequests: () => Promise<Array<{ accessType: string; stoppedDueToInactivity?: boolean }>>;
  create: (body: unknown) => Promise<{ status: number }>;
  appAppleId: string;
}): Promise<{ action: "exists" | "stopped" | "created" | "failed"; status?: number }> {
  const plan = planOngoingAnalyticsRequest(await deps.listRequests());
  if (plan === "exists") return { action: "exists" };
  if (plan === "stopped") return { action: "stopped" };
  const response = await deps.create(ongoingAnalyticsRequestBody(deps.appAppleId));
  if (response.status >= 200 && response.status < 300) {
    return { action: "created", status: response.status };
  }
  return { action: "failed", status: response.status };
}
