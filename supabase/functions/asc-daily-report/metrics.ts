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

/// 除外は kpi.excluded_user_ids / excluded_install_ids と同じ。件数だけを返す。
export function countAppActivity(input: {
  events: ActivityEvent[];
  notices: TrialNotice[];
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
  const registrations = new Set(
    events.filter((event) =>
      event.name === "login_result" &&
      event.props.result === "success" &&
      propTrue(event.props.is_new_account) &&
      event.userId &&
      inWindow(event.occurredAt, startMs, endMs)
    ).map((event) => event.userId),
  );
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
    registrations: registrations.size,
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
  activity: AppActivity;
  previous: CombinedDeltas | null;
  week: CombinedDeltas | null;
  nonJpyCustomerRows: number;
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

function line(label: string, point: CountPoint, previous: CountPoint | null, week: CountPoint | null, format?: (value: number) => string): string {
  const value = point.state === "present" && point.value != null
    ? (format ? format(point.value) : point.value.toLocaleString("en-US"))
    : "データなし";
  const day = previous
    ? formatSide("前日", point.value, point.state, previous.value, previous.state)
    : "前日 —";
  const lastWeek = week
    ? formatSide("前週", point.value, point.state, week.value, week.state)
    : "前週 —";
  return `${label} ${value}（${day} / ${lastWeek}）`;
}

function durationText(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  const hours = Math.floor(minutes / 60);
  return `${hours}時間${minutes % 60}分`;
}

function activityLine(label: string, today: number, previous: number | null, week: number | null): string {
  const day = previous == null ? "前日 —" : `前日 ${formatSigned(today - previous)}`;
  const lastWeek = week == null ? "前週 —" : `前週 ${formatSigned(today - week)}`;
  return `${label} ${today.toLocaleString("en-US")}（${day} / ${lastWeek}）`;
}

export function formatCombinedMessage(view: CombinedView): string {
  const period = japanPeriodForPacificReport(view.reportDate);
  const conversionOf = (
    pages: CountPoint | null | undefined,
    downloads: CountPoint | null | undefined,
  ) => {
    if (!pages || !downloads) return null;
    return pageViewConversion(pages.value, pages.state, downloads.value, downloads.state);
  };
  const conversion = conversionOf(view.pageViews, view.newDownloads)!;
  const previousConversion = conversionOf(view.previous?.pageViews, view.previous?.newDownloads);
  const weekConversion = conversionOf(view.week?.pageViews, view.week?.newDownloads);
  const planLines = view.plans.map((plan) =>
    `${plan.label} 有効 ${plan.paid.toLocaleString("en-US")} / トライアル中 ${plan.trials.toLocaleString("en-US")}`
  );
  const crashLines = view.crashTotal.state !== "present"
    ? ["データなし"]
    : [
      `合計 ${displayCount(view.crashTotal.state, view.crashTotal.value)}`,
      ...(view.crashesByVersion ?? []).map((row) => `バージョン ${row.key} ${row.crashes.toLocaleString("en-US")}`),
      ...(view.crashesByDevice ?? []).map((row) => `端末 ${row.key} ${row.crashes.toLocaleString("en-US")}`),
    ];
  const average = view.averageRating == null ? "—" : `★${view.averageRating.toFixed(1)}`;
  const activity = view.activity;
  const previousActivity = view.previous?.activity ?? null;
  const weekActivity = view.week?.activity ?? null;
  return [
    `📊 カロナビ日次レポート｜${period}${view.correction ? "　訂正" : ""}`,
    "Appleの日付は太平洋時間です。米国の夏時間の間は日本時間の16:00区切り、終わったあとは17:00区切りです。ファイルが届くまで約3日かかります。",
    "アプリ内の数は、見出しの開始から終了までの範囲です。社長・審査員・削除済みは除いています。",
    "利用者が少ないなどの理由で Apple のレポートが無い日は、0ではなく「データなし」です。",
    ...(view.correction ? ["前回の投稿を、届いたファイルで上書きしました。"] : []),
    "",
    "■ 獲得",
    line("新規DL", view.newDownloads, view.previous?.newDownloads ?? null, view.week?.newDownloads ?? null),
    line("再DL", view.redownloads, view.previous?.redownloads ?? null, view.week?.redownloads ?? null),
    line("売上", view.salesCents, view.previous?.salesCents ?? null, view.week?.salesCents ?? null, formatYenFromCents),
    line("手取り", view.proceedsCents, view.previous?.proceedsCents ?? null, view.week?.proceedsCents ?? null, formatYenFromCents),
    "売上は顧客通貨が JPY の行だけ、手取りは受取通貨が JPY の行だけです。",
    view.nonJpyCustomerRows > 0 ? `円以外の顧客通貨の行が ${view.nonJpyCustomerRows} 件あります。円にはしていません。` : "",
    "",
    "■ 集客",
    line("表示回数", view.impressions, view.previous?.impressions ?? null, view.week?.impressions ?? null),
    line("ページ閲覧", view.pageViews, view.previous?.pageViews ?? null, view.week?.pageViews ?? null),
    `検索 ${displayCount(view.sourceSearch.state, view.sourceSearch.value)}`,
    "検索の表示回数には広告が含まれます。広告だけの数は分かれて出ません。",
    `その他 ${displayCount(view.sourceOther.state, view.sourceOther.value)}`,
    `転換率 ${formatRate(conversion.state, conversion.rate)}（ページ閲覧→新規DL / 前日 ${
      previousConversion ? formatRate(previousConversion.state, previousConversion.rate) : "—"
    } / 前週 ${weekConversion ? formatRate(weekConversion.state, weekConversion.rate) : "—"}）`,
    "表示からページ、ページからDLは一つのファネルにしていません。直接・広告・リンクの訪問は表示を通りません。",
    "",
    "■ インストールと削除",
    line("インストール", view.installs, view.previous?.installs ?? null, view.week?.installs ?? null),
    line("アンインストール", view.uninstalls, view.previous?.uninstalls ?? null, view.week?.uninstalls ?? null),
    "",
    "■ Appleの起動",
    line("起動回数", view.appleSessions, view.previous?.appleSessions ?? null, view.week?.appleSessions ?? null),
    line("合計利用時間", view.appleDurationSeconds, null, null, durationText),
    line("利用端末数", view.uniqueDevices, null, null),
    "利用端末数は行ごとの数を足しています。同じ端末が複数行にあると重なります。",
    "",
    "■ クラッシュ",
    ...crashLines,
    "",
    "■ 課金",
    ...planLines,
    line("トライアル開始", view.appleTrialStarts, null, null),
    line("有料への切り替え", view.paidConversions, null, null),
    line("解約", view.cancellations, null, null),
    activityLine(
      "トライアル開始（ストア通知）",
      activity.trialStarts,
      previousActivity?.trialStarts ?? null,
      weekActivity?.trialStarts ?? null,
    ),
    "ストア通知の無料トライアル開始だけを数えます。アプリの購入成功の数は使いません。",
    "",
    "■ レビュー",
    `本文つき ${view.reviewCount}件 / 平均 ${average}`,
    `★5 ${view.stars[4]}　★4 ${view.stars[3]}　★3 ${view.stars[2]}　★2 ${view.stars[1]}　★1 ${view.stars[0]}`,
    view.excerpt ? `「${view.excerpt}」` : "",
    "本文のない★だけの評価は API に含まれません。レビューの日付は日本時間の暦日です。",
    "",
    "■ アプリ内",
    activityLine("初回起動", activity.firstOpens, previousActivity?.firstOpens ?? null, weekActivity?.firstOpens ?? null),
    `うち ASA ${activity.firstOpensAsa.toLocaleString("en-US")} / それ以外 ${activity.firstOpensOther.toLocaleString("en-US")} / 判定なし ${activity.firstOpensUnknown.toLocaleString("en-US")}`,
    activityLine("登録", activity.registrations, previousActivity?.registrations ?? null, weekActivity?.registrations ?? null),
    activityLine(
      "初回設定完了",
      activity.onboardingCompletes,
      previousActivity?.onboardingCompletes ?? null,
      weekActivity?.onboardingCompletes ?? null,
    ),
    activityLine("初めての食事記録", activity.firstMeals, previousActivity?.firstMeals ?? null, weekActivity?.firstMeals ?? null),
    activityLine(
      "課金画面を開いた人数",
      activity.paywallOpeners,
      previousActivity?.paywallOpeners ?? null,
      weekActivity?.paywallOpeners ?? null,
    ),
    activityLine("セッション", activity.sessions, previousActivity?.sessions ?? null, weekActivity?.sessions ?? null),
    `利用時間 ${durationText(activity.sessionDurationSeconds)}`,
    activityLine("検索", activity.searches, previousActivity?.searches ?? null, weekActivity?.searches ?? null),
    activityLine("Siri", activity.siriUses, previousActivity?.siriUses ?? null, weekActivity?.siriUses ?? null),
    activityLine("ウィジェット", activity.widgetUses, previousActivity?.widgetUses ?? null, weekActivity?.widgetUses ?? null),
  ].filter((row) => row !== "").join("\n");
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
    reviewCount: view.reviewCount,
    averageRating: view.averageRating,
    stars: view.stars,
    activity: view.activity,
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
    charts: {
      downloads: { new: view.newDownloads.value, re: view.redownloads.value },
      acquisition: {
        impressions: view.impressions.value,
        page_views: view.pageViews.value,
        new_downloads: view.newDownloads.value,
      },
      first_opens: {
        asa: view.activity.firstOpensAsa,
        other: view.activity.firstOpensOther,
        unknown: view.activity.firstOpensUnknown,
      },
      plans: view.plans,
      crashes_by_version: view.crashesByVersion,
    },
    lines: text.split("\n"),
  };
}
