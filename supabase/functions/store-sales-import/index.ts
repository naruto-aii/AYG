import { authorizeStoreImport, json } from "../_shared/store_import.ts";
import { salesDeps } from "../_shared/store_live.ts";
import { importSales } from "./import.ts";

Deno.serve(async (request) => {
  if (!authorizeStoreImport(request)) {
    return json({ ok: false }, 401);
  }
  const result = await importSales(salesDeps());
  return json(result);
});
