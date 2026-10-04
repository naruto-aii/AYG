// 20:00 Asia/Tokyo reminder. The body is built from the rows read at send
// time. A previously rendered sentence is never stored or reused.

export const noRecordsMessage =
  "今日の食事、運動が登録されてません！今のうちに登録しましょう！";

export const fallbackWeightKg = 60;

const lifestyleFactors: Record<string, number> = {
  low: 1.2,
  light: 1.375,
  moderate: 1.55,
  high: 1.725,
  veryHigh: 1.9,
};

export type ReminderRow = {
  user_id: string;
  device_token: string;
  apns_environment: string;
  meal_count: number;
  exercise_count: number;
  food_kcal: number;
  alcohol_kcal: number;
  exercise_net_kcal: number;
  goal_kcal: number;
  weight_kg: number | null;
  use_health_integration: boolean;
  activity_level: string | null;
  active_energy_burned_kcal: number | null;
  activity_excess_kcal: number | null;
  activity_excess_on: string | null;
  birth_date: string | null;
  gender: string | null;
  height_cm: number | null;
};

export type SendResult = "sent" | "transient" | "drop_token" | "failed";

export type ReminderDeps = {
  now: () => Date;
  isAuthorized: (authorization: string | null) => boolean;
  apnsConfigured: boolean;
  loadPage: (
    japanDate: string,
    limit: number,
    afterUserId: string | null,
  ) => Promise<ReminderRow[]>;
  claim: (userId: string, japanDate: string) => Promise<boolean>;
  release: (userId: string, japanDate: string) => Promise<void>;
  dropToken: (row: ReminderRow) => Promise<void>;
  send: (row: ReminderRow, body: string, japanDate: string) => Promise<SendResult>;
};

export function japanCalendarDate(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

export function japanHour(now: Date): number {
  const hour = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    hourCycle: "h23",
  }).format(now);
  return Number(hour);
}

export function roundKcal(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  const sign = value < 0 ? -1 : 1;
  const abs = Math.abs(value);
  const whole = Math.floor(abs);
  const fraction = abs - whole;
  return sign * (fraction >= 0.5 ? whole + 1 : whole);
}

export function runningKilometers(excessKcal: number, weightKg: number): string {
  if (!(excessKcal > 0)) {
    return "0.0";
  }
  const weight = weightKg > 0 && Number.isFinite(weightKg)
    ? weightKg
    : fallbackWeightKg;
  // MetActivityCatalog running: 1.0 kcal·kg⁻¹·km⁻¹.
  const km = excessKcal / weight;
  const rounded = roundKcal(km * 10) / 10;
  const shown = rounded < 0.1 ? 0.1 : rounded;
  return shown.toFixed(1);
}

export function remainingMessage(kcal: number): string {
  return `今日あと${kcal}kcal食べられます！`;
}

export function overageMessage(kcal: number, kilometers: string): string {
  return `今日は${kcal}kcalオーバーしてます！${kilometers}kmランニングすればチャラにできますよ！`;
}

function finite(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value)) {
    return null;
  }
  return value;
}

export function ageYears(birthIso: string | null, japanDate: string): number | null {
  if (!birthIso) {
    return null;
  }
  const birth = new Date(birthIso);
  if (Number.isNaN(birth.getTime())) {
    return null;
  }
  const [year, month, day] = japanDate.split("-").map((part) => Number(part));
  if (!year || !month || !day) {
    return null;
  }
  let age = year - birth.getUTCFullYear();
  const birthMonth = birth.getUTCMonth() + 1;
  const birthDay = birth.getUTCDate();
  if (month < birthMonth || (month === birthMonth && day < birthDay)) {
    age -= 1;
  }
  return age;
}

export function estimateReeKcal(input: {
  weightKg: number | null;
  heightCm: number | null;
  age: number | null;
  gender: string | null;
}): number | null {
  const weight = finite(input.weightKg);
  const height = finite(input.heightCm);
  if (
    weight == null ||
    height == null ||
    weight <= 0 ||
    height <= 0 ||
    input.age == null ||
    input.age < 18 ||
    (input.gender !== "male" && input.gender !== "female")
  ) {
    return null;
  }
  const base = 10 * weight + 6.25 * height - 5 * input.age;
  return input.gender === "female" ? base - 161 : base + 5;
}

export function fallbackHealthExcessKcal(row: ReminderRow, japanDate: string): number {
  if (!row.use_health_integration) {
    return 0;
  }
  const factor = lifestyleFactors[row.activity_level ?? ""] ?? lifestyleFactors.moderate;
  const ree = estimateReeKcal({
    weightKg: row.weight_kg,
    heightCm: row.height_cm,
    age: ageYears(row.birth_date, japanDate),
    gender: row.gender,
  });
  const active = finite(row.active_energy_burned_kcal);
  if (ree == null || ree <= 0 || factor < 1 || active == null || active < 0) {
    return 0;
  }
  const excess = active - ree * (factor - 1);
  if (!Number.isFinite(excess) || excess <= 0) {
    return 0;
  }
  return excess;
}

export function resolveHealthExcessKcal(row: ReminderRow, japanDate: string): number {
  const stored = finite(row.activity_excess_kcal);
  if (row.activity_excess_on === japanDate && stored != null && stored >= 0) {
    return stored;
  }
  return fallbackHealthExcessKcal(row, japanDate);
}

export function buildDailyReminder(row: ReminderRow, japanDate: string): string {
  if (Number(row.meal_count) <= 0 && Number(row.exercise_count) <= 0) {
    return noRecordsMessage;
  }
  const goal = finite(row.goal_kcal) ?? 0;
  const intake = (finite(row.food_kcal) ?? 0) + (finite(row.alcohol_kcal) ?? 0);
  const exercise = finite(row.exercise_net_kcal) ?? 0;
  const excess = resolveHealthExcessKcal(row, japanDate);
  const remaining = goal + exercise + excess - intake;
  if (!Number.isFinite(remaining)) {
    return noRecordsMessage;
  }
  if (remaining >= 0) {
    return remainingMessage(roundKcal(remaining));
  }
  const over = roundKcal(Math.abs(remaining));
  return overageMessage(
    over,
    runningKilometers(over, finite(row.weight_kg) ?? 0),
  );
}

export function isServiceRoleAuthorization(authorization: string | null): boolean {
  if (!authorization?.startsWith("Bearer ")) {
    return false;
  }
  const token = authorization.slice("Bearer ".length).trim();
  const parts = token.split(".");
  if (parts.length < 2) {
    return false;
  }
  try {
    const padded = parts[1].replaceAll("-", "+").replaceAll("_", "/") +
      "=".repeat((4 - (parts[1].length % 4)) % 4);
    const json = JSON.parse(atob(padded)) as { role?: unknown };
    return json.role === "service_role";
  } catch {
    return false;
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handleDailyReminder(
  req: Request,
  deps: ReminderDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return json({ ok: false }, 405);
  }
  if (!deps.isAuthorized(req.headers.get("Authorization"))) {
    return json({ ok: false }, 401);
  }
  const now = deps.now();
  const japanDate = japanCalendarDate(now);
  if (japanHour(now) !== 20) {
    return json({ ok: false, reason: "outside_japan_20", japanDate }, 200);
  }
  if (!deps.apnsConfigured) {
    return json({ ok: false, reason: "apns_not_configured", japanDate }, 200);
  }

  let after: string | null = null;
  let considered = 0;
  let sent = 0;
  let skipped = 0;
  let failed = 0;
  for (;;) {
    const page = await deps.loadPage(japanDate, 200, after);
    if (page.length === 0) {
      break;
    }
    for (const row of page) {
      after = row.user_id;
      considered += 1;
      const claimed = await deps.claim(row.user_id, japanDate);
      if (!claimed) {
        skipped += 1;
        continue;
      }
      const body = buildDailyReminder(row, japanDate);
      let result = await deps.send(row, body, japanDate);
      if (result === "transient") {
        result = await deps.send(row, body, japanDate);
      }
      if (result === "sent") {
        sent += 1;
        continue;
      }
      failed += 1;
      if (result === "transient") {
        await deps.release(row.user_id, japanDate);
      } else if (result === "drop_token") {
        await deps.dropToken(row);
      }
    }
    if (page.length < 200) {
      break;
    }
  }

  return json({ ok: true, japanDate, considered, sent, skipped, failed }, 200);
}

export type ApnsSecrets = {
  teamId: string;
  keyId: string;
  privateKeyPem: string;
  bundleId: string;
};

type EnvMap = Record<string, string | undefined>;

export function apnsSecretsFromEnv(env: EnvMap): ApnsSecrets | null {
  const teamId = env.APNS_TEAM_ID?.trim() ?? "";
  const keyId = env.APNS_KEY_ID?.trim() ?? "";
  const bundleId = (env.APNS_BUNDLE_ID?.trim() || "com.narutoaii.ayg");
  const privateKeyPem = (env.APNS_PRIVATE_KEY ?? "").replaceAll("\\n", "\n").trim();
  if (!teamId || !keyId || !privateKeyPem.includes("PRIVATE KEY")) {
    return null;
  }
  return { teamId, keyId, privateKeyPem, bundleId };
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replaceAll("-----BEGIN PRIVATE KEY-----", "")
    .replaceAll("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export async function apnsProviderToken(secrets: ApnsSecrets, nowSeconds: number): Promise<string> {
  const pkcs8 = pemToPkcs8(secrets.privateKeyPem);
  const keyBytes = new Uint8Array(pkcs8.byteLength);
  keyBytes.set(pkcs8);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = bytesToBase64Url(new TextEncoder().encode(JSON.stringify({
    alg: "ES256",
    kid: secrets.keyId,
  })));
  const payload = bytesToBase64Url(new TextEncoder().encode(JSON.stringify({
    iss: secrets.teamId,
    iat: nowSeconds,
  })));
  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

export function apnsHost(environment: string): string {
  return environment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}

export function apnsExpiration(japanDate: string): string {
  const [year, month, day] = japanDate.split("-").map((part) => Number(part));
  return String(Math.floor(Date.UTC(year, month - 1, day, 12, 0, 0) / 1000));
}

export function classifyApnsResponse(status: number, reason: string): SendResult {
  if (status === 200) {
    return "sent";
  }
  if (status === 429 || status >= 500) {
    return "transient";
  }
  if (
    status === 410 ||
    reason === "BadDeviceToken" ||
    reason === "Unregistered" ||
    reason === "DeviceTokenNotForTopic"
  ) {
    return "drop_token";
  }
  return "failed";
}

export async function sendApnsAlert(input: {
  secrets: ApnsSecrets;
  token: string;
  environment: string;
  body: string;
  japanDate: string;
  providerToken: string;
  fetchImpl?: typeof fetch;
}): Promise<SendResult> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const host = apnsHost(input.environment);
  const response = await fetchImpl(
    `${host}/3/device/${encodeURIComponent(input.token)}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${input.providerToken}`,
        "apns-topic": input.secrets.bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": `calonavi-${input.japanDate}`,
        "apns-expiration": apnsExpiration(input.japanDate),
      },
      body: JSON.stringify({
        aps: {
          alert: input.body,
          sound: "default",
        },
      }),
    },
  );
  let reason = "";
  if (response.status !== 200) {
    try {
      const json = await response.json() as { reason?: unknown };
      if (typeof json.reason === "string") {
        reason = json.reason;
      }
    } catch {
      reason = "";
    }
  }
  return classifyApnsResponse(response.status, reason);
}

type Postgrest = (
  path: string,
  init: { method: string; body?: unknown },
) => Promise<unknown>;

function asNumber(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : 0;
}

function asNullableNumber(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

export function reminderRowFromJson(value: unknown): ReminderRow | null {
  if (!value || typeof value !== "object") {
    return null;
  }
  const row = value as Record<string, unknown>;
  if (typeof row.user_id !== "string" || typeof row.device_token !== "string") {
    return null;
  }
  return {
    user_id: row.user_id,
    device_token: row.device_token,
    apns_environment: row.apns_environment === "sandbox" ? "sandbox" : "production",
    meal_count: asNumber(row.meal_count),
    exercise_count: asNumber(row.exercise_count),
    food_kcal: asNumber(row.food_kcal),
    alcohol_kcal: asNumber(row.alcohol_kcal),
    exercise_net_kcal: asNumber(row.exercise_net_kcal),
    goal_kcal: asNumber(row.goal_kcal),
    weight_kg: asNullableNumber(row.weight_kg),
    use_health_integration: row.use_health_integration === true,
    activity_level: typeof row.activity_level === "string" ? row.activity_level : null,
    active_energy_burned_kcal: asNullableNumber(row.active_energy_burned_kcal),
    activity_excess_kcal: asNullableNumber(row.activity_excess_kcal),
    activity_excess_on: typeof row.activity_excess_on === "string"
      ? row.activity_excess_on
      : null,
    birth_date: typeof row.birth_date === "string" ? row.birth_date : null,
    gender: typeof row.gender === "string" ? row.gender : null,
    height_cm: asNullableNumber(row.height_cm),
  };
}

export function liveReminderDeps(input: {
  env: EnvMap;
  now: () => Date;
  fetchImpl?: typeof fetch;
}): ReminderDeps {
  const supabaseUrl = (input.env.SUPABASE_URL ?? "").replace(/\/$/, "");
  const serviceRole = input.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const secrets = apnsSecretsFromEnv(input.env);
  const fetchImpl = input.fetchImpl ?? fetch;
  let providerToken = "";
  let providerTokenMintedAt = 0;

  const postgrest: Postgrest = async (path, init) => {
    const response = await fetchImpl(`${supabaseUrl}${path}`, {
      method: init.method,
      headers: {
        apikey: serviceRole,
        Authorization: `Bearer ${serviceRole}`,
        "Content-Type": "application/json",
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
    if (!response.ok) {
      throw new Error(`reminder query failed: ${response.status}`);
    }
    if (response.status === 204) {
      return null;
    }
    const text = await response.text();
    if (!text) {
      return null;
    }
    return JSON.parse(text);
  };

  return {
    now: input.now,
    isAuthorized: isServiceRoleAuthorization,
    apnsConfigured: secrets != null && supabaseUrl.length > 0 && serviceRole.length > 0,
    loadPage: async (japanDate, limit, afterUserId) => {
      const payload = await postgrest("/rest/v1/rpc/daily_calorie_reminder_page", {
        method: "POST",
        body: {
          p_japan_date: japanDate,
          p_limit: limit,
          p_after_user_id: afterUserId,
        },
      });
      if (!Array.isArray(payload)) {
        return [];
      }
      return payload
        .map(reminderRowFromJson)
        .filter((row): row is ReminderRow => row != null);
    },
    claim: async (userId, japanDate) => {
      const payload = await postgrest("/rest/v1/rpc/claim_daily_calorie_reminder", {
        method: "POST",
        body: { p_user_id: userId, p_japan_date: japanDate },
      });
      return payload === true;
    },
    release: async (userId, japanDate) => {
      await postgrest("/rest/v1/rpc/release_daily_calorie_reminder", {
        method: "POST",
        body: { p_user_id: userId, p_japan_date: japanDate },
      });
    },
    dropToken: async (row) => {
      const userId = encodeURIComponent(row.user_id);
      const token = encodeURIComponent(row.device_token);
      await postgrest(
        `/rest/v1/user_push_tokens?user_id=eq.${userId}&device_token=eq.${token}`,
        { method: "DELETE" },
      );
    },
    send: async (row, body, japanDate) => {
      if (!secrets) {
        return "failed";
      }
      const nowSeconds = Math.floor(input.now().getTime() / 1000);
      if (!providerToken || nowSeconds - providerTokenMintedAt > 50 * 60) {
        providerToken = await apnsProviderToken(secrets, nowSeconds);
        providerTokenMintedAt = nowSeconds;
      }
      return await sendApnsAlert({
        secrets,
        token: row.device_token,
        environment: row.apns_environment,
        body,
        japanDate,
        providerToken,
        fetchImpl,
      });
    },
  };
}
