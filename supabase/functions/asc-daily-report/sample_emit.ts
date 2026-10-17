// 見本の文面。本番の整形と同じ関数を使う。投稿はしない。
import { formatCombinedMessage, reportPayload, type AppActivity, type CombinedView, type CountPoint } from "./metrics.ts";

const pending = (): CountPoint => ({ state: "pending", value: null });
const present = (value: number): CountPoint => ({ state: "present", value });

function activity(over: Partial<AppActivity>): AppActivity {
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
    ...over,
  };
}

const day15Activity = activity({
  firstOpens: 8,
  firstOpensOther: 8,
  onboardingCompletes: 8,
  firstMeals: 2,
  paywallOpeners: 3,
  sessions: 23,
  sessionDurationSeconds: 19015,
  searches: 150,
  siriUses: 76,
});

const day16Activity = activity({
  firstOpens: 34,
  firstOpensAsa: 31,
  firstOpensOther: 2,
  firstOpensUnknown: 1,
  onboardingCompletes: 33,
  firstMeals: 12,
  paywallOpeners: 20,
  trialStarts: 1,
  sessions: 75,
  sessionDurationSeconds: 45791,
  searches: 1081,
  siriUses: 182,
  widgetUses: 20,
});

function base(reportDate: string, over: Partial<CombinedView>): CombinedView {
  const point = pending();
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
    plans: [
      { label: "月額", paid: 0, trials: 0 },
      { label: "半年", paid: 0, trials: 0 },
      { label: "年額", paid: 0, trials: 0 },
    ],
    appleTrialStarts: point,
    paidConversions: point,
    cancellations: point,
    reviewCount: 0,
    averageRating: null,
    stars: [0, 0, 0, 0, 0],
    excerpt: "",
    activity: activity({}),
    previous: null,
    week: null,
    nonJpyCustomerRows: 0,
    ...over,
  };
}

const samples = [
  {
    id: "2026-10-15",
    note: "太平洋時間 10/15。売上・課金・レビューとアプリ内は、その時点で保存済みの集計。集客と利用状況のファイルはまだ無いのでデータなし。集客が pending のため本番では投稿しない。",
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
      activity: day15Activity,
    }),
  },
  {
    id: "2026-10-16",
    note: "太平洋時間 10/16。アプリ内だけ集計がある。Apple のファイルはまだ確定していないのでデータなし。本番では投稿しない。",
    view: base("2026-10-16", {
      plans: [],
      activity: day16Activity,
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
        activity: day15Activity,
      },
    }),
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
