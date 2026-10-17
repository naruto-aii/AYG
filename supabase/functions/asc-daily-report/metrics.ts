// 日次レポートに足す数。秘密も個人の識別子も受け取らない。
// アプリ内の集計 SQL（kpi.collect_app_activity）と同じ規則。

import {
  analyticsRowsFor,
  cell,
  fileDecision,
  flashReady,
  formatYenFromCents,
  japanPeriodForPacificReport,
  nextClaim,
  numberCell,
  type AnalyticsInstance,
  type FileState,
  type StoredPost,
} from "./parse.ts";

/// Apple Search Ads で数えるキャンペーン。社長の指定。
export const asaCampaignId = "2144888758";

export type MetricState = "present" | "absent" | "pending";

export type ReportKind = "discovery" | "downloads" | "installs" | "sessions" | "crashes";

/// standard だけ。detailed と、別用途の Sessions Context は使わない。
export function reportKind(name: string): ReportKind | null {
  const normalized = name.trim().toLowerCase();
  if (normalized.includes("detailed") || normalized.includes("web preview")) return null;
  if (normalized.includes("discovery") && normalized.includes("engagement")) return "discovery";
  if (normalized.includes("installation") && normalized.includes("deletion")) return "installs";
  if (normalized.includes("crash")) return "crashes";
  if (
    normalized.includes("session") &&
    !normalized.includes("context") &&
    !normalized.includes("clip")
  ) {
    return "sessions";
  }
  if (normalized.includes("download") && !normalized.includes("discovery")) return "downloads";
  return null;
}

export function preferStandardReport<T extends { name: string }>(rows: T[], kind: ReportKind): T | null {
  const matches = rows.filter((row) => reportKind(row.name) === kind);
  if (matches.length === 0) return null;
  return matches.find((row) => row.name.toLowerCase().includes("standard")) ?? matches[0];
}

export type ProcessedInstance = {
  processingDate: string;
  rowCountForDate: number;
};

/// その日の行があれば present。より新しい処理日のファイルだけがあり行が無いときは absent。
/// ファイルがまだ無いときは pending。期限が来ただけでは absent にも 0 にもしない。
export function usageState(instances: ProcessedInstance[] | null, reportDate: string): MetricState {
  if (!instances || instances.length === 0) return "pending";
  if (instances.some((instance) => instance.rowCountForDate > 0)) return "present";
  const processed = instances.some((instance) => instance.processingDate >= reportDate);
  return processed ? "absent" : "pending";
}

export function classifyUsage(
  instances: AnalyticsInstance[] | null,
  reportDate: string,
  appAppleId: string,
): { state: MetricState; rows: Record<string, string>[] } {
  if (!instances || instances.length === 0) return { state: "pending", rows: [] };
  const processed = instances.map((instance) => ({
    processingDate: instance.processingDate,
    rowCountForDate: analyticsRowsFor(instance, reportDate, appAppleId).length,
  }));
  const state = usageState(processed, reportDate);
  if (state !== "present") return { state, rows: [] };
  const sorted = [...instances].sort((left, right) => left.processingDate.localeCompare(right.processingDate));
  let rows: Record<string, string>[] = [];
  for (const instance of sorted) {
    const matched = analyticsRowsFor(instance, reportDate, appAppleId);
    if (matched.length > 0) rows = matched;
  }
  return { state, rows };
}

export function summarizeInstalls(rows: Record<string, string>[]): { installs: number; uninstalls: number } {
  let installs = 0;
  let uninstalls = 0;
  for (const row of rows) {
    const event = cell(row, "Event").trim().toLowerCase();
    const counts = numberCell(row, "Counts");
    if (event === "install" || event === "installation") installs += counts;
    if (event === "delete" || event === "deletion") uninstalls += counts;
  }
  return { installs, uninstalls };
}

export function summarizeAppleSessions(rows: Record<string, string>[]): {
  sessions: number;
  durationSeconds: number;
  uniqueDevices: number;
} {
  let sessions = 0;
  let durationSeconds = 0;
  let uniqueDevices = 0;
  for (const row of rows) {
    sessions += numberCell(row, "Sessions");
    durationSeconds += numberCell(row, "Total Session Duration");
    uniqueDevices += numberCell(row, "Unique Devices");
  }
  return { sessions, durationSeconds, uniqueDevices };
}

export function summarizeCrashes(rows: Record<string, string>[]): {
  total: number;
  byVersion: CrashLine[];
  byDevice: CrashLine[];
} {
  let total = 0;
  const versions = new Map<string, number>();
  const devices = new Map<string, number>();
  for (const row of rows) {
    const crashes = numberCell(row, "Crashes");
    total += crashes;
    const version = cell(row, "App Version").trim() || "不明";
    const device = cell(row, "Device").trim() || "不明";
    versions.set(version, (versions.get(version) ?? 0) + crashes);
    devices.set(device, (devices.get(device) ?? 0) + crashes);
  }
  const top = (source: Map<string, number>) =>
    [...source.entries()]
      .map(([key, crashes]) => ({ key, crashes }))
      .sort((left, right) => right.crashes - left.crashes || left.key.localeCompare(right.key))
      .slice(0, 8);
  return { total, byVersion: top(versions), byDevice: top(devices) };
}

export function displayCount(state: MetricState, value: number | null): string {
  if (state !== "present" || value == null) return "データなし";
  return value.toLocaleString("en-US");
}

/// ページ閲覧から新規DL。表示回数は分母にしない。片方でもデータが無ければ率もデータなし。
export function pageViewConversion(
  pageViews: number | null,
  pageState: MetricState,
  newDownloads: number | null,
  downloadState: MetricState,
): { state: MetricState; rate: number | null } {
  if (pageState !== "present" || downloadState !== "present") {
    return { state: pageState === "pending" || downloadState === "pending" ? "pending" : "absent", rate: null };
  }
  if (pageViews == null || newDownloads == null || pageViews <= 0) {
    return { state: "present", rate: null };
  }
  return { state: "present", rate: Math.round((newDownloads / pageViews) * 10000) / 10000 };
}

export function formatRate(state: MetricState, rate: number | null): string {
  if (state !== "present") return "データなし";
  if (rate == null) return "—";
  return `${(Math.round(rate * 1000) / 10).toFixed(1)}%`;
}

export function formatSigned(value: number): string {
  if (value > 0) return `+${value.toLocaleString("en-US")}`;
  return value.toLocaleString("en-US");
}

/// どちらかがデータなしなら差もデータなし。0 とは書かない。
export function formatSide(
  label: string,
  today: number | null,
  todayState: MetricState,
  other: number | null,
  otherState: MetricState,
): string {
  if (todayState !== "present" || otherState !== "present" || today == null || other == null) {
    return `${label} データなし`;
  }
  return `${label} ${formatSigned(today - other)}`;
}

export type ActivityEvent = {
  name: string;
  occurredAt: string;
  userId: string | null;
  installId: string | null;
  props: Record<string, unknown>;
};

export type TrialNotice = {
  userId: string | null;
  originalTransactionId: string | null;
  notificationUuid: string;
  notificationType: string;
  subtype: string | null;
  environment: string;
  verificationStatus: string;
  offerDiscountType: string | null;
  offerType: number | null;
  priceMilliunits: number | null;
  signedAt: string;
};

export type AppActivity = {
  firstOpens: number;
  firstOpensAsa: number;
  firstOpensOther: number;
  firstOpensUnknown: number;
  registrations: number;
  onboardingCompletes: number;
  firstMeals: number;
  paywallOpeners: number;
  trialStarts: number;
  sessions: number;
  sessionDurationSeconds: number;
  searches: number;
  siriUses: number;
  widgetUses: number;
};

function inWindow(iso: string, startMs: number, endMs: number): boolean {
  const value = Date.parse(iso);
  return !Number.isNaN(value) && value >= startMs && value < endMs;
}

function kept(
  event: ActivityEvent,
  excludedUsers: ReadonlySet<string>,
  excludedInstalls: ReadonlySet<string>,
): boolean {
  if (event.userId && excludedUsers.has(event.userId)) return false;
  if (event.installId && excludedInstalls.has(event.installId)) return false;
  return true;
}

function propTrue(value: unknown): boolean {
  return value === true || value === "true";
}

function isAsa(props: Record<string, unknown>): boolean {
  return propTrue(props.attribution) && String(props.campaign_id ?? "") === asaCampaignId;
}

function isFreeTrial(notice: TrialNotice): boolean {
  const discount = (notice.offerDiscountType ?? "").toUpperCase();
  if (discount === "FREE_TRIAL") return true;
  if (discount === "PAY_AS_YOU_GO" || discount === "PAY_UP_FRONT") return false;
  return notice.offerType === 1 && notice.priceMilliunits === 0;
}

function isInitialBuy(notice: TrialNotice): boolean {
  return notice.notificationType === "INITIAL_BUY" || notice.subtype === "INITIAL_BUY";
}

/// auth.users の作成。profiles には作成時刻が無い。
export type CreatedAccount = {
  userId: string;
  createdAt: string;
  deleted: boolean;
  anonymous?: boolean;
  installIds?: readonly string[];
};

/// 除外は kpi.excluded_user_ids / excluded_install_ids と同じ。件数だけを返す。
export function countAppActivity(input: {
  events: ActivityEvent[];
  notices: TrialNotice[];
  accounts: readonly CreatedAccount[];
  onboardingCompleteUsers: ReadonlySet<string>;
  excludedUserIds: readonly string[];
  excludedInstallIds: readonly string[];
  start: Date;
  end: Date;
}): AppActivity {
  const excludedUsers = new Set(input.excludedUserIds);
  const excludedInstalls = new Set(input.excludedInstallIds);
  const startMs = input.start.getTime();
  const endMs = input.end.getTime();
  const events = input.events.filter((event) => kept(event, excludedUsers, excludedInstalls));
  const opens = events.filter((event) =>
    event.name === "app_install_first_open" && inWindow(event.occurredAt, startMs, endMs)
  );
  const adsByInstall = new Map<string, { asa: boolean }>();
  for (const event of events) {
    if (event.name !== "apple_ads_attribution" || !event.installId) continue;
    const current = adsByInstall.get(event.installId) ?? { asa: false };
    if (isAsa(event.props)) current.asa = true;
    adsByInstall.set(event.installId, current);
  }
  let asa = 0;
  let other = 0;
  let unknown = 0;
  for (const open of opens) {
    const ads = open.installId ? adsByInstall.get(open.installId) : undefined;
    if (!ads) unknown += 1;
    else if (ads.asa) asa += 1;
    else other += 1;
  }
  const excludedInstallList = input.excludedInstallIds;
  let registrations = 0;
  for (const account of input.accounts) {
    if (account.deleted || account.anonymous) continue;
    if (!account.userId || excludedUsers.has(account.userId)) continue;
    if ((account.installIds ?? []).some((installId) => excludedInstallList.includes(installId))) continue;
    if (!inWindow(account.createdAt, startMs, endMs)) continue;
    registrations += 1;
  }
  const firstAt = (name: string) => {
    const earliest = new Map<string, number>();
    for (const event of events) {
      if (event.name !== name || !event.userId) continue;
      const at = Date.parse(event.occurredAt);
      if (Number.isNaN(at)) continue;
      const prev = earliest.get(event.userId);
      if (prev == null || at < prev) earliest.set(event.userId, at);
    }
    return earliest;
  };
  let onboardingCompletes = 0;
  for (const [userId, at] of firstAt("onboarding_complete")) {
    if (at >= startMs && at < endMs && input.onboardingCompleteUsers.has(userId)) onboardingCompletes += 1;
  }
  let firstMeals = 0;
  for (const at of firstAt("food_entry_added").values()) {
    if (at >= startMs && at < endMs) firstMeals += 1;
  }
  const paywallOpeners = new Set(
    events.filter((event) =>
      event.name === "paywall_open" && event.userId && inWindow(event.occurredAt, startMs, endMs)
    ).map((event) => event.userId),
  );
  const trials = new Set<string>();
  for (const notice of input.notices) {
    if (notice.verificationStatus !== "verified" || notice.environment !== "Production") continue;
    if (!isInitialBuy(notice) || !isFreeTrial(notice)) continue;
    if (notice.userId && excludedUsers.has(notice.userId)) continue;
    if (!inWindow(notice.signedAt, startMs, endMs)) continue;
    trials.add(notice.originalTransactionId || notice.notificationUuid);
  }
  let sessionDurationSeconds = 0;
  for (const event of events) {
    if (event.name !== "session_end" || !inWindow(event.occurredAt, startMs, endMs)) continue;
    const raw = event.props.duration_seconds;
    const value = typeof raw === "number" ? raw : Number(raw);
    if (Number.isFinite(value) && value >= 0) sessionDurationSeconds += value;
  }
  const countName = (names: readonly string[]) =>
    events.filter((event) => names.includes(event.name) && inWindow(event.occurredAt, startMs, endMs)).length;
  return {
    firstOpens: opens.length,
    firstOpensAsa: asa,
    firstOpensOther: other,
    firstOpensUnknown: unknown,
    registrations,
    onboardingCompletes,
    firstMeals,
    paywallOpeners: paywallOpeners.size,
    trialStarts: trials.size,
    sessions: countName(["session_start"]),
    sessionDurationSeconds: Math.round(sessionDurationSeconds),
    searches: countName(["food_search", "exercise_search"]),
    siriUses: countName(["siri_request_started", "siri_registration_imported", "siri_open_search"]),
    widgetUses: countName(["widget_tap", "widget_registration_imported"]),
  };
}

export type CountPoint = { state: MetricState; value: number | null };

export type PlanLine = { label: string; paid: number; trials: number };

export type CrashLine = { key: string; crashes: number };

export type CombinedView = {
  reportDate: string;
  correction: boolean;
  publishable: boolean;
  newDownloads: CountPoint;
  redownloads: CountPoint;
  salesCents: CountPoint;
  proceedsCents: CountPoint;
  impressions: CountPoint;
  pageViews: CountPoint;
  sourceSearch: CountPoint;
  sourceOther: CountPoint;
  installs: CountPoint;
  uninstalls: CountPoint;
  appleSessions: CountPoint;
  appleDurationSeconds: CountPoint;
  uniqueDevices: CountPoint;
  crashTotal: CountPoint;
  crashesByVersion: CrashLine[] | null;
  crashesByDevice: CrashLine[] | null;
  plans: PlanLine[];
  appleTrialStarts: CountPoint;
  paidConversions: CountPoint;
  cancellations: CountPoint;
  reviewCount: number;
  averageRating: number | null;
  stars: [number, number, number, number, number];
  excerpt: string;
  reviewsReady: boolean;
  activity: AppActivity;
  previous: CombinedDeltas | null;
  week: CombinedDeltas | null;
  nonJpyCustomerRows: number;
  series: TrendDay[];
};

export type TrendDay = {
  reportDate: string;
  label: string;
  newDownloads: number | null;
  redownloads: number | null;
  impressions: number | null;
  pageViews: number | null;
  conversion: number | null;
  firstOpensAsa: number;
  firstOpensOther: number;
  firstOpensUnknown: number;
  firstOpens: number;
  onboardingCompletes: number;
  firstMeals: number;
  paywallOpeners: number;
  sessions: number;
  sessionDurationSeconds: number;
};

export type MetricRow = {
  section: string;
  metric: string;
  today: string;
  day: string;
  week: string;
};

export type SummaryCard = {
  label: string;
  value: string;
  delta: string;
};

export type CombinedDeltas = {
  newDownloads: CountPoint | null;
  redownloads: CountPoint | null;
  salesCents: CountPoint | null;
  proceedsCents: CountPoint | null;
  impressions: CountPoint | null;
  pageViews: CountPoint | null;
  installs: CountPoint | null;
  uninstalls: CountPoint | null;
  appleSessions: CountPoint | null;
  activity: AppActivity | null;
};

export function salesPoint(decision: "rows" | "zero" | "hold", value: number): CountPoint {
  if (decision === "hold") return { state: "pending", value: null };
  return { state: "present", value };
}

/// 売上・購読・イベントが確定し、表示とページ閲覧のファイルが present か absent のときだけ投稿する。
/// 新しい利用状況レポートが pending でも投稿は止めない。その欄はデータなし。
export function combinedPublishable(input: {
  sales: "rows" | "zero" | "hold";
  subscription: "rows" | "zero" | "hold";
  events: "rows" | "zero" | "hold";
  reviewsReady: boolean;
  hasParentSku: boolean;
  discovery: MetricState;
  downloads: MetricState;
}): boolean {
  if (!flashReady(input.sales, input.subscription, input.events)) return false;
  if (!input.reviewsReady || !input.hasParentSku) return false;
  return input.discovery !== "pending" && input.downloads !== "pending";
}

export function fileHold(state: FileState, rows: number, laterProductRows: number): "rows" | "zero" | "hold" {
  return fileDecision({ state, rows }, laterProductRows);
}

function durationText(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  const hours = Math.floor(minutes / 60);
  return `${hours}時間${minutes % 60}分`;
}

function shown(point: CountPoint, format?: (value: number) => string): string {
  if (point.state !== "present" || point.value == null) return "データなし";
  return format ? format(point.value) : point.value.toLocaleString("en-US");
}

function delta(today: number | null, todayState: MetricState, previous: number | null, previousState: MetricState | null): string {
  if (todayState !== "present" || previousState !== "present" || today == null || previous == null) return "—";
  return formatSigned(today - previous);
}

function activityDelta(today: number, previous: number | null): string {
  if (previous == null) return "—";
  return formatSigned(today - previous);
}

function durationDelta(today: number, previous: number | null): string {
  if (previous == null) return "—";
  const gap = today - previous;
  if (gap === 0) return "0";
  const sign = gap > 0 ? "+" : "-";
  return sign + durationText(Math.abs(gap));
}

function row(section: string, metric: string, today: string, day: string, week: string): MetricRow {
  return { section, metric, today, day, week };
}

function pointRow(
  section: string,
  metric: string,
  point: CountPoint,
  previous: CountPoint | null,
  week: CountPoint | null,
  format?: (value: number) => string,
): MetricRow {
  return row(
    section,
    metric,
    shown(point, format),
    delta(point.value, point.state, previous?.value ?? null, previous?.state ?? null),
    delta(point.value, point.state, week?.value ?? null, week?.state ?? null),
  );
}

function countRow(section: string, metric: string, today: number, previous: number | null, week: number | null, format?: (value: number) => string): MetricRow {
  return row(
    section,
    metric,
    format ? format(today) : today.toLocaleString("en-US"),
    activityDelta(today, previous),
    activityDelta(today, week),
  );
}

export function reportNotes(view: CombinedView): string[] {
  const notes = [
    "Appleの日付は太平洋時間です。米国の夏時間の間は日本時間の16:00区切り、終わったあとは17:00区切りです。ファイルが届くまで約3日かかります。",
    "アプリ内の数は、見出しの開始から終了までです。社長・審査員・削除済みは除いています。",
    "登録は、その時間に作られたアカウントです。削除済みは除きます。",
    "Appleのレポートが無い日は、0ではなく「データなし」です。",
    "転換率はページ閲覧から新規DLです。表示・ページ閲覧・新規DLは一つのファネルにしていません。直接・広告・リンクの訪問は表示を通りません。",
    "検索の表示回数には広告が含まれます。広告だけの数は分かれて出ません。",
    "売上は顧客通貨が JPY の行だけ、手取りは受取通貨が JPY の行だけです。",
    "利用端末数は行ごとの合計です。同じ端末が複数行にあると重なります。",
    "トライアル開始はストア通知の無料トライアルだけです。アプリの購入成功は使いません。",
    "本文のない星だけの評価は API に含まれません。レビューの日付は日本時間の暦日です。",
    "利用時間は session_end に記録された秒数の合計です。",
  ];
  if (view.nonJpyCustomerRows > 0) {
    notes.push(`円以外の顧客通貨の行が ${view.nonJpyCustomerRows.toLocaleString("en-US")} 件あります。円にはしていません。`);
  }
  return notes;
}

export function metricRows(view: CombinedView): MetricRow[] {
  const activity = view.activity;
  const previous = view.previous?.activity ?? null;
  const week = view.week?.activity ?? null;
  const conversion = pageViewConversion(
    view.pageViews.value,
    view.pageViews.state,
    view.newDownloads.value,
    view.newDownloads.state,
  );
  const previousConversion = view.previous
    ? pageViewConversion(
      view.previous.pageViews?.value ?? null,
      view.previous.pageViews?.state ?? "pending",
      view.previous.newDownloads?.value ?? null,
      view.previous.newDownloads?.state ?? "pending",
    )
    : null;
  const weekConversion = view.week
    ? pageViewConversion(
      view.week.pageViews?.value ?? null,
      view.week.pageViews?.state ?? "pending",
      view.week.newDownloads?.value ?? null,
      view.week.newDownloads?.state ?? "pending",
    )
    : null;
  const conversionToday = formatRate(conversion.state, conversion.rate);
  const conversionDay = previousConversion && conversion.rate != null && previousConversion.rate != null
    ? formatSigned(Math.round((conversion.rate - previousConversion.rate) * 1000) / 10) + "pt"
    : "—";
  const conversionWeek = weekConversion && conversion.rate != null && weekConversion.rate != null
    ? formatSigned(Math.round((conversion.rate - weekConversion.rate) * 1000) / 10) + "pt"
    : "—";
  const planRows = view.plans.length === 0
    ? [row("課金", "プラン別", "データなし", "—", "—")]
    : view.plans.flatMap((plan) => [
      row("課金", `${plan.label} 有効`, plan.paid.toLocaleString("en-US"), "—", "—"),
      row("課金", `${plan.label} トライアル中`, plan.trials.toLocaleString("en-US"), "—", "—"),
    ]);
  const crashRows = view.crashTotal.state !== "present"
    ? [pointRow("クラッシュ", "合計", view.crashTotal, null, null)]
    : [
      pointRow("クラッシュ", "合計", view.crashTotal, null, null),
      ...(view.crashesByVersion ?? []).map((line) => row("クラッシュ", `バージョン ${line.key}`, line.crashes.toLocaleString("en-US"), "—", "—")),
      ...(view.crashesByDevice ?? []).map((line) => row("クラッシュ", `端末 ${line.key}`, line.crashes.toLocaleString("en-US"), "—", "—")),
    ];
  const reviewToday = view.reviewsReady
    ? `${view.reviewCount.toLocaleString("en-US")}件 / ${view.averageRating == null ? "—" : `★${view.averageRating.toFixed(1)}`}`
    : "データなし";
  return [
    pointRow("獲得", "新規DL", view.newDownloads, view.previous?.newDownloads ?? null, view.week?.newDownloads ?? null),
    pointRow("獲得", "再DL", view.redownloads, view.previous?.redownloads ?? null, view.week?.redownloads ?? null),
    pointRow("獲得", "売上", view.salesCents, view.previous?.salesCents ?? null, view.week?.salesCents ?? null, formatYenFromCents),
    pointRow("獲得", "手取り", view.proceedsCents, view.previous?.proceedsCents ?? null, view.week?.proceedsCents ?? null, formatYenFromCents),
    pointRow("集客", "表示回数", view.impressions, view.previous?.impressions ?? null, view.week?.impressions ?? null),
    pointRow("集客", "ページ閲覧", view.pageViews, view.previous?.pageViews ?? null, view.week?.pageViews ?? null),
    pointRow("集客", "検索", view.sourceSearch, null, null),
    pointRow("集客", "その他", view.sourceOther, null, null),
    row("集客", "転換率", conversionToday, conversionDay, conversionWeek),
    pointRow("インストール", "インストール", view.installs, view.previous?.installs ?? null, view.week?.installs ?? null),
    pointRow("インストール", "アンインストール", view.uninstalls, view.previous?.uninstalls ?? null, view.week?.uninstalls ?? null),
    pointRow("Appleの起動", "起動回数", view.appleSessions, view.previous?.appleSessions ?? null, view.week?.appleSessions ?? null),
    pointRow("Appleの起動", "合計利用時間", view.appleDurationSeconds, null, null, durationText),
    pointRow("Appleの起動", "利用端末数", view.uniqueDevices, null, null),
    ...crashRows,
    ...planRows,
    pointRow("課金", "トライアル開始（Apple）", view.appleTrialStarts, null, null),
    pointRow("課金", "有料への切り替え", view.paidConversions, null, null),
    pointRow("課金", "解約", view.cancellations, null, null),
    countRow("課金", "トライアル開始", activity.trialStarts, previous?.trialStarts ?? null, week?.trialStarts ?? null),
    row("レビュー", "本文つき", reviewToday, "—", "—"),
    countRow("アプリ内", "初回起動", activity.firstOpens, previous?.firstOpens ?? null, week?.firstOpens ?? null),
    countRow("アプリ内", "うち ASA", activity.firstOpensAsa, previous?.firstOpensAsa ?? null, week?.firstOpensAsa ?? null),
    countRow("アプリ内", "うち それ以外", activity.firstOpensOther, previous?.firstOpensOther ?? null, week?.firstOpensOther ?? null),
    countRow("アプリ内", "うち 判定なし", activity.firstOpensUnknown, previous?.firstOpensUnknown ?? null, week?.firstOpensUnknown ?? null),
    countRow("アプリ内", "登録", activity.registrations, previous?.registrations ?? null, week?.registrations ?? null),
    countRow("アプリ内", "初回設定完了", activity.onboardingCompletes, previous?.onboardingCompletes ?? null, week?.onboardingCompletes ?? null),
    countRow("アプリ内", "初めての食事記録", activity.firstMeals, previous?.firstMeals ?? null, week?.firstMeals ?? null),
    countRow("アプリ内", "課金画面を開いた人数", activity.paywallOpeners, previous?.paywallOpeners ?? null, week?.paywallOpeners ?? null),
    countRow("アプリ内", "セッション", activity.sessions, previous?.sessions ?? null, week?.sessions ?? null),
    row(
      "アプリ内",
      "利用時間",
      durationText(activity.sessionDurationSeconds),
      durationDelta(activity.sessionDurationSeconds, previous?.sessionDurationSeconds ?? null),
      durationDelta(activity.sessionDurationSeconds, week?.sessionDurationSeconds ?? null),
    ),
    countRow("アプリ内", "検索", activity.searches, previous?.searches ?? null, week?.searches ?? null),
    countRow("アプリ内", "Siri", activity.siriUses, previous?.siriUses ?? null, week?.siriUses ?? null),
    countRow("アプリ内", "ウィジェット", activity.widgetUses, previous?.widgetUses ?? null, week?.widgetUses ?? null),
  ];
}

function moveSentence(label: string, today: number, previous: number, view: CombinedView): string {
  const change = `前日 ${formatSigned(today - previous)}`;
  if (label === "初回起動") {
    return `初回起動は ${previous.toLocaleString("en-US")} から ${today.toLocaleString("en-US")}（${change}、ASA ${view.activity.firstOpensAsa.toLocaleString("en-US")}）。`;
  }
  return `${label}は ${previous.toLocaleString("en-US")} から ${today.toLocaleString("en-US")}（${change}）。`;
}

export function summaryLines(view: CombinedView): string[] {
  const previous = view.previous?.activity ?? null;
  const ranked: Array<{ label: string; today: number; previous: number | null; rank: number }> = [
    { label: "初回起動", today: view.activity.firstOpens, previous: previous?.firstOpens ?? null, rank: 0 },
    { label: "登録", today: view.activity.registrations, previous: previous?.registrations ?? null, rank: 1 },
    { label: "初回設定完了", today: view.activity.onboardingCompletes, previous: previous?.onboardingCompletes ?? null, rank: 2 },
    { label: "初めての食事記録", today: view.activity.firstMeals, previous: previous?.firstMeals ?? null, rank: 3 },
    { label: "トライアル開始", today: view.activity.trialStarts, previous: previous?.trialStarts ?? null, rank: 4 },
  ];
  const changed = ranked
    .filter((item): item is { label: string; today: number; previous: number; rank: number } => item.previous != null)
    .sort((left, right) => {
      const gap = Math.abs(right.today - right.previous) - Math.abs(left.today - left.previous);
      if (gap !== 0) return gap;
      return left.rank - right.rank;
    });
  const body: string[] = [];
  if (view.newDownloads.state === "present" && view.newDownloads.value != null) {
    const redownload = view.redownloads.state === "present" && view.redownloads.value != null
      ? `、再DL ${view.redownloads.value.toLocaleString("en-US")}`
      : "";
    const sales = view.salesCents.state === "present" && view.salesCents.value != null
      ? `売上は ${formatYenFromCents(view.salesCents.value)}。`
      : "売上はデータなし。";
    body.push(`新規DL ${view.newDownloads.value.toLocaleString("en-US")}${redownload}。${sales}`);
  }
  if (changed[0]) body.push(moveSentence(changed[0].label, changed[0].today, changed[0].previous, view));
  if (changed[1]) body.push(moveSentence(changed[1].label, changed[1].today, changed[1].previous, view));
  const rest = changed.slice(2, 4);
  if (rest.length > 0) {
    body.push(rest.map((item) =>
      `${item.label} ${item.today.toLocaleString("en-US")}（前日 ${formatSigned(item.today - item.previous)}）`
    ).join("、") + "。");
  }
  const missing = [
    view.newDownloads.state === "present" ? "" : "新規DL",
    view.salesCents.state === "present" ? "" : "売上",
  ].filter((label) => label.length > 0);
  if (missing.length > 0 && !body.some((line) => line.includes("データなし"))) {
    body.push(`${missing.join("と")}はデータなし。`);
  }
  return [...body.slice(0, 4), "詳細はPDFです。"];
}

export function summaryCards(view: CombinedView): SummaryCard[] {
  const previous = view.previous;
  const activity = view.activity;
  const previousActivity = previous?.activity ?? null;
  return [
    {
      label: "新規DL",
      value: shown(view.newDownloads),
      delta: `前日 ${delta(view.newDownloads.value, view.newDownloads.state, previous?.newDownloads?.value ?? null, previous?.newDownloads?.state ?? null)}`,
    },
    {
      label: "初回起動",
      value: activity.firstOpens.toLocaleString("en-US"),
      delta: `前日 ${activityDelta(activity.firstOpens, previousActivity?.firstOpens ?? null)}`,
    },
    {
      label: "初回設定完了",
      value: activity.onboardingCompletes.toLocaleString("en-US"),
      delta: `前日 ${activityDelta(activity.onboardingCompletes, previousActivity?.onboardingCompletes ?? null)}`,
    },
    {
      label: "初めての食事記録",
      value: activity.firstMeals.toLocaleString("en-US"),
      delta: `前日 ${activityDelta(activity.firstMeals, previousActivity?.firstMeals ?? null)}`,
    },
    {
      label: "トライアル開始",
      value: activity.trialStarts.toLocaleString("en-US"),
      delta: `前日 ${activityDelta(activity.trialStarts, previousActivity?.trialStarts ?? null)}`,
    },
    {
      label: "売上",
      value: shown(view.salesCents, formatYenFromCents),
      delta: `前日 ${delta(view.salesCents.value, view.salesCents.state, previous?.salesCents?.value ?? null, previous?.salesCents?.state ?? null)}`,
    },
  ];
}

export function formatCombinedMessage(view: CombinedView): string {
  const period = japanPeriodForPacificReport(view.reportDate);
  const heading = `📊 カロナビ日次レポート｜${period}${view.correction ? "　訂正" : ""}`;
  const correction = view.correction ? ["届いたファイルで、前回の投稿を訂正しました。"] : [];
  const cards = summaryCards(view).map((card) => `${card.label} ${card.value}（${card.delta}）`);
  return [heading, ...correction, ...summaryLines(view), "", ...cards].join("\n");
}

export function canonicalSnapshot(view: CombinedView): string {
  return JSON.stringify({
    newDownloads: view.newDownloads,
    redownloads: view.redownloads,
    salesCents: view.salesCents,
    proceedsCents: view.proceedsCents,
    impressions: view.impressions,
    pageViews: view.pageViews,
    sourceSearch: view.sourceSearch,
    sourceOther: view.sourceOther,
    installs: view.installs,
    uninstalls: view.uninstalls,
    appleSessions: view.appleSessions,
    appleDurationSeconds: view.appleDurationSeconds,
    uniqueDevices: view.uniqueDevices,
    crashTotal: view.crashTotal,
    crashesByVersion: view.crashesByVersion,
    crashesByDevice: view.crashesByDevice,
    plans: view.plans,
    appleTrialStarts: view.appleTrialStarts,
    paidConversions: view.paidConversions,
    cancellations: view.cancellations,
    reviewCount: view.reviewsReady ? view.reviewCount : null,
    averageRating: view.reviewsReady ? view.averageRating : null,
    stars: view.reviewsReady ? view.stars : null,
    activity: view.activity,
    series: view.series,
  });
}

export async function snapshotHash(view: CombinedView): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonicalSnapshot(view)));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/// 投稿済みで中身が同じ日は出さない。予約中の30分と失敗後の待ちも、今の仕組みのまま残す。
export function deliveryDecision(
  post: (StoredPost & { contentHash: string | null }) | null,
  nowMs: number,
  contentHash: string,
  revisingAllowed: boolean,
): "skip" | "claim" | "revise" {
  if (post?.status === "posted") {
    if (revisingAllowed && post.contentHash !== contentHash) return "revise";
    return "skip";
  }
  return nextClaim(post, nowMs).action === "skip" ? "skip" : "claim";
}

export function reportPayload(view: CombinedView): Record<string, unknown> {
  const text = formatCombinedMessage(view);
  return {
    heading: text.split("\n")[0],
    slack_text: text,
    summary: summaryLines(view),
    cards: summaryCards(view),
    series: view.series.map((day) => ({
      label: day.label,
      new_downloads: day.newDownloads,
      redownloads: day.redownloads,
      impressions: day.impressions,
      page_views: day.pageViews,
      conversion: day.conversion,
      asa: day.firstOpensAsa,
      other: day.firstOpensOther,
      unknown: day.firstOpensUnknown,
      first_opens: day.firstOpens,
      onboarding: day.onboardingCompletes,
      meals: day.firstMeals,
      paywall: day.paywallOpeners,
      sessions: day.sessions,
      duration_minutes: Math.round(day.sessionDurationSeconds / 60),
    })),
    table: metricRows(view),
    notes: reportNotes(view),
  };
}
