import {
  authorizeNotify,
  checkpointLabel,
  classifyStore,
  formatMention,
  isScrubbed,
  slackText,
  type CheckpointType,
  type StoreNotice,
} from "./logic.ts";

export type NotifyJob = {
  userId: string | null;
  installId: string | null;
  checkpointType: CheckpointType;
  sourceId: string;
  occurredAt: string;
  scrubbed: boolean;
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
  | { kind: "store"; sourceId: string };

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

export function parseInbound(body: unknown): Inbound | null {
  const record = asRecord(body);
  if (!record) {
    return null;
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
    const checkpointType: CheckpointType | null = inbound.eventName === "app_install_first_open"
      ? "install"
      : inbound.eventName === "onboarding_complete"
      ? "onboarding_complete"
      : null;
    if (!checkpointType) {
      return [];
    }
    return [{
      userId: inbound.userId,
      installId: inbound.installId,
      checkpointType,
      sourceId: inbound.sourceId,
      occurredAt: inbound.occurredAt,
      scrubbed: false,
    }];
  }
  if (inbound.kind === "session") {
    return [{
      userId: inbound.userId,
      installId: null,
      checkpointType: "login",
      sourceId: inbound.sourceId,
      occurredAt: inbound.occurredAt,
      scrubbed: false,
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
  }];
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
      const context = await deps.loadContext(job.userId, job.installId);
      const text = slackText({
        mention,
        userId: job.userId,
        displayName: context.displayName,
        label: checkpointLabel(job.checkpointType, context.excluded || job.scrubbed),
        occurredAt: job.occurredAt,
      });
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
