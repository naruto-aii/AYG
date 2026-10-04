import {
  buildDailyReminder,
  classifyApnsResponse,
  fallbackHealthExcessKcal,
  handleDailyReminder,
  isServiceRoleAuthorization,
  japanCalendarDate,
  japanHour,
  noRecordsMessage,
  resolveHealthExcessKcal,
  roundKcal,
  runningKilometers,
  type ReminderRow,
  type SendResult,
} from "./daily_calorie_reminder.ts";

function assert(condition: unknown, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function b64url(value: string): string {
  return btoa(value).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function bearer(role: string): string {
  const header = b64url(JSON.stringify({ alg: "none", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ role }));
  return `Bearer ${header}.${payload}.sig`;
}

function row(overrides: Partial<ReminderRow> = {}): ReminderRow {
  return {
    user_id: "11111111-1111-4111-8111-111111111111",
    device_token: "ab".repeat(32),
    apns_environment: "sandbox",
    meal_count: 0,
    exercise_count: 0,
    food_kcal: 0,
    alcohol_kcal: 0,
    exercise_net_kcal: 0,
    goal_kcal: 1800,
    weight_kg: 60,
    use_health_integration: false,
    activity_level: "moderate",
    active_energy_burned_kcal: null,
    activity_excess_kcal: null,
    activity_excess_on: null,
    birth_date: "1990-01-01T00:00:00.000Z",
    gender: "female",
    height_cm: 160,
    ...overrides,
  };
}

Deno.test("japan clock is 20:00 at 11:00 UTC", () => {
  const at2000 = new Date("2026-10-04T11:00:00.000Z");
  assert(japanCalendarDate(at2000) === "2026-10-04", japanCalendarDate(at2000));
  assert(japanHour(at2000) === 20, String(japanHour(at2000)));
  assert(japanHour(new Date("2026-10-04T10:59:00.000Z")) === 19, "19");
  assert(japanHour(new Date("2026-10-04T12:00:00.000Z")) === 21, "21");
});

Deno.test("copy matches the three app sentences", () => {
  assert(
    buildDailyReminder(row({ alcohol_kcal: 250 }), "2026-10-04") === noRecordsMessage,
    "alcohol alone",
  );
  assert(
    noRecordsMessage ===
      "今日の食事、運動が登録されてません！今のうちに登録しましょう！",
    "empty wording",
  );
  assert(roundKcal(10.5) === 11, "round half");
  assert(roundKcal(10.4) === 10, "round down");
  assert(
    buildDailyReminder(
      row({ meal_count: 1, goal_kcal: 2000, food_kcal: 500 }),
      "2026-10-04",
    ) === "今日あと1500kcal食べられます！",
    "remaining",
  );
  assert(
    buildDailyReminder(
      row({ meal_count: 1, goal_kcal: 500, food_kcal: 500 }),
      "2026-10-04",
    ) === "今日あと0kcal食べられます！",
    "zero",
  );
  assert(
    buildDailyReminder(
      row({
        meal_count: 1,
        goal_kcal: 500,
        food_kcal: 680,
        weight_kg: 70,
      }),
      "2026-10-04",
    ) === "今日は180kcalオーバーしてます！2.6kmランニングすればチャラにできますよ！",
    "overage",
  );
  assert(runningKilometers(1, 60) === "0.1", runningKilometers(1, 60));
  assert(runningKilometers(60, 0) === "1.0", "fallback weight");
});

Deno.test("a meal after the previous totals changes the sentence", () => {
  const before = buildDailyReminder(row(), "2026-10-04");
  const after = buildDailyReminder(
    row({ meal_count: 1, food_kcal: 450 }),
    "2026-10-04",
  );
  assert(before === noRecordsMessage, "before");
  assert(after === "今日あと1350kcal食べられます！", after);
});

Deno.test("today's saved health excess wins over the fallback", () => {
  const sample = row({
    use_health_integration: true,
    active_energy_burned_kcal: 900,
    activity_excess_kcal: 40,
    activity_excess_on: "2026-10-04",
    meal_count: 1,
    goal_kcal: 2000,
    food_kcal: 1800,
  });
  assert(resolveHealthExcessKcal(sample, "2026-10-04") === 40, "stored");
  assert(
    fallbackHealthExcessKcal(sample, "2026-10-04") !== 40,
    "fallback differs",
  );
  assert(
    buildDailyReminder(sample, "2026-10-04") === "今日あと240kcal食べられます！",
    "uses stored excess",
  );
  const yesterday = { ...sample, activity_excess_on: "2026-10-03" };
  assert(
    resolveHealthExcessKcal(yesterday, "2026-10-04") ===
      fallbackHealthExcessKcal(yesterday, "2026-10-04"),
    "stale excess is not reused",
  );
});

Deno.test("the handler sends one fresh body and only at 20:00 Japan", async () => {
  const sends: string[] = [];
  const claimed = new Set<string>();
  const deps = {
    now: () => new Date("2026-10-04T11:00:00.000Z"),
    isAuthorized: isServiceRoleAuthorization,
    apnsConfigured: true,
    loadPage: async (
      _japanDate: string,
      _limit: number,
      afterUserId: string | null,
    ) => {
      if (afterUserId != null) {
        return [];
      }
      return [row({ meal_count: 1, food_kcal: 450, goal_kcal: 1800 })];
    },
    claim: async (userId: string) => {
      if (claimed.has(userId)) {
        return false;
      }
      claimed.add(userId);
      return true;
    },
    release: async () => {},
    dropToken: async () => {},
    send: async (_row: ReminderRow, body: string): Promise<SendResult> => {
      sends.push(body);
      return "sent";
    },
  };

  const denied = await handleDailyReminder(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: bearer("authenticated") },
    }),
    deps,
  );
  assert(denied.status === 401, "user jwt");
  assert(sends.length === 0, "no send without service role");

  const early = await handleDailyReminder(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: bearer("service_role") },
    }),
    { ...deps, now: () => new Date("2026-10-04T10:59:00.000Z") },
  );
  const earlyBody = await early.json();
  assert(earlyBody.reason === "outside_japan_20", "hour gate");
  assert(sends.length === 0, "no early send");

  const ok = await handleDailyReminder(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: bearer("service_role") },
    }),
    deps,
  );
  const okBody = await ok.json();
  assert(okBody.sent === 1, "one send");
  assert(sends.length === 1, "one body");
  assert(sends[0] === "今日あと1350kcal食べられます！", sends[0]);

  const again = await handleDailyReminder(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: bearer("service_role") },
    }),
    deps,
  );
  const againBody = await again.json();
  assert(againBody.skipped === 1, "second claim skipped");
  assert(sends.length === 1, "still one body");
});

Deno.test("apns failure classes", () => {
  assert(classifyApnsResponse(200, "") === "sent", "200");
  assert(classifyApnsResponse(503, "") === "transient", "503");
  assert(classifyApnsResponse(410, "Unregistered") === "drop_token", "410");
  assert(classifyApnsResponse(400, "BadDeviceToken") === "drop_token", "bad");
  assert(classifyApnsResponse(400, "PayloadTooLarge") === "failed", "payload");
});
