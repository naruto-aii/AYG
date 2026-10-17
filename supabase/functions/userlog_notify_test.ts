import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  accountDeletionText,
  checkpointLabel,
  classifyStore,
  formatJst,
  formatMention,
  isFreeTrialOffer,
  readOffer,
  subscriptionCancelLabel,
  trialCancelLabel,
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

Deno.test("EXPIRED and REFUND are not posted", () => {
  const expired = notice({
    notificationUuid: "99999999-9999-4999-8999-999999999999",
    notificationType: "EXPIRED",
    subtype: "VOLUNTARY",
  });
  const refund = notice({
    notificationUuid: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    notificationType: "REFUND",
  });
  assertEquals(classifyStore(expired, [expired]), null);
  assertEquals(classifyStore(refund, [refund]), null);
});

Deno.test("a renewal without a stored free trial is not a paid start", () => {
  const renew = notice({
    notificationUuid: "abababab-abab-4aba-8aba-abababababab",
    notificationType: "DID_RENEW",
    originalTransactionId: "orig-yearly",
    signedDate: "2026-10-15T05:27:03.000Z",
    priceMilliunits: 8800000,
  });
  assertEquals(classifyStore(renew, [renew]), null);
});

Deno.test("the first renewal after a free trial is a paid start even when the price column is empty", () => {
  const trial = notice({
    notificationUuid: "bcbcbcbc-bcbc-4bcb-8bcb-bcbcbcbcbcbc",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerType: 1,
    offerDiscountType: "FREE_TRIAL",
    priceMilliunits: null,
    signedDate: "2026-10-15T03:25:22.000Z",
  });
  const renew = notice({
    notificationUuid: "cdcdcdcd-cdcd-4cdc-8cdc-cdcdcdcdcdcd",
    notificationType: "DID_RENEW",
    signedDate: "2026-10-18T03:25:21.000Z",
    priceMilliunits: 800000,
  });
  assertEquals(classifyStore(renew, [trial, renew])?.type, "paid_start");
  assertEquals(classifyStore(renew, [trial, renew])?.sourceId, "orig-a");
});

Deno.test("turning auto-renew off before the first renewal is a trial cancel", () => {
  const trial = notice({
    notificationUuid: "55555555-5555-4555-8555-555555555555",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerDiscountType: "FREE_TRIAL",
    signedDate: "2026-10-15T03:25:22.000Z",
  });
  const cancel = notice({
    notificationUuid: "dededede-dede-4ded-8ded-dededededede",
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    signedDate: "2026-10-16T00:00:00.000Z",
  });
  const renew = notice({
    notificationUuid: "efefefef-efef-4efe-8efe-efefefefefef",
    notificationType: "DID_RENEW",
    signedDate: "2026-10-18T03:25:21.000Z",
  });
  const afterPaid = notice({
    notificationUuid: "f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2",
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    signedDate: "2026-10-19T00:00:00.000Z",
  });
  const duringTrial = classifyStore(cancel, [trial, cancel]);
  assertEquals(duringTrial?.type, "cancel");
  assertEquals(duringTrial?.slackLabel, trialCancelLabel);
  const afterRenew = classifyStore(afterPaid, [trial, renew, afterPaid]);
  assertEquals(afterRenew?.type, "cancel");
  assertEquals(afterRenew?.slackLabel, subscriptionCancelLabel);

  const paidInitial = notice({
    notificationUuid: "44444444-4444-4444-8444-444444444444",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    priceMilliunits: 480000,
    signedDate: "2026-10-15T03:25:22.000Z",
  });
  assertEquals(classifyStore(cancel, [paidInitial, cancel])?.slackLabel, subscriptionCancelLabel);
  assertEquals(classifyStore(cancel, [cancel])?.slackLabel, subscriptionCancelLabel);
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

const registration = {
  kind: "app_event",
  source_id: eventId,
  user_id: userId,
  install_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  event_name: "onboarding_complete",
  occurred_at: "2026-10-14T20:17:00.000Z",
};

Deno.test("the same checkpoint posts once", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const notify = deps(memory, posts);
  const first = await handleUserlogNotify(post(registration), notify);
  const second = await handleUserlogNotify(post(registration), notify);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0].includes("<@U0FAKEOWNER1>"), true);
  assertEquals(posts[0].includes("ユーザーID: 11111111-1111-4111-8111-111111111111"), true);
  assertEquals(posts[0].includes("表示名: 花子"), true);
  assertEquals(posts[0].includes("種類: 新規会員登録"), true);
  assertEquals(posts[0].includes("時刻: 2026-10-15 05:17 JST"), true);
  assertEquals(posts[0].toLowerCase().includes("test"), false);
  assertEquals(memory.get(`${userId}|onboarding_complete|${eventId}`), "sent");
});

Deno.test("a failed webhook does not count as sent, and a retry posts once", async () => {
  const memory: Memory = new Map();
  const posts: string[] = [];
  const failing = deps(memory, posts, false);
  const failed = await handleUserlogNotify(post(registration), failing);
  assertEquals(failed.status, 500);
  assertEquals(memory.get(`${userId}|onboarding_complete|${eventId}`), "failed");
  const retryPosts: string[] = [];
  const again = await handleUserlogNotify(post(registration), deps(memory, retryPosts, true));
  assertEquals(again.status, 200);
  assertEquals(retryPosts.length, 1);
  assertEquals(memory.get(`${userId}|onboarding_complete|${eventId}`), "sent");
  const extra: string[] = [];
  await handleUserlogNotify(post(registration), deps(memory, extra, true));
  assertEquals(extra.length, 0);
});

Deno.test("KPI exclusion is appended to the Japanese type", async () => {
  const posts: string[] = [];
  const notify = deps(new Map(), posts);
  notify.loadContext = () => Promise.resolve({ displayName: "開発", excluded: true });
  const response = await handleUserlogNotify(post(registration), notify);
  assertEquals(response.status, 200);
  assertEquals(posts[0].includes("種類: 新規会員登録（集計対象外）"), true);
  assertEquals(checkpointLabel("onboarding_complete", true), "新規会員登録（集計対象外）");
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

Deno.test("install and login payloads are skipped", async () => {
  const posts: string[] = [];
  const notify = deps(new Map(), posts);
  const install = await handleUserlogNotify(post({
    kind: "app_event",
    source_id: eventId,
    user_id: userId,
    install_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    event_name: "app_install_first_open",
    occurred_at: "2026-10-14T20:17:00.000Z",
  }), notify);
  const login = await handleUserlogNotify(post(installLogin("12121212-1212-4121-8121-121212121212")), notify);
  const session = await handleUserlogNotify(post({
    kind: "session",
    source_id: "16161616-1616-4161-8161-161616161616",
    user_id: userId,
    occurred_at: "2026-10-15T03:00:00.000Z",
  }), notify);
  assertEquals(install.status, 200);
  assertEquals(login.status, 200);
  assertEquals(session.status, 200);
  assertEquals(posts.length, 0);
  assertEquals(await install.json(), { ok: true, skipped: true });
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
  const response = await handleUserlogNotify(post(registration, "n".repeat(32)), deps(new Map(), posts));
  assertEquals(response.status, 401);
  assertEquals(posts.length, 0);
});

Deno.test("slack text keeps the display name on one line", () => {
  const text = slackText({
    mention: "<@U0FAKEOWNER1>",
    userId,
    displayName: "花子\n<@UOTHER>",
    label: "新規会員登録",
    occurredAt: "2026-10-15T00:00:00.000Z",
  });
  assertEquals(text.includes("\n<@UOTHER>"), false);
  assertEquals(text.includes("種類: 新規会員登録"), true);
});

Deno.test("a trial cancel posts the trial wording and keeps the cancel record", async () => {
  const posts: string[] = [];
  const memory: Memory = new Map();
  const notify = deps(memory, posts);
  const trial = notice({
    notificationUuid: "f0f0f0f0-f0f0-40f0-80f0-f0f0f0f0f0f0",
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    offerDiscountType: "FREE_TRIAL",
    signedDate: "2026-10-15T03:25:22.000Z",
  });
  const cancel = notice({
    notificationUuid: "f1f1f1f1-f1f1-41f1-81f1-f1f1f1f1f1f1",
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    signedDate: "2026-10-16T00:00:00.000Z",
  });
  notify.loadStore = () => Promise.resolve({ current: cancel, history: [trial, cancel] });
  notify.loadContext = () => Promise.resolve({ displayName: "花子", excluded: true });
  const response = await handleUserlogNotify(post({
    kind: "store",
    source_id: cancel.notificationUuid,
  }), notify);
  assertEquals(response.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0].includes("種類: トライアル解約（集計対象外）"), true);
  assertEquals(posts[0].includes("ユーザーID:"), true);
  assertEquals(memory.get(`${userId}|cancel|${cancel.notificationUuid}`), "sent");
  assertEquals([...memory.keys()].some((key) => key.includes("trial_cancel")), false);
});

Deno.test("account deletion posts the plan and period without a user", async () => {
  const posts: string[] = [];
  const memory: Memory = new Map();
  const notify = deps(memory, posts);
  let contextCalls = 0;
  notify.loadContext = () => {
    contextCalls += 1;
    return Promise.resolve({ displayName: "花子", excluded: false });
  };
  const body = {
    kind: "account_deletion",
    deleted_on: "2026-10-17",
    plus_status: "never",
    plan: "none",
    account_age_bucket: "0-1d",
  };
  const first = await handleUserlogNotify(post(body), notify);
  const second = await handleUserlogNotify(post(body), notify);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(posts.length, 1);
  assertEquals(posts[0], accountDeletionText({
    mention: "<@U0FAKEOWNER1>",
    plan: "none",
    ageBucket: "0-1d",
    deletedOn: "2026-10-17",
  }));
  assertEquals(posts[0].includes("ユーザーID"), false);
  assertEquals(posts[0].includes("表示名"), false);
  assertEquals(posts[0].includes(userId), false);
  assertEquals(posts[0].includes("プラン: なし"), true);
  assertEquals(posts[0].includes("使った期間: 0〜1日"), true);
  assertEquals(posts[0].includes("never"), false);
  assertEquals(contextCalls, 0);
  assertEquals(memory.get("|account_deletion|2026-10-17|never|none|0-1d"), "sent");
});

Deno.test("a paid plan deletion keeps the product id", async () => {
  const text = accountDeletionText({
    mention: "<@U0FAKEOWNER1>",
    plan: "calonavi_plus_monthly",
    ageBucket: "91d+",
    deletedOn: "2026-10-17",
  });
  assertEquals(text.includes("プラン: calonavi_plus_monthly"), true);
  assertEquals(text.includes("使った期間: 91日以上"), true);
  assertEquals(text.includes("日付: 2026-10-17"), true);
});
