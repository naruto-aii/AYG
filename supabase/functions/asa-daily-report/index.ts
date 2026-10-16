import { pemToPkcs8, signAppleAdsClientSecret } from "./jwt.ts";
import { withBackoff, type Backoff, type DayReport, type StoredPost } from "./parse.ts";
import { dayPayload, ReportError, runAsaDailyReport, type AsaDeps, type ReportCall } from "./report.ts";
import { authorizeStoreImport, json } from "./text.ts";

// Apple Ads Campaign Management API v5。
// アクセストークンは client secret JWT を https://appleid.apple.com/auth/oauth2/token で交換する。
// scope は searchadsorg。呼び出しは Authorization Bearer と X-AP-Context: orgId=...。

const tokenUrl = "https://appleid.apple.com/auth/oauth2/token";
const apiRoot = "https://api.searchads.apple.com/api/v5";

const backoff: Backoff = {
  initialMs: 500,
  maxAttempts: 3,
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new ReportError("missing_secret");
  return value;
}

function orgId(): string {
  const value = required("ASA_ORG_ID");
  if (!/^\d{1,20}$/.test(value)) throw new ReportError("invalid_org");
  return value;
}

function serviceHeaders(): Headers {
  const key = required("SUPABASE_SERVICE_ROLE_KEY");
  const headers = new Headers();
  headers.set("apikey", key);
  headers.set("authorization", `Bearer ${key}`);
  headers.set("content-type", "application/json");
  return headers;
}

function restBase(): string {
  return required("SUPABASE_URL").replace(/\/$/, "");
}

async function rpc(op: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${restBase()}/rest/v1/rpc/asa_daily_report_rpc`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({ p_op: op, p_body: body }),
  });
  if (!response.ok) throw new ReportError(`rpc_${response.status}`);
  return await response.json();
}

function asNumber(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : 0;
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

async function accessToken(): Promise<string> {
  const clientId = required("ASA_CLIENT_ID");
  const clientSecret = await signAppleAdsClientSecret({
    clientId,
    teamId: required("ASA_TEAM_ID"),
    keyId: required("ASA_KEY_ID"),
    pkcs8: pemToPkcs8(required("ASA_PRIVATE_KEY")),
    nowSeconds: Math.floor(Date.now() / 1000),
  });
  const response = await withBackoff(async () => {
    const result = await fetch(tokenUrl, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        client_id: clientId,
        client_secret: clientSecret,
        scope: "searchadsorg",
      }),
    });
    return { status: result.status, response: result };
  }, backoff);
  if (response.status !== 200) throw new ReportError(`apple_token_${response.status}`);
  const payload = await readJson(response.response);
  const token = payload && typeof payload === "object"
    ? (payload as Record<string, unknown>).access_token
    : null;
  if (typeof token !== "string" || token.length === 0) throw new ReportError("apple_token");
  return token;
}

function reportUrl(call: ReportCall): string {
  if (call.kind === "campaigns") return `${apiRoot}/reports/campaigns`;
  return `${apiRoot}/reports/campaigns/${call.campaignId}/keywords`;
}

function reportBody(call: ReportCall): string {
  return JSON.stringify({
    startTime: call.startTime,
    endTime: call.endTime,
    timeZone: call.timeZone,
    granularity: call.granularity,
    returnRecordsWithNoMetrics: true,
    returnRowTotals: true,
    returnGrandTotals: false,
    selector: {
      orderBy: [{ field: "localSpend", sortOrder: "DESCENDING" }],
      pagination: { offset: call.offset, limit: call.limit },
    },
  });
}

function liveDeps(): AsaDeps {
  const id = orgId();
  let token = "";
  const headers = async (withOrg: boolean): Promise<Headers> => {
    if (!token) token = await accessToken();
    const result = new Headers();
    result.set("Authorization", `Bearer ${token}`);
    if (withOrg) result.set("X-AP-Context", `orgId=${id}`);
    return result;
  };
  return {
    now: () => new Date(),
    orgId: id,
    backoff,
    getPost: async (dataDate) => {
      const body = await rpc("get_post", { report_type: "daily", data_date: dataDate }) as {
        status?: string;
        attempt?: number;
        updated_at_ms?: number;
      };
      if (body.status == null || body.status === "none") return null;
      if (body.status !== "reserved" && body.status !== "posted" && body.status !== "failed") return null;
      const post: StoredPost = {
        status: body.status,
        attempt: asNumber(body.attempt) || 1,
        updatedAtMs: asNumber(body.updated_at_ms),
      };
      return post;
    },
    claim: async (dataDate) => {
      const body = await rpc("claim", { report_type: "daily", data_date: dataDate }) as { result?: string };
      return body.result === "claimed";
    },
    finish: async (dataDate, status) => {
      await rpc("finish", { report_type: "daily", data_date: dataDate, status });
    },
    saveDay: async (day: DayReport) => {
      await rpc("save_day", dayPayload(day));
    },
    fetchOrg: async () => {
      // 組織一覧は org ヘッダなしで取る。秘密の orgId が一覧にあるときだけレポートを取る。
      const response = await fetch(`${apiRoot}/acls`, { headers: await headers(false) });
      return { status: response.status, body: await readJson(response) };
    },
    fetchReport: async (call) => {
      if (call.kind === "keywords" && !/^\d{1,20}$/.test(call.campaignId)) {
        throw new ReportError("invalid_campaign");
      }
      const headersForReport = await headers(true);
      headersForReport.set("content-type", "application/json");
      const response = await fetch(reportUrl(call), {
        method: "POST",
        headers: headersForReport,
        body: reportBody(call),
      });
      return { status: response.status, body: await readJson(response) };
    },
    postSlack: async (text) => {
      const url = required("SLACK_DAILY_REPORT_WEBHOOK_URL");
      const result = await withBackoff(async () => {
        const response = await fetch(url, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ text }),
        });
        return { status: response.status };
      }, backoff);
      return result.status >= 200 && result.status < 300;
    },
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ ok: false }, 405);
  if (!authorizeStoreImport(request)) return json({ ok: false }, 401);
  try {
    const result = await runAsaDailyReport(liveDeps());
    return json({ ok: true, posted: result.posted, skipped: result.skipped, stopped: result.stopped });
  } catch (error) {
    const code = error instanceof ReportError ? error.code : "error";
    console.error("asa-daily-report failed", code);
    return json({ ok: false }, 500);
  }
});
