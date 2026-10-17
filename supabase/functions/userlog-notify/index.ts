import { handleUserlogNotify, type NotifyDeps, type NotifyJob, type StoreBundle } from "./handler.ts";
import { numberOrNull, type StoreNotice } from "./logic.ts";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`missing ${name}`);
  }
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

function restUrl(path: string): string {
  return `${required("SUPABASE_URL").replace(/\/$/, "")}/rest/v1/${path}`;
}

async function rest(path: string, body: unknown): Promise<Response> {
  return await fetch(restUrl(path), {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
}

function mapNotice(row: Record<string, unknown>): StoreNotice {
  return {
    notificationUuid: typeof row.notification_uuid === "string" ? row.notification_uuid : "",
    notificationType: typeof row.notification_type === "string" ? row.notification_type : "",
    subtype: typeof row.subtype === "string" ? row.subtype : null,
    userId: typeof row.user_id === "string" ? row.user_id : null,
    originalTransactionId: typeof row.original_transaction_id === "string"
      ? row.original_transaction_id
      : null,
    signedDate: typeof row.signed_date === "string" ? row.signed_date : null,
    receivedAt: typeof row.received_at === "string" ? row.received_at : null,
    verificationStatus: typeof row.verification_status === "string" ? row.verification_status : "",
    offerType: numberOrNull(row.offer_type),
    offerDiscountType: typeof row.offer_discount_type === "string" ? row.offer_discount_type : null,
    priceMilliunits: numberOrNull(row.price_milliunits),
    decodedPayload: row.decoded_payload ?? null,
    signedPayload: typeof row.signed_payload === "string" ? row.signed_payload : null,
  };
}

const noticeColumns = [
  "notification_uuid",
  "notification_type",
  "subtype",
  "user_id",
  "original_transaction_id",
  "signed_date",
  "received_at",
  "verification_status",
  "offer_type",
  "offer_discount_type",
  "price_milliunits",
  "decoded_payload",
  "signed_payload",
].join(",");

async function getRows(path: string): Promise<Record<string, unknown>[]> {
  const response = await fetch(restUrl(path), { headers: serviceHeaders() });
  if (!response.ok) {
    throw new Error(`store_${response.status}`);
  }
  const body = await response.json();
  return Array.isArray(body) ? body as Record<string, unknown>[] : [];
}

async function loadStore(sourceId: string): Promise<StoreBundle | null> {
  const rows = await getRows(
    `store_server_notifications?notification_uuid=eq.${encodeURIComponent(sourceId)}&select=${noticeColumns}&limit=1`,
  );
  const current = rows[0] ? mapNotice(rows[0]) : null;
  if (!current) {
    return null;
  }
  if (!current.originalTransactionId) {
    return { current, history: [current] };
  }
  const historyRows = await getRows(
    `store_server_notifications?original_transaction_id=eq.${encodeURIComponent(current.originalTransactionId)}&select=${noticeColumns}&limit=1000`,
  );
  const history = historyRows.map(mapNotice);
  if (!history.some((row) => row.notificationUuid === current.notificationUuid)) {
    history.push(current);
  }
  return { current, history };
}

async function loadContext(userId: string | null, installId: string | null) {
  const response = await rest("rpc/userlog_context", {
    p_user_id: userId,
    p_install_id: installId,
  });
  if (!response.ok) {
    throw new Error(`context_${response.status}`);
  }
  const body = await response.json();
  return {
    displayName: typeof body?.display_name === "string" ? body.display_name : null,
    excluded: body?.excluded === true,
  };
}

async function claim(job: NotifyJob): Promise<string> {
  if (job.checkpointType === "account_deletion") {
    const key = job.accountDeletion;
    if (!key) {
      throw new Error("claim_shape");
    }
    const response = await rest("rpc/userlog_account_deletion_claim", {
      p_deleted_on: key.deletedOn,
      p_plus_status: key.plusStatus,
      p_plan: key.plan,
      p_age_bucket: key.ageBucket,
    });
    if (!response.ok) {
      throw new Error(`claim_${response.status}`);
    }
    const value = await response.json();
    if (typeof value !== "string") {
      throw new Error("claim_shape");
    }
    return value;
  }
  const response = await rest("rpc/userlog_claim", {
    p_user_id: job.userId,
    p_checkpoint_type: job.checkpointType,
    p_source_id: job.sourceId,
  });
  if (!response.ok) {
    throw new Error(`claim_${response.status}`);
  }
  const value = await response.json();
  if (typeof value !== "string") {
    throw new Error("claim_shape");
  }
  return value;
}

async function finish(job: NotifyJob, status: "sent" | "failed", error: string | null): Promise<void> {
  if (job.checkpointType === "account_deletion") {
    const key = job.accountDeletion;
    if (!key) {
      throw new Error("finish_shape");
    }
    const response = await rest("rpc/userlog_account_deletion_finish", {
      p_deleted_on: key.deletedOn,
      p_plus_status: key.plusStatus,
      p_plan: key.plan,
      p_age_bucket: key.ageBucket,
      p_status: status,
      p_error: error,
    });
    if (!response.ok) {
      throw new Error(`finish_${response.status}`);
    }
    return;
  }
  const response = await rest("rpc/userlog_finish", {
    p_user_id: job.userId,
    p_checkpoint_type: job.checkpointType,
    p_source_id: job.sourceId,
    p_status: status,
    p_error: error,
  });
  if (!response.ok) {
    throw new Error(`finish_${response.status}`);
  }
}

function liveDeps(): NotifyDeps {
  return {
    secret: Deno.env.get("USERLOG_NOTIFY_SECRET") ?? "",
    webhookUrl: Deno.env.get("SLACK_USERLOG_WEBHOOK_URL") ?? "",
    mention: Deno.env.get("SLACK_USERLOG_MENTION") ?? "",
    claim,
    finish,
    loadContext,
    loadStore,
    postSlack: async (webhookUrl, body) => {
      const response = await fetch(webhookUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(4000),
      });
      return { ok: response.ok, status: response.status };
    },
  };
}

Deno.serve((request) => handleUserlogNotify(request, liveDeps()));
