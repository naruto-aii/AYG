import { handleRequest } from "./handler.mjs";
import { createRuntime } from "./server.mjs";

let runtime;

function deps() {
  runtime ??= createRuntime();
  return runtime;
}

export async function dispatch(request) {
  try {
    const handled = await handleRequest(request, deps());
    if (handled) return handled;
    return new Response(JSON.stringify({ message: "not found" }), {
      status: 404,
      headers: { "content-type": "application/json; charset=utf-8" },
    });
  } catch (error) {
    console.error("vp-voice", error?.name || "error");
    return new Response(JSON.stringify({ message: "中継で失敗しました" }), {
      status: 500,
      headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
    });
  }
}
