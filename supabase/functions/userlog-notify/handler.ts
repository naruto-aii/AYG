import {
  accountDeletionText,
  authorizeNotify,
  checkpointLabel,
  classifyStore,
  formatMention,
  isScrubbed,
  slackText,
  withExcluded,
  type CheckpointType,
  type StoreNotice,
} from "./logic.ts";

export type AccountDeletionFields = {
  deletedOn: string;
  plusStatus: string;
  plan: string;
  ageBucket: string;
};

export type NotifyJob = {
  userId: string | null;
  installId: string | null;
  checkpointType: CheckpointType | "account_deletion";
  sourceId: string;
  occurredAt: string;
  scrubbed: boolean;
  slackLabel?: string;
  accountDeletion?: AccountDeletionFields;
};

export type SubjectContext = {
  displayName: string | null;
  excluded: boolean;
};

export type StoreBundle = {
  current: StoreNotice;
  history: StoreNotice[];
};

type Inbound =
  | {
    kind: "app_event";
    sourceId: string;
    userId: string | null;
    installId: string | null;
    eventName: string;
    occurredAt: string;
  }
  | {
    kind: "session";
    sourceId: string;
    userId: string | null;
    occurredAt: string;
  }
  | {
    kind: "install_login";
    sourceId: string;
    userId: string;
    installId: string;
    occurredAt: string;
  }
  | { kind: "store"; sourceId: string }
  | {
    kind: "account_deletion";
    deletedOn: string;
    plusStatus: string;
    plan: string;
    ageBucket: string;
  };

export type NotifyDeps = {
  secret: string;
  webhookUrl: string;
  mention: string;
  claim: (job: NotifyJob) => Promise<string>;
  finish: (job: NotifyJob, status: "sent" | "failed", error: string | null) => Promise<void>;
  loadContext: (userId: string | null, installId: string | null) => Promise<SubjectContext>;
  loadStore: (sourceId: string) => Promise<StoreBundle | null>;
  postSlack: (webhookUrl: string, body: { text: string }) => Promise<{ ok: boolean; status: number }>;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function uuidOrNull(value: unknown): string | null {
  return typeof value === "string" && uuidPattern.test(value) ? value.toLowerCase() : null;
}

function requiredUuid(value: unknown): string | null {
  return uuidOrNull(value);
}

function occurredAt(value: unknown): string | null {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    return null;
  }
  return new Date(value).toISOString();
}

function isIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

function parseAccountDeletion(record: Record<string, unknown>): Inbound | null {
  const deletedOn = typeof record.deleted_on === "string" ? record.deleted_on : "";
  const plusStatus = typeof record.plus_status === "string" ? record.plus_status : "";
  const plan = typeof record.plan === "string" ? record.plan : "";
  const ageBucket = typeof record.account_age_bucket === "string" ? record.account_age_bucket : "";
  if (
    !isIsoDate(deletedOn) ||
    !/^[a-z]{1,16}$/.test(plusStatus) ||
    !/^[A-Za-z0-9._-]{1,64}$/.test(plan) ||
    !/^[0-9A-Za-z+][0-9A-Za-z+-]{0,15}$/.test(ageBucket)
  ) {
    return null;
  }
  return { kind: "account_deletion", deletedOn, plusStatus, plan, ageBucket };
}

export function parseInbound(body: unknown): Inbound | null {
  const record = asRecord(body);
  if (!record) {
    return null;
  }
  if (record.kind === "account_deletion") {
    return parseAccountDeletion(record);
  }
  const sourceId = requiredUuid(record.source_id);
  if (!sourceId) {
    return null;
  }
  if (record.kind === "store") {
    return { kind: "store", sourceId };
  }
  const when = occurredAt(record.occurred_at);
  const userId = record.user_id == null ? null : uuidOrNull(record.user_id);
  if (!when || (record.user_id != null && userId == null)) {
    return null;
  }
  if (record.kind === "session") {
    return { kind: "session", sourceId, userId, occurredAt: when };
  }
  if (record.kind === "install_login") {
    const installId = record.install_id == null ? sourceId : uuidOrNull(record.install_id);
    if (!userId || !installId || installId !== sourceId) {
      return null;
    }
    return {
      kind: "install_login",
      sourceId,
      userId,
      installId,
      occurredAt: when,
    };
  }
  if (record.kind === "app_event" && typeof record.event_name === "string") {
    const installId = record.install_id == null ? null : uuidOrNull(record.install_id);
    if (record.install_id != null && installId == null) {
      return null;
    }
    return {
      kind: "app_event",
      sourceId,
      userId,
      installId,
      eventName: record.event_name,
      occurredAt: when,
    };
  }
  return null;
}

export async function jobsForInbound(body: unknown, deps: Pick<NotifyDeps, "loadStore">): Promise<NotifyJob[] | null> {
  const inbound = parseInbound(body);
  if (!inbound) {
    return null;
  }
  if (inbound.kind === "app_event") {
    if (inbound.eventName !== "onboarding_complete") {
      return [];
    }
    return [{
      userId: inbound.userId,
      installId: inbound.installId,
      checkpointType: "onboarding_complete",
      sourceId: inbound.sourceId,
      occurredAt: inbound.occurredAt,
      scrubbed: false,
    }];
  }
  if (inbound.kind === "session" || inbound.kind === "install_login") {
    return [];
  }
  if (inbound.kind === "account_deletion") {
    return [{
      userId: null,
      installId: null,
      checkpointType: "account_deletion",
      sourceId: `${inbound.deletedOn}|${inbound.plusStatus}|${inbound.plan}|${inbound.ageBucket}`,
      occurredAt: `${inbound.deletedOn}T00:00:00.000Z`,
      scrubbed: false,
      accountDeletion: {
        deletedOn: inbound.deletedOn,
        plusStatus: inbound.plusStatus,
        plan: inbound.plan,
        ageBucket: inbound.ageBucket,
      },
    }];
  }
  const loaded = await deps.loadStore(inbound.sourceId);
  if (!loaded) {
    return [];
  }
  const checkpoint = classifyStore(loaded.current, loaded.history);
  if (!checkpoint) {
    return [];
  }
  return [{
    userId: loaded.current.userId,
    installId: null,
    checkpointType: checkpoint.type,
    sourceId: checkpoint.sourceId,
    occurredAt: checkpoint.occurredAt,
    scrubbed: isScrubbed(loaded.current),
    slackLabel: checkpoint.slackLabel,
  }];
}

async function checkpointText(
  job: NotifyJob,
  mention: string,
  deps: Pick<NotifyDeps, "loadContext">,
): Promise<string> {
  if (job.checkpointType === "account_deletion") {
    throw new Error("account_deletion");
  }
  const context = await deps.loadContext(job.userId, job.installId);
  const excluded = context.excluded || job.scrubbed;
  const label = job.slackLabel
    ? withExcluded(job.slackLabel, excluded)
    : checkpointLabel(job.checkpointType, excluded);
  return slackText({
    mention,
    userId: job.userId,
    displayName: context.displayName,
    label,
    occurredAt: job.occurredAt,
  });
}

export async function handleUserlogNotify(request: Request, deps: NotifyDeps): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("method", { status: 405 });
  }
  if (!authorizeNotify(request.headers.get("x-userlog-notify-secret") ?? "", deps.secret)) {
    return new Response("unauthorized", { status: 401 });
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response("bad json", { status: 400 });
  }
  let jobs: NotifyJob[] | null;
  try {
    jobs = await jobsForInbound(body, deps);
  } catch {
    return json({ ok: false }, 500);
  }
  if (jobs == null) {
    return new Response("bad event", { status: 400 });
  }
  if (jobs.length === 0) {
    return json({ ok: true, skipped: true });
  }
  const mention = formatMention(deps.mention);
  if (!deps.webhookUrl || !mention) {
    return json({ ok: false }, 500);
  }
  for (const job of jobs) {
    let claim = "rejected";
    try {
      claim = await deps.claim(job);
    } catch {
      return json({ ok: false }, 500);
    }
    if (claim === "duplicate") {
      continue;
    }
    if (claim !== "claimed" && claim !== "retry") {
      return json({ ok: false }, 400);
    }
    try {
      const text = job.accountDeletion
        ? accountDeletionText({
          mention,
          plan: job.accountDeletion.plan,
          ageBucket: job.accountDeletion.ageBucket,
          deletedOn: job.accountDeletion.deletedOn,
        })
        : await checkpointText(job, mention, deps);
      const posted = await deps.postSlack(deps.webhookUrl, { text });
      if (!posted.ok) {
        throw new Error("slack");
      }
      await deps.finish(job, "sent", null);
    } catch {
      try {
        await deps.finish(job, "failed", "delivery_failed");
      } catch {
        // 送信結果を書けなくても、元のアプリ操作はすでに確定している。
      }
      return json({ ok: false }, 500);
    }
  }
  return json({ ok: true });
}
