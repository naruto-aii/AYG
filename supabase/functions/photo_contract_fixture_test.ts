// アプリとサーバ（analyze-meal-photo）の受け渡しの形を、1つのファイルで両側から確かめる。
//
// このテストは本物の handleAnalyzeMealPhoto に縦長の写真（1200x2000）と、
// モデルが返す形（短いキー）の混んだ弁当の推定を渡し、アプリへ返す JSON を
// test/fixtures/analyze_meal_photo_ok.json と突き合わせる。アプリ側の
// test/photo_contract_test.dart が同じファイルを読み、解析・保存・同期まで通す。
// 返す形を変えたら `UPDATE_FIXTURE=1 deno test -A photo_contract_fixture_test.ts`
// で作り直し、両方のテストを通す。実際の API は呼ばない。
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleAnalyzeMealPhoto, type AnalyzeDeps } from "./analyze-meal-photo/handler.ts";
import { bytesToBase64 } from "./analyze-meal-photo/image.ts";
import type { PhotoAiRequest } from "./analyze-meal-photo/provider.ts";

const fixtureUrl = new URL("../../test/fixtures/analyze_meal_photo_ok.json", import.meta.url);

async function portraitJpeg(width: number, height: number): Promise<Uint8Array> {
  const jpeg = await import("npm:jpeg-js@0.4.4");
  const data = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      // 上端と下端に目印（赤と青の帯）。切り取られると消える。
      const top = y < height * 0.05;
      const bottom = y >= height * 0.95;
      data[i] = top ? 255 : 120;
      data[i + 1] = 120;
      data[i + 2] = bottom ? 255 : 120;
      data[i + 3] = 255;
    }
  }
  return jpeg.encode({ data, width, height }, 85).data as Uint8Array;
}

// モデルの返答（スキーマの短いキー）。13品あり、量の長い品もある。
const modelText = JSON.stringify({
  n: "幕の内弁当",
  a: "1個",
  k: 820,
  p: 32,
  f: 28,
  c: 110,
  u: 0.62,
  h: "",
  i: [
    { n: "白ごはん", a: "200g", k: 312, p: 5, f: 0.6, c: 74 },
    { n: "鮭の塩焼き", a: "1切れ（約60g）", k: 120, p: 13, f: 7, c: 0.1 },
    { n: "鶏の唐揚げ", a: "2個", k: 160, p: 10, f: 10, c: 6 },
    { n: "玉子焼き", a: "1切れ", k: 50, p: 3, f: 3, c: 2 },
    { n: "煮物（にんじん・れんこん・しいたけ・こんにゃく・里芋）", a: "にんじん1切れ、れんこん1切れ、しいたけ1個、こんにゃく1切れ、里芋1個くらい", k: 60, p: 2, f: 0.5, c: 12 },
    { n: "ポテトサラダ", a: "大さじ2", k: 50, p: 1, f: 3, c: 5 },
    { n: "漬物", a: "少し", k: 5, p: 0.2, f: 0, c: 1 },
    { n: "梅干し", a: "1個", k: 3, p: 0.1, f: 0, c: 0.6 },
    { n: "ごま", a: "少し", k: 6, p: 0.2, f: 0.5, c: 0.2 },
    { n: "きんぴらごぼう", a: "小さじ2", k: 20, p: 0.4, f: 1, c: 3 },
    { n: "かまぼこ", a: "1切れ", k: 9, p: 1, f: 0, c: 1 },
    { n: "枝豆", a: "3さや", k: 8, p: 0.7, f: 0.4, c: 0.5 },
    { n: "パセリ", a: "少し", k: 1, p: 0.1, f: 0, c: 0.1 },
  ],
});

function deps(calls: PhotoAiRequest[]): AnalyzeDeps {
  return {
    env: { ANTHROPIC_API_KEY: "test-key", PHOTO_AI_PROVIDER: "anthropic" },
    now: () => new Date("2026-10-09T00:30:00Z"),
    userId: () => Promise.resolve("user-1"),
    isPlus: () => Promise.resolve(true),
    hasConsent: () => Promise.resolve(true),
    usageRows: () => Promise.resolve([]),
    insertUsage: () => Promise.resolve("usage-1"),
    insertCollections: (rows) => Promise.resolve(rows.map(() => "collection-1")),
    providerFor: () => ({
      id: "anthropic",
      analyze: (request: PhotoAiRequest) => {
        calls.push(request);
        return Promise.resolve({
          text: modelText,
          usage: { inputTokens: 1600, outputTokens: 520, cacheReadTokens: 0, cacheWriteTokens: 0 },
        });
      },
    }),
    log: () => {},
  };
}

Deno.test("縦長写真の推定: 写真は切らずに縮めて送り、アプリへ返す形は fixture と同じ", async () => {
  const calls: PhotoAiRequest[] = [];
  const image = await portraitJpeg(1200, 2000);
  const response = await handleAnalyzeMealPhoto(
    new Request("https://example.test/analyze-meal-photo", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: JSON.stringify({ image_base64: bytesToBase64(image), dish_name: "", amount: "", note: "" }),
    }),
    deps(calls),
  );
  assertEquals(response.status, 200);
  const body = await response.json();

  // モデルへ送った写真: 縦横比はそのまま、長辺 1024、上下の目印が残っている。
  assertEquals(calls.length, 1);
  assertEquals(calls[0].maxTokens, 1200);
  const jpeg = await import("npm:jpeg-js@0.4.4");
  const sent = jpeg.decode(
    Uint8Array.from(atob(calls[0].imageJpegBase64), (c) => c.charCodeAt(0)),
    { useTArray: true, formatAsRGBA: true },
  );
  assertEquals([sent.width, sent.height], [614, 1024]);
  const pixel = (x: number, y: number) => {
    const i = (y * sent.width + x) * 4;
    return [sent.data[i], sent.data[i + 1], sent.data[i + 2]];
  };
  assert(pixel(300, 5)[0] > 200, "上端（赤い帯）が送られていない");
  assert(pixel(300, sent.height - 5)[2] > 200, "下端（青い帯）が送られていない");

  // 13品は12品にまとめ、合計は全体の値と一致する。
  assertEquals(body.ok, true);
  assertEquals(body.estimate.items.length, 12);
  const sum = body.estimate.items.reduce((total: number, item: { kcal: number }) => total + item.kcal, 0);
  assert(Math.abs(sum - body.estimate.kcal) < 0.11, `items ${sum} vs total ${body.estimate.kcal}`);

  if (Deno.env.get("UPDATE_FIXTURE") === "1") {
    await Deno.writeTextFile(fixtureUrl, JSON.stringify(body, null, 2) + "\n");
  }
  const fixture = JSON.parse(await Deno.readTextFile(fixtureUrl));
  assertEquals(body, fixture);
});
