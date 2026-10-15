import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  classifyStore,
  formatJst,
  formatMention,
  isFreeTrialOffer,
  readOffer,
  slackText,
  type StoreNotice,
} from "./userlog-notify/logic.ts";
import { handleUserlogNotify, type NotifyDeps, type NotifyJob } from "./userlog-notify/handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const eventId = "22222222-2222-4222-8222-222222222222";
const secret = "s".repeat(32);
const mention = "U0FAKEOWNER1";
const webhookUrl = "https://hooks.example.test/services/userlog";

function notice(partial: Partial<StoreNotice> & Pick<StoreNotice, "notificationUuid" | "notificationType">): StoreNotice {
  return {
    subtype: null,
    userId,
    originalTransactionId: "orig-a",
    signedDate: "2026-10-14T20:17:00.000Z",
    receivedAt: "2026-10-14T20:17:01.000Z",
    verificationStatus: "verified",
    offerType: null,
    offerDiscountType: null,
    priceMilliunits: null,
    decodedPayload: null,
    signedPayload: null,
    ...partial,
  };
}

function jws(payload: unknown): string {
  const json = JSON.stringify(payload);
  const bytes = new TextEncoder().encode(json);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const body = btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  return `aaa.${body}.sig`;
}

Deno.test("JST shows the release instant as the next morning", () => {
  assertEquals(formatJst("2026-10-14T20:17:00.000Z"), "2026-10-15 05:17 JST");
  assertEquals(formatJst("2026-10-14T15:00:00.000Z"), "2026-10-15 00:00 JST");
});

Deno.test("mention comes from the supplied id", () => {
  assertEquals(formatMention(mention), `<@${mention}>`);
  assertEquals(formatMention(`<@${mention}>`), `<@${mention}>`);
  assertEquals(formatMention("not-a-member"), "");
});

Deno.test("free trial is the introductory free offer, not a paid introductory price", () => {
  assertEquals(isFreeTrialOffer({ offerType: 1, offerDiscountType: "FREE_TRIAL", priceMilliunits: 0 }), true);
  assertEquals(isFreeTrialOffer({ offerType: 1, offerDiscountType: "PAY_UP_FRONT", priceMilliunits: 0 }), false);
  assertEquals(isFreeTrialOffer({ offerType: null, offerDiscountType: null, priceMilliunits: 0 }), false);
  assertEquals(isFreeTrialOffer({ offerType: 1, offerDiscountType: null, priceMilliunits: 0 }), true);
});

Deno.test("offer fields are read from the signed transaction when columns are empty", () => {
  const row = notice({
    notificationUuid: "33333333-3333-4333-8333-333333333333",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    decodedPayload: {
      signedDate: Date.parse("2026-10-14T20:17:00.000Z"),
      data: {
        signedTransactionInfo: jws({
          offerType: 1,
          offerDiscountType: "FREE_TRIAL",
          price: 0,
          originalTransactionId: "orig-a",
        }),
      },
    },
  });
  assertEquals(readOffer(row).offerDiscountType, "FREE_TRIAL");
  assertEquals(classifyStore(row, [row])?.type, "trial_start");
});

Deno.test("INITIAL_BUY without a trial is a paid start, and only the first post-trial renewal is", () => {
  const paidInitial = notice({
    notificationUuid: "44444444-4444-4444-8444-444444444444",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerDiscountType: null,
    priceMilliunits: 480000,
  });
  assertEquals(classifyStore(paidInitial, [paidInitial])?.type, "paid_start");

  const trial = notice({
    notificationUuid: "55555555-5555-4555-8555-555555555555",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerDiscountType: "FREE_TRIAL",
    signedDate: "2026-10-14T20:17:00.000Z",
  });
  const firstRenew = notice({
    notificationUuid: "66666666-6666-4666-8666-666666666666",
    notificationType: "DID_RENEW",
    signedDate: "2026-10-21T20:17:00.000Z",
  });
  const secondRenew = notice({
    notificationUuid: "77777777-7777-4777-8777-777777777777",
    notificationType: "DID_RENEW",
    signedDate: "2026-11-21T20:17:00.000Z",
  });
  const history = [trial, firstRenew, secondRenew];
  assertEquals(classifyStore(firstRenew, history)?.type, "paid_start");
  assertEquals(classifyStore(secondRenew, history), null);

  const cancel = notice({
    notificationUuid: "88888888-8888-4888-8888-888888888888",
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    signedDate: "2026-10-16T00:00:00.000Z",
  });
  assertEquals(classifyStore(cancel, [trial, cancel])?.type, "cancel");
  assertEquals(classifyStore(firstRenew, [trial, cancel, firstRenew]), null);
});

Deno.test("EXPIRED and REFUND are their own checkpoints", () => {
  const expired = notice({
    notificationUuid: "99999999-9999-4999-8999-999999999999",
    notificationType: "EXPIRED",
    subtype: "VOLUNTARY",
  });
  const refund = notice({
    notificationUuid: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    notificationType: "REFUND",
  });
  assertEquals(classifyStore(expired, [expired])?.type, "expired");
  assertEquals(classifyStore(refund, [refund])?.type, "refund");
});

Deno.test("a scrubbed initial purchase without offer data is not guessed", () => {
  const scrubbed = notice({
    notificationUuid: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    notificationType: "INITIAL_BUY",
    userId: null,
    originalTransactionId: null,
    decodedPayload: null,
    signedPayload: null,
  });
  assertEquals(classifyStore(scrubbed, [scrubbed]), null);
});

type Memory = Map<string, string>;

function keyOf(job: NotifyJob): string {
  return `${job.userId ?? ""}|${job.checkpointType}|${job.sourceId}`;
}

function deps(memory: Memory, posts: string[], slackOk = true): NotifyDeps {
  return {
    secret,
    webhookUrl,
    mention,
    claim: (job) => {
      const key = keyOf(job);
      const status = memory.get(key);
      if (status === "sent" || status === "pending") {
        return Promise.resolve("duplicate");
      }
      if (status === "failed") {
        memory.set(key, "pending");
        return Promise.resolve("retry");
      }
      memory.set(key, "pending");
      return Promise.resolve("claimed");
    },
    finish: (job, status) => {
      memory.set(keyOf(job), status);
      return Promise.resolve();
    },
    loadContext: () => Promise.resolve({ displayName: "花子", excluded: false }),
    loadStore: () => Promise.resolve(null),
    postSlack: (_url, body) => {
      posts.push(body.text);
      return Promise.resolve({ ok: slackOk, status: slackOk ? 200 : 500 });
    },
  };
}

function post(body: unknown, header = secret): Request {
  return new Request("https://example.test/functions/v1/userlog-notify", {
    method: "POST",
    headers: { "content-type": "application/json", "x-userlog-notify-secret": header },
    body: JSON.stringify(body),
  });
}

const install = {
  kind: "app_event",
  source_id: eventId,
  user_id: userId,
  install_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  event_name: "app_install_first_open",
  occurred_at: "2026-10-14T20:17:00.000Z",
};

Deno.test("the same checkpoint posts once", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const notify = deps(memory, posts);
  const first = await handleUserlogNotify(post(install), notify);
  const second = await handleUserlogNotify(post(install), notify);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0].includes("<@U0FAKEOWNER1>"), true);
  assertEquals(posts[0].includes("ユーザーID: 11111111-1111-4111-8111-111111111111"), true);
  assertEquals(posts[0].includes("表示名: 花子"), true);
  assertEquals(posts[0].includes("種類: インストール"), true);
  assertEquals(posts[0].includes("時刻: 2026-10-15 05:17 JST"), true);
  assertEquals(posts[0].toLowerCase().includes("test"), false);
  assertEquals(memory.get(`${userId}|install|${eventId}`), "sent");
});

Deno.test("a failed webhook does not count as sent, and a retry posts once", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const failing = deps(memory, posts, false);
  const failed = await handleUserlogNotify(post(install), failing);
  assertEquals(failed.status, 500);
  assertEquals(memory.get(`${userId}|install|${eventId}`), "failed");
  const retryPosts: string[] = [];
  const again = await handleUserlogNotify(post(install), deps(memory, retryPosts, true));
  assertEquals(again.status, 200);
  assertEquals(retryPosts.length, 1);
  assertEquals(memory.get(`${userId}|install|${eventId}`), "sent");
  const extra: string[] = [];
  await handleUserlogNotify(post(install), deps(memory, extra, true));
  assertEquals(extra.length, 0);
});

Deno.test("KPI exclusion is appended to the Japanese type", async () => {
  const posts: string[] = [];
  const notify = deps(new Map(), posts);
  notify.loadContext = () => Promise.resolve({ displayName: "開発", excluded: true });
  const response = await handleUserlogNotify(post({
    kind: "session",
    source_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    user_id: userId,
    occurred_at: "2026-10-15T01:00:00.000Z",
  }), notify);
  assertEquals(response.status, 200);
  assertEquals(posts[0].includes("種類: ログイン（集計対象外）"), true);
});

Deno.test("store trial uses the transaction offer and the webhook passed in", async () => {
  const posts: string[] = [];
  const urls: string[] = [];
  const notify = deps(new Map(), posts);
  const row = notice({
    notificationUuid: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerDiscountType: "FREE_TRIAL",
  });
  notify.loadStore = () => Promise.resolve({ current: row, history: [row] });
  notify.postSlack = (url, body) => {
    urls.push(url);
    posts.push(body.text);
    return Promise.resolve({ ok: true, status: 200 });
  };
  const response = await handleUserlogNotify(post({
    kind: "store",
    source_id: row.notificationUuid,
  }), notify);
  assertEquals(response.status, 200);
  assertEquals(urls, [webhookUrl]);
  assertEquals(posts[0].includes("種類: 無料トライアル開始"), true);
  assertEquals(posts[0].includes("orig-a"), false);
});

const installLogin = (installId: string, occurredAt = "2026-10-15T01:00:00.000Z") => ({
  kind: "install_login",
  source_id: installId,
  user_id: userId,
  install_id: installId,
  occurred_at: occurredAt,
});

Deno.test("the same user and install posts one login", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const seen: string[] = [];
  const notify = deps(memory, posts);
  const installId = "12121212-1212-4121-8121-121212121212";
  notify.loadContext = (_userId, install) => {
    seen.push(install ?? "");
    return Promise.resolve({ displayName: null, excluded: false });
  };
  const first = await handleUserlogNotify(post(installLogin(installId)), notify);
  const second = await handleUserlogNotify(post(installLogin(installId)), notify);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0].includes("種類: ログイン"), true);
  assertEquals(seen, [installId]);
  assertEquals(memory.get(`${userId}|login|${installId}`), "sent");
});

Deno.test("a new install posts another login", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const notify = deps(memory, posts);
  const firstInstall = "13131313-1313-4131-8131-131313131313";
  const secondInstall = "14141414-1414-4141-8141-141414141414";
  await handleUserlogNotify(post(installLogin(firstInstall)), notify);
  const again = await handleUserlogNotify(post(installLogin(secondInstall, "2026-10-15T02:00:00.000Z")), notify);
  assertEquals(again.status, 200);
  assertEquals(posts.length, 2);
  assertEquals(memory.get(`${userId}|login|${firstInstall}`), "sent");
  assertEquals(memory.get(`${userId}|login|${secondInstall}`), "sent");
});

Deno.test("a login already recorded for the install is not posted again", async () => {
  const installId = "15151515-1515-4151-8151-151515151515";
  const memory: Memory = new Map([[`${userId}|login|${installId}`, "sent"]]);
  const posts: string[] = [];
  const response = await handleUserlogNotify(post(installLogin(installId)), deps(memory, posts));
  assertEquals(response.status, 200);
  assertEquals(posts.length, 0);
});

Deno.test("session kind remains a login during rollout", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const sessionId = "16161616-1616-4161-8161-161616161616";
  const response = await handleUserlogNotify(post({
    kind: "session",
    source_id: sessionId,
    user_id: userId,
    occurred_at: "2026-10-15T03:00:00.000Z",
  }), deps(memory, posts));
  assertEquals(response.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0].includes("種類: ログイン"), true);
  assertEquals(memory.get(`${userId}|login|${sessionId}`), "sent");
});

Deno.test("install login rejects a source that is not the install", async () => {
  const posts: string[] = [];
  const response = await handleUserlogNotify(post({
    kind: "install_login",
    source_id: "17171717-1717-4171-8171-171717171717",
    user_id: userId,
    install_id: "18181818-1818-4181-8181-181818181818",
    occurred_at: "2026-10-15T04:00:00.000Z",
  }), deps(new Map(), posts));
  assertEquals(response.status, 400);
  assertEquals(posts.length, 0);
});

Deno.test("a wrong secret does not post", async () => {
  const posts: string[] = [];
  const response = await handleUserlogNotify(post(install, "n".repeat(32)), deps(new Map(), posts));
  assertEquals(response.status, 401);
  assertEquals(posts.length, 0);
});

Deno.test("slack text keeps the display name on one line", () => {
  const text = slackText({
    mention: "<@U0FAKEOWNER1>",
    userId,
    displayName: "花子\n<@UOTHER>",
    label: "初回登録完了",
    occurredAt: "2026-10-15T00:00:00.000Z",
  });
  assertEquals(text.includes("\n<@UOTHER>"), false);
  assertEquals(text.includes("種類: 初回登録完了"), true);
});
