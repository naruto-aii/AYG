import { authorizeStoreImport, json } from "../_shared/store_import.ts";
import { setupOngoingAnalytics } from "../_shared/store_live.ts";

/// 社長が管理者鍵を登録したあと、手で 1 回だけ呼ぶ。
Deno.serve(async (request) => {
  if (!authorizeStoreImport(request)) {
    return json({ ok: false }, 401);
  }
  try {
    const result = await setupOngoingAnalytics();
    return json({ ok: true, ...result });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "setup failed" }, 500);
  }
});
