import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  countAppActivity,
  combinedPublishable,
  deliveryDecision,
  displayCount,
  fileHold,
  formatCombinedMessage,
  formatRate,
  pageViewConversion,
  preferStandardReport,
  reportKind,
  usageState,
  type ActivityEvent,
  type AppActivity,
  type CombinedView,
  type CountPoint,
  type TrialNotice,
} from "./asc-daily-report/metrics.ts";
import { japanPeriodForPacificReport, pacificReportBounds, reservationLeaseMs } from "./asc-daily-report/parse.ts";

Deno.test("太平洋時間の区切りは夏時間の16時と、11月2日以降の17時で切り替わる", () => {
  assertEquals(
    japanPeriodForPacificReport("2026-10-15"),
    "10/15 16:00〜10/16 16:00（日本時間）",
  );
  assertEquals(
    japanPeriodForPacificReport("2026-10-16"),
    "10/16 16:00〜10/17 16:00（日本時間）",
  );
  assertEquals(
    japanPeriodForPacificReport("2026-11-01"),
    "11/1 16:00〜11/2 17:00（日本時間）",
  );
  assertEquals(
    japanPeriodForPacificReport("2026-11-02"),
    "11/2 17:00〜11/3 17:00（日本時間）",
  );
  const summer = pacificReportBounds("2026-10-15");
  const winter = pacificReportBounds("2026-11-02");
  assertEquals(summer.end.getTime() - summer.start.getTime(), 24 * 60 * 60 * 1000);
  assertEquals(winter.end.getTime() - winter.start.getTime(), 24 * 60 * 60 * 1000);
  assertEquals(summer.start.toISOString(), "2026-10-15T07:00:00.000Z");
  assertEquals(winter.start.toISOString(), "2026-11-02T08:00:00.000Z");
});

Deno.test("空の返事や0件は、より新しい日に製品行があるときだけ0と確定する", () => {
  assertEquals(fileHold("missing", 0, 0), "hold");
  assertEquals(fileHold("missing", 0, 9), "hold");
  assertEquals(fileHold("empty", 0, 0), "hold");
  assertEquals(fileHold("ready", 0, 0), "hold");
  assertEquals(fileHold("empty", 0, 3), "zero");
  assertEquals(fileHold("ready", 0, 3), "zero");
  assertEquals(fileHold("ready", 4, 0), "rows");
});

Deno.test("利用状況レポートが無い日はデータなしで、0にはしない", () => {
  assertEquals(usageState(null, "2026-10-15"), "pending");
  assertEquals(usageState([], "2026-10-15"), "pending");
  assertEquals(
    usageState([{ processingDate: "2026-10-14", rowCountForDate: 0 }], "2026-10-15"),
    "pending",
  );
  assertEquals(
    usageState([{ processingDate: "2026-10-16", rowCountForDate: 0 }], "2026-10-15"),
    "absent",
  );
  assertEquals(
    usageState([{ processingDate: "2026-10-15", rowCountForDate: 0 }], "2026-10-15"),
    "absent",
  );
  assertEquals(
    usageState([{ processingDate: "2026-10-15", rowCountForDate: 2 }], "2026-10-15"),
    "present",
  );
  assertEquals(displayCount("absent", null), "データなし");
  assertEquals(displayCount("pending", null), "データなし");
  assertEquals(displayCount("present", 0), "0");
  const text = formatCombinedMessage(view({
    installs: pending(),
    uninstalls: pending(),
  }));
  assertEquals(text.includes("インストール データなし"), true);
  assertEquals(text.includes("アンインストール データなし"), true);
  assertEquals(text.includes("インストール 0"), false);
});

Deno.test("転換率はページ閲覧から新規DLで、表示回数は分母にしない", () => {
  const rate = pageViewConversion(40, "present", 10, "present");
  assertEquals(rate.rate, 0.25);
  assertEquals(formatRate(rate.state, rate.rate), "25.0%");
  const impressionsWouldBe = 10 / 200;
  assertEquals(rate.rate === impressionsWouldBe, false);
  assertEquals(pageViewConversion(null, "absent", 10, "present").rate, null);
  assertEquals(formatRate("absent", null), "データなし");
  assertEquals(pageViewConversion(0, "present", 3, "present").rate, null);
  assertEquals(formatRate("present", null), "—");
  const text = formatCombinedMessage(view({
    impressions: present(200),
    pageViews: present(40),
    newDownloads: present(10),
  }));
  assertEquals(text.includes("転換率 25.0%（ページ閲覧→新規DL"), true);
  assertEquals(text.includes("一つのファネルにしていません"), true);
  assertEquals(text.includes("総ダウンロード ÷ 表示回数"), false);
});

Deno.test("集客ファイルが揃うまで投稿せず、利用状況が無くても売上確定後は投稿できる", () => {
  const base = {
    sales: "rows" as const,
    subscription: "rows" as const,
    events: "zero" as const,
    reviewsReady: true,
    hasParentSku: true,
    discovery: "present" as const,
    downloads: "present" as const,
  };
  assertEquals(combinedPublishable(base), true);
  assertEquals(combinedPublishable({ ...base, discovery: "pending" }), false);
  assertEquals(combinedPublishable({ ...base, downloads: "absent", discovery: "absent" }), true);
  assertEquals(combinedPublishable({ ...base, sales: "hold" }), false);
  assertEquals(combinedPublishable({ ...base, sales: "zero", subscription: "rows" }), false);
  assertEquals(combinedPublishable({ ...base, events: "hold" }), false);
  assertEquals(combinedPublishable({ ...base, reviewsReady: false }), false);
  assertEquals(combinedPublishable({ ...base, hasParentSku: false }), false);
  assertEquals(combinedPublishable({ ...base, installs: "pending" } as typeof base), true);
});

Deno.test("除外した人と端末は初回起動・登録・トライアルに入れない", () => {
  const start = new Date("2026-10-15T07:00:00.000Z");
  const end = new Date("2026-10-16T07:00:00.000Z");
  const events: ActivityEvent[] = [
    open("i-keep", "u-keep", "2026-10-15T08:00:00.000Z"),
    ads("i-keep", "u-keep", true, "2144888758"),
    open("i-other", "u-other", "2026-10-15T09:00:00.000Z"),
    ads("i-other", "u-other", false, "1"),
    open("i-unknown", "u-unknown", "2026-10-15T10:00:00.000Z"),
    open("i-boss", "u-boss", "2026-10-15T11:00:00.000Z"),
    ads("i-boss", "u-boss", true, "2144888758"),
    open("i-reviewer", "u-reviewer", "2026-10-15T12:00:00.000Z"),
    event("login_result", "u-keep", "i-keep", "2026-10-15T12:30:00.000Z", {
      result: "success",
      is_new_account: true,
    }),
    event("login_result", "u-boss", "i-boss", "2026-10-15T12:40:00.000Z", {
      result: "success",
      is_new_account: true,
    }),
    event("login_result", "u-keep", "i-keep", "2026-10-15T12:50:00.000Z", {
      result: "success",
      is_new_account: false,
    }),
    event("purchase_result", "u-keep", "i-keep", "2026-10-15T13:00:00.000Z", { result: "success" }),
    event("onboarding_complete", "u-keep", "i-keep", "2026-10-15T13:10:00.000Z", {}),
    event("onboarding_complete", "u-flag-off", "i-flag", "2026-10-15T13:20:00.000Z", {}),
    event("food_entry_added", "u-keep", "i-keep", "2026-10-15T14:00:00.000Z", {}),
    event("food_entry_added", "u-keep", "i-keep", "2026-10-15T15:00:00.000Z", {}),
    event("paywall_open", "u-keep", "i-keep", "2026-10-15T16:00:00.000Z", {}),
    event("paywall_open", "u-keep", "i-keep", "2026-10-15T17:00:00.000Z", {}),
    event("paywall_open", "u-boss", "i-boss", "2026-10-15T17:10:00.000Z", {}),
    event("session_start", "u-keep", "i-keep", "2026-10-15T18:00:00.000Z", {}),
    event("session_end", "u-keep", "i-keep", "2026-10-15T18:30:00.000Z", { duration_seconds: 90 }),
    event("food_search", "u-keep", "i-keep", "2026-10-15T19:00:00.000Z", {}),
    event("siri_registration_imported", "u-keep", "i-keep", "2026-10-15T19:10:00.000Z", {}),
    event("widget_presence", "u-keep", "i-keep", "2026-10-15T19:20:00.000Z", {}),
    event("widget_tap", "u-keep", "i-keep", "2026-10-15T19:30:00.000Z", {}),
    event("food_entry_added", "u-boss", "i-boss", "2026-10-14T01:00:00.000Z", {}),
  ];
  const notices: TrialNotice[] = [
    trial("u-keep", "tx-1", "2026-10-15T20:00:00.000Z"),
    trial("u-boss", "tx-boss", "2026-10-15T20:10:00.000Z"),
    trial("u-sandbox", "tx-sand", "2026-10-15T20:20:00.000Z", "Sandbox"),
    { ...trial("u-paid", "tx-paid", "2026-10-15T20:30:00.000Z"), offerDiscountType: "PAY_UP_FRONT" },
  ];
  const counted = countAppActivity({
    events,
    notices,
    onboardingCompleteUsers: new Set(["u-keep", "u-boss"]),
    excludedUserIds: ["u-boss"],
    excludedInstallIds: ["i-reviewer"],
    start,
    end,
  });
  assertEquals(counted.firstOpens, 3);
  assertEquals(counted.firstOpensAsa, 1);
  assertEquals(counted.firstOpensOther, 1);
  assertEquals(counted.firstOpensUnknown, 1);
  assertEquals(counted.registrations, 1);
  assertEquals(counted.onboardingCompletes, 1);
  assertEquals(counted.firstMeals, 1);
  assertEquals(counted.paywallOpeners, 1);
  assertEquals(counted.trialStarts, 1);
  assertEquals(counted.sessions, 1);
  assertEquals(counted.sessionDurationSeconds, 90);
  assertEquals(counted.searches, 1);
  assertEquals(counted.siriUses, 1);
  assertEquals(counted.widgetUses, 1);
});

Deno.test("同じ日付の投稿済みは、中身が変わった訂正期間だけ取り直す", () => {
  const now = Date.parse("2026-10-17T00:00:00.000Z");
  const posted = {
    status: "posted" as const,
    attempt: 1,
    updatedAtMs: now - 60_000,
    contentHash: "same",
  };
  assertEquals(deliveryDecision(posted, now, "same", true), "skip");
  assertEquals(deliveryDecision(posted, now, "changed", true), "revise");
  assertEquals(deliveryDecision(posted, now, "changed", false), "skip");
  assertEquals(
    deliveryDecision(
      { status: "reserved", attempt: 1, updatedAtMs: now - 1000, contentHash: "same" },
      now,
      "same",
      true,
    ),
    "skip",
  );
  assertEquals(
    deliveryDecision(
      {
        status: "reserved",
        attempt: 1,
        updatedAtMs: now - reservationLeaseMs - 1,
        contentHash: "same",
      },
      now,
      "same",
      true,
    ),
    "claim",
  );
});

Deno.test("standard のレポートだけを選び、ダウンロードとインストールを混ぜない", () => {
  assertEquals(reportKind("App Store Discovery and Engagement"), "discovery");
  assertEquals(reportKind("App Store Downloads"), "downloads");
  assertEquals(reportKind("App Store Downloads Detailed"), null);
  assertEquals(reportKind("App Store Installation and Deletion"), "installs");
  assertEquals(reportKind("App Sessions"), "sessions");
  assertEquals(reportKind("App Sessions Detailed"), null);
  assertEquals(reportKind("App Sessions Context"), null);
  assertEquals(reportKind("App Crashes"), "crashes");
  const picked = preferStandardReport(
    [
      { name: "App Sessions Detailed", id: "d" },
      { name: "App Sessions", id: "s" },
      { name: "App Store Downloads", id: "dl" },
    ],
    "sessions",
  );
  assertEquals(picked?.id, "s");
});

function present(value: number): CountPoint {
  return { state: "present", value };
}

function pending(): CountPoint {
  return { state: "pending", value: null };
}

function emptyActivity(): AppActivity {
  return {
    firstOpens: 0,
    firstOpensAsa: 0,
    firstOpensOther: 0,
    firstOpensUnknown: 0,
    registrations: 0,
    onboardingCompletes: 0,
    firstMeals: 0,
    paywallOpeners: 0,
    trialStarts: 0,
    sessions: 0,
    sessionDurationSeconds: 0,
    searches: 0,
    siriUses: 0,
    widgetUses: 0,
  };
}

function view(over: Partial<CombinedView>): CombinedView {
  const point = pending();
  return {
    reportDate: "2026-10-15",
    correction: false,
    publishable: true,
    newDownloads: point,
    redownloads: point,
    salesCents: point,
    proceedsCents: point,
    impressions: point,
    pageViews: point,
    sourceSearch: point,
    sourceOther: point,
    installs: point,
    uninstalls: point,
    appleSessions: point,
    appleDurationSeconds: point,
    uniqueDevices: point,
    crashTotal: point,
    crashesByVersion: null,
    crashesByDevice: null,
    plans: [],
    appleTrialStarts: point,
    paidConversions: point,
    cancellations: point,
    reviewCount: 0,
    averageRating: null,
    stars: [0, 0, 0, 0, 0],
    excerpt: "",
    activity: emptyActivity(),
    previous: null,
    week: null,
    nonJpyCustomerRows: 0,
    ...over,
  };
}

function event(
  name: string,
  userId: string | null,
  installId: string | null,
  occurredAt: string,
  props: Record<string, unknown>,
): ActivityEvent {
  return { name, userId, installId, occurredAt, props };
}

function open(installId: string, userId: string, occurredAt: string): ActivityEvent {
  return event("app_install_first_open", userId, installId, occurredAt, {});
}

function ads(installId: string, userId: string, attribution: boolean, campaignId: string): ActivityEvent {
  return event("apple_ads_attribution", userId, installId, "2026-10-15T08:05:00.000Z", {
    attribution,
    campaign_id: campaignId,
  });
}

function trial(userId: string, transactionId: string, signedAt: string, environment = "Production"): TrialNotice {
  return {
    userId,
    originalTransactionId: transactionId,
    notificationUuid: transactionId,
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    environment,
    verificationStatus: "verified",
    offerDiscountType: "FREE_TRIAL",
    offerType: 1,
    priceMilliunits: 0,
    signedAt,
  };
}
