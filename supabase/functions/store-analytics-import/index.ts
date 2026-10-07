import { authorizeStoreImport, json } from "../_shared/store_import.ts";
import { analyticsDeps } from "../_shared/store_live.ts";
import { importAnalytics } from "./import.ts";

Deno.serve(async (request) => {
  if (!authorizeStoreImport(request)) {
    return json({ ok: false }, 401);
  }
  const result = await importAnalytics(analyticsDeps());
  return json(result);
});
