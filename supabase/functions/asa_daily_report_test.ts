import { assertEquals, assertRejects, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { pemToPkcs8, signAppleAdsClientSecret } from "./asa-daily-report/jwt.ts";
import {
  campaignsFromReport,
  eligibleReportDates,
  formatCpa,
  formatDailyMessage,
  formatMoney,
  jstDateString,
  keywordsFromReport,
  nextClaim,
  readOrg,
  readReportPage,
  reportWindow,
  type DayReport,
  type Metrics,
  type StoredPost,
} from "./asa-daily-report/parse.ts";
import { dayPayload, runAsaDailyReport, type AsaDeps, type HttpResult, type ReportCall } from "./asa-daily-report/report.ts";
import { authorizeStoreImport } from "./asa-daily-report/text.ts";

const orgId = "4062040";
const secret = "s".repeat(32);

function metrics(partial: Partial<Metrics> = {}): Metrics {
  return {
    impressions: 1000,
    taps: 50,
    installs: 4,
    spendCents: 80_000,
    currency: "JPY",
    installField: "totalInstalls",
    ...partial,
  };
}

function money(cents: number, currency = "JPY") {
  const sign = cents < 0 ? "-" : "";
  const absolute = Math.abs(cents);
  return {
    amount: `${sign}${Math.trunc(absolute / 100)}.${String(absolute % 100).padStart(2, "0")}`,
    currency,
  };
}

function campaignRow(
  id: number,
  appName: string,
  campaignName: string,
  rowMetrics: Metrics,
  granularity?: unknown[],
): Record<string, unknown> {
  const total = {
    impressions: rowMetrics.impressions,
    taps: rowMetrics.taps,
    totalInstalls: rowMetrics.installs,
    localSpend: money(rowMetrics.spendCents, rowMetrics.currency),
  };
  return {
    metadata: {
      campaignId: id,
      campaignName,
      app: { appName, adamId: 1 },
    },
    total,
    granularity,
  };
}

function keywordRow(
  id: number,
  keyword: string,
  matchType: string,
  rowMetrics: Metrics,
): Record<string, unknown> {
  return {
    metadata: {
      keywordId: id,
      keyword,
      matchType,
      adGroupId: 7,
      adGroupName: "完全",
    },
    total: {
      impressions: rowMetrics.impressions,
      taps: rowMetrics.taps,
      totalInstalls: rowMetrics.installs,
      localSpend: money(rowMetrics.spendCents, rowMetrics.currency),
    },
  };
}

function page(rows: unknown[], total = rows.length): HttpResult {
  return {
    status: 200,
    body: {
      data: { reportingDataResponse: { row: rows } },
      pagination: { totalResults: total, startIndex: 0, itemsPerPage: 1000 },
      error: null,
    },
  };
}

function tokyoOrg(): HttpResult {
  return {
    status: 200,
    body: {
      data: [{ orgId: Number(orgId), orgName: "カロナビ", timeZone: "Asia/Tokyo", currency: "JPY" }],
      error: null,
    },
  };
}

function posted(_date: string): StoredPost {
  return { status: "posted", attempt: 1, updatedAtMs: Date.parse("2026-10-17T00:00:00Z") };
}

function harness(nowIso: string, options?: {
  posts?: Record<string, StoredPost | null>;
  org?: HttpResult;
  report?: (call: ReportCall) => HttpResult;
  slack?: () => Promise<boolean> | boolean;
  claim?: () => boolean;
  finish?: () => Promise<void> | void;
}): {
  deps: AsaDeps;
  calls: ReportCall[];
  slackTexts: string[];
  claims: string[];
  finishes: Array<{ date: string; status: string }>;
  saved: DayReport[];
} {
  const calls: ReportCall[] = [];
  const slackTexts: string[] = [];
  const claims: string[] = [];
  const finishes: Array<{ date: string; status: string }> = [];
  const saved: DayReport[] = [];
  const deps: AsaDeps = {
    now: () => new Date(nowIso),
    orgId,
    backoff: { initialMs: 1, maxAttempts: 3, sleep: () => Promise.resolve() },
    getPost: (date) => Promise.resolve(options?.posts?.[date] ?? null),
    claim: (date) => {
      claims.push(date);
      return Promise.resolve(options?.claim ? options.claim() : true);
    },
    finish: (date, status) => {
      finishes.push({ date, status });
      return Promise.resolve(options?.finish ? options.finish() : undefined);
    },
    saveDay: (day) => {
      saved.push(day);
      return Promise.resolve();
    },
    fetchOrg: () => Promise.resolve(options?.org ?? tokyoOrg()),
    fetchReport: (call) => {
      calls.push(call);
      return Promise.resolve(options?.report ? options.report(call) : page([]));
    },
    postSlack: async (text) => {
      slackTexts.push(text);
      return options?.slack ? await options.slack() : true;
    },
  };
  return { deps, calls, slackTexts, claims, finishes, saved };
}

function markOlderPosted(target: string, nowIso: string): Record<string, StoredPost> {
  const posts: Record<string, StoredPost> = {};
  for (const date of eligibleReportDates(new Date(nowIso))) {
    if (date !== target) posts[date] = posted(date);
  }
  return posts;
}

Deno.test("日本時間の前日は、日付が終わって 6 時間たつまで対象にしない", () => {
  const before = new Date("2026-10-16T20:59:00.000Z");
  const after = new Date("2026-10-16T21:00:00.000Z");
  assertEquals(jstDateString(before), "2026-10-17");
  assertEquals(eligibleReportDates(before).includes("2026-10-16"), false);
  assertEquals(eligibleReportDates(after)[eligibleReportDates(after).length - 1], "2026-10-16");
  assertEquals(eligibleReportDates(before).includes("2026-10-15"), true);
});

Deno.test("アカウントのタイムゾーンが日本なら日次、それ以外は UTC の時間を日本時間へ足す", () => {
  assertEquals(reportWindow("2026-10-16", "Asia/Tokyo"), {
    mode: "daily",
    startTime: "2026-10-16",
    endTime: "2026-10-16",
    timeZone: "ORTZ",
    granularity: "DAILY",
  });
  assertEquals(reportWindow("2026-10-16", "America/Los_Angeles").granularity, "HOURLY");
  assertEquals(reportWindow("2026-10-16", "America/Los_Angeles").timeZone, "UTC");
});

Deno.test("カロナビ以外のキャンペーンは合計に入れない", () => {
  const parsed = campaignsFromReport([
    campaignRow(42, "カロナビ", "検索", metrics()),
    campaignRow(99, "Trip Trek", "Other", metrics({ spendCents: 10_000, currency: "USD", installs: 1 })),
  ], "daily", "2026-10-16", "JPY");
  assertEquals(parsed.ok, true);
  if (!parsed.ok) return;
  assertEquals(parsed.rows.map((row) => row.campaignId), ["42"]);
  assertEquals(parsed.rows[0].spendCents, 80_000);
});

Deno.test("時間レポートは日本時間の 24 時間だけを足す", () => {
  const insideEarly = { date: "2026-10-14 15", impressions: 10, taps: 2, totalInstalls: 1, localSpend: money(300) };
  const insideLate = { date: "2026-10-15 14", impressions: 5, taps: 1, totalInstalls: 0, localSpend: money(100) };
  const outsideBefore = { date: "2026-10-14 14", impressions: 100, taps: 100, totalInstalls: 100, localSpend: money(99_900) };
  const outsideAfter = { date: "2026-10-15 15", impressions: 100, taps: 100, totalInstalls: 100, localSpend: money(99_900) };
  const parsed = campaignsFromReport([
    campaignRow(42, "CaloNavi", "brand", metrics(), [outsideBefore, insideEarly, insideLate, outsideAfter]),
  ], "hourly", "2026-10-15", "JPY");
  assertEquals(parsed.ok, true);
  if (!parsed.ok) return;
  assertEquals(parsed.rows[0].impressions, 15);
  assertEquals(parsed.rows[0].taps, 3);
  assertEquals(parsed.rows[0].installs, 1);
  assertEquals(parsed.rows[0].spendCents, 400);
  assertEquals(formatCpa(parsed.rows[0]), "¥4");
});

Deno.test("キーワードは配信のあった行だけ残し、文面に内訳を出す", () => {
  const parsed = keywordsFromReport([
    keywordRow(1, "カロリー", "EXACT", metrics({ impressions: 600, taps: 30, installs: 3, spendCents: 60_000 })),
    keywordRow(2, "無風", "BROAD", metrics({ impressions: 0, taps: 0, installs: 0, spendCents: 0 })),
  ], "42", "daily", "2026-10-16", "JPY");
  assertEquals(parsed.ok, true);
  if (!parsed.ok) return;
  assertEquals(parsed.rows.map((row) => row.keyword), ["カロリー"]);
  const text = formatDailyMessage({
    dataDate: "2026-10-15",
    campaigns: [{ ...metrics(), campaignId: "42", campaignName: "検索" }],
    keywords: parsed.rows,
  });
  assertStringIncludes(text, "📊 カロナビ Apple Ads｜10/15（木）分　_日本時間_");
  assertStringIncludes(text, "支出額 ¥800");
  assertStringIncludes(text, "表示回数 1,000");
  assertStringIncludes(text, "タップ数 50");
  assertStringIncludes(text, "インストール数 4");
  assertStringIncludes(text, "CPA ¥200");
  assertStringIncludes(text, "・カロリー（完全一致）");
  assertEquals(text.includes("無風"), false);
  assertEquals(formatMoney(1_250, "JPY"), "¥12.50");
});

Deno.test("posted は取り直さず、失敗は待ってから、予約の期限が切れたら取り直す", () => {
  const now = Date.parse("2026-10-17T06:00:00+09:00");
  assertEquals(nextClaim({ status: "posted", attempt: 1, updatedAtMs: now - 86_400_000 }, now).action, "skip");
  assertEquals(nextClaim({ status: "failed", attempt: 1, updatedAtMs: now - 10_000 }, now).action, "skip");
  assertEquals(nextClaim({ status: "failed", attempt: 1, updatedAtMs: now - 31_000 }, now).action, "reclaim");
  assertEquals(nextClaim({ status: "reserved", attempt: 1, updatedAtMs: now - 60_000 }, now).action, "skip");
  assertEquals(nextClaim({ status: "reserved", attempt: 2, updatedAtMs: now - 31 * 60_000 }, now).action, "reclaim");
  assertEquals(nextClaim(null, now).action, "insert");
});

Deno.test("6 時前は前日を取りにいかない", async () => {
  const nowIso = "2026-10-16T20:59:00.000Z";
  const { deps, calls } = harness(nowIso, { posts: markOlderPosted("2026-10-16", nowIso) });
  const result = await runAsaDailyReport(deps);
  assertEquals(result.posted, []);
  assertEquals(calls.length, 0);
  assertEquals(result.stopped, null);
});

Deno.test("日本時間の前日がそろってから 1 回投稿し、同じ日は再送しない", async () => {
  const nowIso = "2026-10-16T21:00:00.000Z";
  const target = "2026-10-16";
  const report = (call: ReportCall): HttpResult => {
    assertEquals(call.timeZone, "ORTZ");
    assertEquals(call.granularity, "DAILY");
    assertEquals(call.startTime, target);
    assertEquals(call.endTime, target);
    if (call.kind === "campaigns") return page([campaignRow(42, "カロナビ", "検索", metrics())]);
    return page([keywordRow(9, "たんぱく質", "BROAD", metrics({ impressions: 20, taps: 4, installs: 1, spendCents: 15_000 }))]);
  };
  const first = harness(nowIso, { posts: markOlderPosted(target, nowIso), report });
  const result = await runAsaDailyReport(first.deps);
  assertEquals(result.posted, [target]);
  assertEquals(first.slackTexts.length, 1);
  assertStringIncludes(first.slackTexts[0], "10/16（金）");
  assertStringIncludes(first.slackTexts[0], "たんぱく質（部分一致）");
  assertEquals(first.saved[0].campaigns[0].campaignId, "42");
  assertEquals(dayPayload(first.saved[0]).campaigns[0].spend, "800.00");
  assertEquals(first.claims, [target]);
  assertEquals(first.finishes, [{ date: target, status: "posted" }]);

  const second = harness(nowIso, {
    posts: { ...markOlderPosted(target, nowIso), [target]: posted(target) },
    report: () => {
      throw new Error("posted day must not be fetched");
    },
  });
  const again = await runAsaDailyReport(second.deps);
  assertEquals(again.posted, []);
  assertEquals(second.slackTexts.length, 0);
});

Deno.test("Slack が失敗した日は posted にせず、予約が取れなければ送らない", async () => {
  const nowIso = "2026-10-16T21:00:00.000Z";
  const target = "2026-10-16";
  const report = (call: ReportCall): HttpResult => {
    if (call.kind === "campaigns") return page([campaignRow(42, "カロナビ", "検索", metrics())]);
    return page([]);
  };
  const failed = harness(nowIso, {
    posts: markOlderPosted(target, nowIso),
    report,
    slack: () => false,
  });
  const result = await runAsaDailyReport(failed.deps);
  assertEquals(result.posted, []);
  assertEquals(result.stopped, "slack_failed");
  assertEquals(failed.finishes, [{ date: target, status: "failed" }]);

  const raced = harness(nowIso, {
    posts: markOlderPosted(target, nowIso),
    report,
    claim: () => false,
  });
  const skipped = await runAsaDailyReport(raced.deps);
  assertEquals(skipped.posted, []);
  assertEquals(raced.slackTexts.length, 0);
});

Deno.test("カロナビのキャンペーンが無い日は投稿せず、予約もしない", async () => {
  const nowIso = "2026-10-16T21:00:00.000Z";
  const target = "2026-10-16";
  const { deps, claims, slackTexts } = harness(nowIso, {
    posts: markOlderPosted(target, nowIso),
    report: () => page([campaignRow(99, "Other", "Other", metrics())]),
  });
  const result = await runAsaDailyReport(deps);
  assertEquals(result.stopped, "no_calonavi");
  assertEquals(result.posted, []);
  assertEquals(claims, []);
  assertEquals(slackTexts, []);
});

Deno.test("組織が見つからない、またはレポートが失敗したときは送らない", async () => {
  const nowIso = "2026-10-16T21:00:00.000Z";
  const target = "2026-10-16";
  const posts = markOlderPosted(target, nowIso);
  const missing = harness(nowIso, {
    posts,
    org: { status: 200, body: { data: [{ orgId: 1, timeZone: "Asia/Tokyo", currency: "JPY" }], error: null } },
  });
  assertEquals((await runAsaDailyReport(missing.deps)).stopped, "org_not_found");
  assertEquals(missing.slackTexts, []);

  const http = harness(nowIso, {
    posts,
    report: () => ({ status: 503, body: null }),
  });
  assertEquals((await runAsaDailyReport(http.deps)).stopped, "apple_http");
  assertEquals(http.slackTexts, []);
});

Deno.test("ページをまたいだキャンペーンもカロナビだけ残す", async () => {
  const nowIso = "2026-10-16T21:00:00.000Z";
  const target = "2026-10-16";
  const filler = Array.from({ length: 1000 }, (_, index) => campaignRow(1000 + index, "Other", "x", metrics({ spendCents: 0, impressions: 0, taps: 0, installs: 0 })));
  const { deps, slackTexts } = harness(nowIso, {
    posts: markOlderPosted(target, nowIso),
    report: (call) => {
      if (call.kind === "keywords") return page([]);
      if (call.offset === 0) return page(filler, 1001);
      return page([campaignRow(42, "カロナビ", "検索", metrics())], 1001);
    },
  });
  const result = await runAsaDailyReport(deps);
  assertEquals(result.posted, [target]);
  assertStringIncludes(slackTexts[0], "支出額 ¥800");
});

Deno.test("呼び出し確認は合言葉が一致したときだけ通す", () => {
  Deno.env.set("STORE_IMPORT_SECRET", secret);
  try {
    const headers = new Headers({ "x-store-import-secret": secret });
    assertEquals(authorizeStoreImport(new Request("https://example.test", { headers })), true);
    assertEquals(authorizeStoreImport(new Request("https://example.test")), false);
    const wrong = new Headers({ "x-store-import-secret": `${"t".repeat(31)}s` });
    assertEquals(authorizeStoreImport(new Request("https://example.test", { headers: wrong })), false);
  } finally {
    Deno.env.delete("STORE_IMPORT_SECRET");
  }
});

Deno.test("openssl の prime256v1 秘密鍵で client secret JWT を作れる", async () => {
  const directory = await Deno.makeTempDir();
  const privatePath = `${directory}/asa_private.pem`;
  const publicPath = `${directory}/asa_public.pem`;
  const pkcs8Path = `${directory}/asa_pkcs8.pem`;
  const otherPath = `${directory}/other.pem`;
  const run = (args: string[]) => new Deno.Command("openssl", { args, stdout: "piped", stderr: "piped" }).output();
  const generated = await run(["ecparam", "-genkey", "-name", "prime256v1", "-noout", "-out", privatePath]);
  assertEquals(generated.code, 0);
  assertEquals((await run(["ec", "-in", privatePath, "-pubout", "-out", publicPath])).code, 0);
  assertEquals((await run(["pkcs8", "-topk8", "-nocrypt", "-in", privatePath, "-out", pkcs8Path])).code, 0);
  assertEquals((await run(["ecparam", "-genkey", "-name", "secp384r1", "-noout", "-out", otherPath])).code, 0);

  const sec1 = await Deno.readTextFile(privatePath);
  const pkcs8 = await Deno.readTextFile(pkcs8Path);
  const escaped = sec1.replaceAll("\n", "\\n");
  const nowSeconds = 1_700_000_000;
  for (const pem of [sec1, pkcs8, escaped]) {
    const token = await signAppleAdsClientSecret({
      clientId: "client-1",
      teamId: "team-1",
      keyId: "key-1",
      pkcs8: pemToPkcs8(pem),
      nowSeconds,
    });
    const [headerPart, payloadPart, signaturePart] = token.split(".");
    const header = JSON.parse(decodeBase64Url(headerPart));
    const payload = JSON.parse(decodeBase64Url(payloadPart));
    assertEquals(header, { alg: "ES256", kid: "key-1", typ: "JWT" });
    assertEquals(payload.iss, "team-1");
    assertEquals(payload.sub, "client-1");
    assertEquals(payload.aud, "https://appleid.apple.com");
    assertEquals(payload.exp - payload.iat, 20 * 60);
    const signature = decodeBase64UrlBytes(signaturePart);
    assertEquals(signature.byteLength, 64);
    const signatureCopy = new ArrayBuffer(signature.byteLength);
    new Uint8Array(signatureCopy).set(signature);
    const publicKey = await crypto.subtle.importKey(
      "spki",
      pemToDer(await Deno.readTextFile(publicPath)),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
    const verified = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      publicKey,
      signatureCopy,
      new TextEncoder().encode(`${headerPart}.${payloadPart}`),
    );
    assertEquals(verified, true);
  }
  const otherPem = await Deno.readTextFile(otherPath);
  await assertRejects(async () => {
    pemToPkcs8(otherPem);
  }, Error, "unsupported private key");
  await Deno.remove(directory, { recursive: true });
});

Deno.test("組織とレポートの囲みを読む", () => {
  assertEquals(readOrg(tokyoOrg().body, orgId).timeZone, "Asia/Tokyo");
  assertEquals(readOrg(tokyoOrg().body, "1").found, false);
  const parsed = readReportPage(page([campaignRow(1, "カロナビ", "検索", metrics())]).body);
  assertEquals(parsed?.rows.length, 1);
  assertEquals(readReportPage({ error: { errors: [{ messageCode: "INVALID" }] } }), null);
});

function decodeBase64Url(value: string): string {
  return new TextDecoder().decode(decodeBase64UrlBytes(value));
}

function decodeBase64UrlBytes(value: string): Uint8Array {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") + "=".repeat((4 - value.length % 4) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes.buffer;
}
