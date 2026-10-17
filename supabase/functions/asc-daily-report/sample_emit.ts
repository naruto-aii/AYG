// 見本の文面。本番の整形と同じ関数を使う。投稿はしない。
// 数字は 2026-10-17 時点の集計。個人は含まない。
// 検索・Siri・ウィジェット・利用時間は、その日の kpi.app_events を件数だけ数えた。
import { formatCombinedMessage, reportPayload, type AppActivity, type CombinedView, type CountPoint, type TrendDay } from "./metrics.ts";

const pending = (): CountPoint => ({ state: "pending", value: null });
const present = (value: number): CountPoint => ({ state: "present", value });

type Day = {
  date: string;
  asa: number;
  other: number;
  unknown: number;
  registrations: number;
  onboarding: number;
  meals: number;
  paywall: number;
  trials: number;
  sessions: number;
  duration: number;
  searches: number;
  searchUsers: number;
  siri: number;
  siriUsers: number;
  widget: number;
  widgetUsers: number;
  newDownloads: number | null;
  redownloads: number | null;
  impressions: number | null;
  pageViews: number | null;
};

function quiet(date: string): Day {
  return {
    date,
    asa: 0,
    other: 0,
    unknown: 0,
    registrations: 0,
    onboarding: 0,
    meals: 0,
    paywall: 0,
    trials: 0,
    sessions: 0,
    duration: 0,
    searches: 0,
    searchUsers: 0,
    siri: 0,
    siriUsers: 0,
    widget: 0,
    widgetUsers: 0,
    newDownloads: null,
    redownloads: null,
    impressions: null,
    pageViews: null,
  };
}

const measured: Day[] = [
  ...["2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11", "2026-10-12", "2026-10-13"].map(quiet),
  {
    ...quiet("2026-10-14"),
    other: 4,
    registrations: 5,
    onboarding: 4,
    meals: 1,
    paywall: 2,
    trials: 1,
    sessions: 7,
    duration: 4576,
    searches: 17,
    searchUsers: 2,
    siri: 0,
    siriUsers: 0,
    impressions: 7,
    pageViews: 11,
  },
  {
    ...quiet("2026-10-15"),
    other: 8,
    registrations: 7,
    onboarding: 8,
    meals: 2,
    paywall: 3,
    sessions: 23,
    duration: 8616,
    searches: 50,
    searchUsers: 3,
    siri: 0,
    siriUsers: 0,
    newDownloads: 14,
    redownloads: 2,
  },
  {
    ...quiet("2026-10-16"),
    asa: 31,
    other: 2,
    unknown: 1,
    registrations: 35,
    onboarding: 33,
    meals: 12,
    paywall: 20,
    trials: 1,
    sessions: 75,
    duration: 17797,
    searches: 373,
    searchUsers: 20,
    siri: 1,
    siriUsers: 1,
    widget: 20,
    widgetUsers: 1,
  },
];

function byDate(date: string): Day {
  return measured.find((day) => day.date === date) ?? quiet(date);
}

function addDays(isoDate: string, days: number): string {
  const [year, month, day] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

function activityOf(day: Day): AppActivity {
  return {
    firstOpens: day.asa + day.other + day.unknown,
    firstOpensAsa: day.asa,
    firstOpensOther: day.other,
    firstOpensUnknown: day.unknown,
    registrations: day.registrations,
    onboardingCompletes: day.onboarding,
    firstMeals: day.meals,
    paywallOpeners: day.paywall,
    trialStarts: day.trials,
    sessions: day.sessions,
    sessionDurationSeconds: day.duration,
    searches: day.searches,
    searchUsers: day.searchUsers,
    siriUses: day.siri,
    siriUsers: day.siriUsers,
    widgetUses: day.widget,
    widgetUsers: day.widgetUsers,
  };
}

function trendOf(day: Day): TrendDay {
  const conversion = day.pageViews != null && day.pageViews > 0 && day.newDownloads != null
    ? Math.round((day.newDownloads / day.pageViews) * 10000) / 10000
    : null;
  return {
    reportDate: day.date,
    label: `${Number(day.date.slice(5, 7))}/${Number(day.date.slice(8, 10))}`,
    newDownloads: day.newDownloads,
    redownloads: day.redownloads,
    impressions: day.impressions,
    pageViews: day.pageViews,
    conversion,
    firstOpensAsa: day.asa,
    firstOpensOther: day.other,
    firstOpensUnknown: day.unknown,
    firstOpens: day.asa + day.other + day.unknown,
    onboardingCompletes: day.onboarding,
    firstMeals: day.meals,
    paywallOpeners: day.paywall,
    sessions: day.sessions,
    sessionDurationSeconds: day.duration,
  };
}

function seriesEnding(date: string): TrendDay[] {
  const days: TrendDay[] = [];
  for (let ago = 13; ago >= 0; ago--) days.push(trendOf(byDate(addDays(date, -ago))));
  return days;
}

function base(reportDate: string, over: Partial<CombinedView>): CombinedView {
  const point = pending();
  const day = byDate(reportDate);
  return {
    reportDate,
    correction: false,
    publishable: false,
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
    reviewsReady: false,
    activity: activityOf(day),
    previous: {
      newDownloads: null,
      redownloads: null,
      salesCents: null,
      proceedsCents: null,
      impressions: null,
      pageViews: null,
      installs: null,
      uninstalls: null,
      appleSessions: null,
      activity: activityOf(byDate(addDays(reportDate, -1))),
    },
    week: {
      newDownloads: null,
      redownloads: null,
      salesCents: null,
      proceedsCents: null,
      impressions: null,
      pageViews: null,
      installs: null,
      uninstalls: null,
      appleSessions: null,
      activity: activityOf(byDate(addDays(reportDate, -7))),
    },
    nonJpyCustomerRows: 0,
    series: seriesEnding(reportDate),
    ...over,
  };
}

const samples = [
  {
    id: "2026-10-15",
    note: "太平洋時間 10/15。売上・課金・レビューとアプリ内は、その時点の集計。集客と利用状況のファイルはまだ無いのでデータなし。集客が pending のため本番では投稿しない。",
    view: base("2026-10-15", {
      newDownloads: present(14),
      redownloads: present(2),
      salesCents: present(0),
      proceedsCents: present(0),
      plans: [
        { label: "月額", paid: 0, trials: 1 },
        { label: "半年", paid: 0, trials: 0 },
        { label: "年額", paid: 0, trials: 0 },
      ],
      appleTrialStarts: present(0),
      paidConversions: present(0),
      cancellations: present(0),
      reviewsReady: true,
    }),
  },
  {
    id: "2026-10-16",
    note: "太平洋時間 10/16。アプリ内は集計がある。Apple のファイルはまだ確定していないのでデータなし。レビューも未確定なのでデータなし。本番では投稿しない。",
    view: base("2026-10-16", {}),
  },
];

const output = samples.map((sample) => {
  const text = formatCombinedMessage(sample.view);
  return {
    id: sample.id,
    note: sample.note,
    publishable: sample.view.publishable,
    slack_text: text,
    payload: reportPayload(sample.view),
  };
});

const destination = Deno.args[0];
const body = JSON.stringify(output, null, 2);
if (destination) {
  await Deno.writeTextFile(destination, body);
} else {
  console.log(body);
}
