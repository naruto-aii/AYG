import { handleAnalyzeMealPhoto, liveDeps } from "./handler.ts";
import { webPreflight, withWebCors } from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return webPreflight(req);
  }
  try {
    const response = await handleAnalyzeMealPhoto(req, liveDeps());
    return withWebCors(req, response);
  } catch {
    console.error("analyze-meal-photo failed");
    return withWebCors(
      req,
      new Response(
        JSON.stringify({
          ok: false,
          code: "provider_error",
          message: "推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      ),
    );
  }
});
