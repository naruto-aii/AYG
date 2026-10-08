// 文章だけの自炊コーチ。鍵はこのファイルに置かない。

import { thinkingField, type FetchLike, type PhotoAiUsage } from "../analyze-meal-photo/provider.ts";
import { PhotoAiCallError, PhotoAiConfigError } from "../analyze-meal-photo/provider.ts";
import { readAnthropicTurn } from "../analyze-meal-photo/provider.ts";
import { cookOutputSchema, cookSystemPrompt } from "./prompt.ts";

export { PhotoAiCallError, PhotoAiConfigError };

export type CookCompletion = {
  text: string;
  usage: PhotoAiUsage;
};

export function cookRequestBody(args: {
  model: string;
  maxTokens: number;
  userText: string;
}): Record<string, unknown> {
  return {
    model: args.model,
    max_tokens: args.maxTokens,
    thinking: thinkingField(args.model, "off"),
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: cookOutputSchema },
    },
    system: [
      {
        type: "text",
        text: cookSystemPrompt,
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: [
      {
        role: "user",
        content: args.userText,
      },
    ],
  };
}

export async function completeCook(args: {
  fetchImpl: FetchLike;
  apiKey: string;
  model: string;
  maxTokens: number;
  userText: string;
}): Promise<CookCompletion> {
  if (!args.apiKey.trim()) {
    throw new PhotoAiConfigError("missing_key");
  }
  let response: Response;
  try {
    response = await args.fetchImpl("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": args.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(cookRequestBody(args)),
    });
  } catch {
    throw new PhotoAiCallError();
  }
  if (!response.ok) {
    throw new PhotoAiCallError();
  }
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new PhotoAiCallError();
  }
  const turn = readAnthropicTurn(body);
  if (turn.stopReason === "max_tokens" || !turn.text.trim()) {
    throw new PhotoAiCallError();
  }
  return { text: turn.text, usage: turn.usage };
}
