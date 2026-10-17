import { handleCookCoach, liveDeps } from "./handler.ts";
import { webPreflight, withWebCors } from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return webPreflight(req);
  }
  try {
    const response = await handleCookCoach(req, liveDeps());
    return withWebCors(req, response);
  } catch {
    console.error("cook-coach failed");
    return withWebCors(
      req,
      new Response(
        JSON.stringify({
          ok: false,
          code: "provider_error",
          message: "献立を作れませんでした。しばらくしてからもう一度試してください。",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      ),
    );
  }
});
