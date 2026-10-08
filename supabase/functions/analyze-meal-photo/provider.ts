// 写真の推定を出す相手。鍵は呼び出し側が渡し、このファイルには置かない。
// Gemini は 18 歳未満が使うことがあるアプリでは利用規約上使えない。初期実装は Anthropic。

import { mealEstimateSchema } from "./validate.ts";

export type PhotoTier = "light" | "heavy";

export type PhotoAiUsage = {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
};

export type PhotoAiRequest = {
  model: string;
  tier: PhotoTier;
  imageJpegBase64: string;
  dishName: string | null;
  amount: string | null;
};

export type PhotoAiResult = {
  text: string;
  usage: PhotoAiUsage;
};

export interface PhotoAiProvider {
  readonly id: string;
  analyze(request: PhotoAiRequest, apiKey: string): Promise<PhotoAiResult>;
}

export class PhotoAiConfigError extends Error {
  constructor(readonly code: "missing_key" | "provider_unwired") {
    super(code);
  }
}

export class PhotoAiCallError extends Error {
  constructor() {
    super("provider_call_failed");
  }
}

export type FetchLike = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export const mealAnalysisPrompt =
  "あなたは食事の写真から、記録用の栄養の推定を返す係です。診断や医療の判断はしません。写真に写っている食事について、料理名、量、エネルギー（kcal）、たんぱく質・脂質・炭水化物（g）を推定してください。複数の品があるときは、全体の合計と、品ごとの内訳を返してください。数値は0以上です。kcal は、たんぱく質×4 + 脂質×9 + 炭水化物×4 に近づけてください。料理名は日本語の短い名前にしてください。量はグラム、個数、杯など、分かる範囲で書いてください。confidence は 0 から 1 です。利用者の料理名や量があるときは、それを優先してください。";

export function userPrompt(dishName: string | null, amount: string | null): string {
  const name = dishName && dishName.trim() ? dishName.trim() : "（未入力）";
  const qty = amount && amount.trim() ? amount.trim() : "（未入力）";
  return `料理名: ${name}\n量: ${qty}\nこの写真の食事を推定してください。`;
}

// Sonnet 5.5 は thinking の disabled と、強制の tool_choice を 400 で拒む。
// JSON は output_config.format で受け、先に考えさせない。
export function thinkingField(model: string): { type: string } {
  if (model.includes("sonnet-5-5")) {
    return { type: "between_tools" };
  }
  return { type: "disabled" };
}

export function anthropicBody(request: PhotoAiRequest): Record<string, unknown> {
  return {
    model: request.model,
    max_tokens: 1024,
    thinking: thinkingField(request.model),
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: mealEstimateSchema },
    },
    system: mealAnalysisPrompt,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: request.imageJpegBase64,
            },
          },
          { type: "text", text: userPrompt(request.dishName, request.amount) },
        ],
      },
    ],
  };
}

export function createPhotoAiProvider(
  name: string,
  fetchImpl: FetchLike = fetch,
): PhotoAiProvider {
  switch (name.trim().toLowerCase()) {
    case "anthropic":
      return new AnthropicPhotoProvider(fetchImpl);
    case "gemini":
    case "openai":
      throw new PhotoAiConfigError("provider_unwired");
    default:
      throw new PhotoAiConfigError("provider_unwired");
  }
}

export class AnthropicPhotoProvider implements PhotoAiProvider {
  readonly id = "anthropic";

  constructor(private readonly fetchImpl: FetchLike) {}

  async analyze(request: PhotoAiRequest, apiKey: string): Promise<PhotoAiResult> {
    if (!apiKey.trim()) {
      throw new PhotoAiConfigError("missing_key");
    }
    let response: Response;
    try {
      response = await this.fetchImpl("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(anthropicBody(request)),
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
    return readAnthropicResult(body);
  }
}

export function readAnthropicResult(body: unknown): PhotoAiResult {
  if (body == null || typeof body !== "object") {
    throw new PhotoAiCallError();
  }
  const row = body as Record<string, unknown>;
  if (row.stop_reason === "max_tokens") {
    throw new PhotoAiCallError();
  }
  if (!Array.isArray(row.content)) {
    throw new PhotoAiCallError();
  }
  const text = row.content
    .filter((block): block is { type: string; text: string } => {
      return block != null &&
        typeof block === "object" &&
        (block as { type?: string }).type === "text" &&
        typeof (block as { text?: string }).text === "string";
    })
    .map((block) => block.text)
    .join("");
  if (!text.trim()) {
    throw new PhotoAiCallError();
  }
  const usage = row.usage;
  const usageRow = usage != null && typeof usage === "object"
    ? usage as Record<string, unknown>
    : {};
  return {
    text,
    usage: {
      inputTokens: tokenCount(usageRow.input_tokens),
      outputTokens: tokenCount(usageRow.output_tokens),
      cacheReadTokens: tokenCount(usageRow.cache_read_input_tokens),
      cacheWriteTokens: tokenCount(usageRow.cache_creation_input_tokens),
    },
  };
}

function tokenCount(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    return 0;
  }
  return Math.floor(value);
}
