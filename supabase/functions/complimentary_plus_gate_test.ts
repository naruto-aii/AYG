import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { liveDeps as photoLiveDeps } from "./analyze-meal-photo/handler.ts";
import { liveDeps as cookLiveDeps } from "./cook-coach/handler.ts";
import { liveDeps as lookupLiveDeps } from "./lookup-food-text/handler.ts";
import {
  plusFromEntitlementOrGrant,
  readComplimentaryPlus,
} from "./_shared/complimentary_plus_gate.ts";
import { GateCheckError } from "./_shared/gate_check.ts";

const now = new Date("2026-10-16T00:00:00Z");
const env = {
  SUPABASE_URL: "https://example.test",
  SUPABASE_SERVICE_ROLE_KEY: "service-test",
  SUPABASE_ANON_KEY: "anon-test",
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("an entitlement row is plus and does not ask the grant", async () => {
  let asked = false;
  const plus = await plusFromEntitlementOrGrant(
    { ok: true, status: 200, body: [{ user_id: "u" }] },
    () => {
      asked = true;
      return Promise.resolve(false);
    },
  );
  assertEquals(plus, true);
  assertEquals(asked, false);
});

Deno.test("a failed entitlement read still throws and does not ask the grant", async () => {
  let asked = false;
  await assertRejects(
    () =>
      plusFromEntitlementOrGrant(
        { ok: false, status: 503, body: { message: "down" } },
        () => {
          asked = true;
          return Promise.resolve(true);
        },
      ),
    GateCheckError,
  );
  assertEquals(asked, false);
});

Deno.test("an empty entitlement uses the grant, and a grant failure stays false", async () => {
  assertEquals(
    await plusFromEntitlementOrGrant(
      { ok: true, status: 200, body: [] },
      () => Promise.resolve(true),
    ),
    true,
  );
  assertEquals(
    await plusFromEntitlementOrGrant(
      { ok: true, status: 200, body: [] },
      () => Promise.resolve(false),
    ),
    false,
  );
  assertEquals(
    await plusFromEntitlementOrGrant(
      { ok: true, status: 200, body: [] },
      () => Promise.reject(new Error("grant down")),
    ),
    false,
  );
});

Deno.test("the grant call is service role and accepts only boolean true", async () => {
  let method = "";
  let auth = "";
  let body = "";
  const fetchImpl = (input: string, init?: RequestInit) => {
    method = init?.method ?? "";
    auth = new Headers(init?.headers).get("Authorization") ?? "";
    body = String(init?.body ?? "");
    assertEquals(input, "https://example.test/rest/v1/rpc/user_has_complimentary_plus");
    return Promise.resolve(jsonResponse(200, true));
  };
  assertEquals(
    await readComplimentaryPlus("https://example.test", "service-test", "user-1", fetchImpl),
    true,
  );
  assertEquals(method, "POST");
  assertEquals(auth, "Bearer service-test");
  assertEquals(body.includes("user-1"), true);
  assertEquals(
    await readComplimentaryPlus(
      "https://example.test",
      "service-test",
      "user-1",
      () => Promise.resolve(jsonResponse(200, false)),
    ),
    false,
  );
  assertEquals(
    await readComplimentaryPlus(
      "https://example.test",
      "service-test",
      "user-1",
      () => Promise.resolve(jsonResponse(500, { message: "down" })),
    ),
    false,
  );
});

Deno.test("photo, cook, and food search OR the grant only after an empty entitlement", async () => {
  const makers = [photoLiveDeps, cookLiveDeps, lookupLiveDeps];
  for (const make of makers) {
    const grantCalls: string[] = [];
    const entitled = make(env, (input) => {
      const url = String(input);
      if (url.includes("/rpc/user_has_complimentary_plus")) {
        grantCalls.push(url);
      }
      return Promise.resolve(jsonResponse(200, [{ user_id: "user-1" }]));
    });
    assertEquals(await entitled.isPlus("user-1", now), true);
    assertEquals(grantCalls.length, 0);

    const granted = make(env, (input) => {
      const url = String(input);
      if (url.includes("calonavi_plus_entitlements")) {
        return Promise.resolve(jsonResponse(200, []));
      }
      return Promise.resolve(jsonResponse(200, true));
    });
    assertEquals(await granted.isPlus("user-1", now), true);

    const ordinary = make(env, (input) => {
      const url = String(input);
      if (url.includes("calonavi_plus_entitlements")) {
        return Promise.resolve(jsonResponse(200, []));
      }
      return Promise.resolve(jsonResponse(200, false));
    });
    assertEquals(await ordinary.isPlus("user-1", now), false);

    const grantDown = make(env, (input) => {
      const url = String(input);
      if (url.includes("calonavi_plus_entitlements")) {
        return Promise.resolve(jsonResponse(200, []));
      }
      return Promise.resolve(jsonResponse(503, { message: "down" }));
    });
    assertEquals(await grantDown.isPlus("user-1", now), false);

    const entitlementDown = make(env, () =>
      Promise.resolve(jsonResponse(503, { message: "down" }))
    );
    await assertRejects(() => entitlementDown.isPlus("user-1", now), GateCheckError);
  }
});
