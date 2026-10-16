/** 公式リスト価格（2026-10-07、100万トークンあたり米ドル）。為替は概算。 */
export const JPY_PER_USD = 150;
export const BUDGET_JPY = 10;
export const SAVING_JPY = 7;
export const DEFAULT_MODEL = "claude-haiku-5-5";

export const PRICES = {
  "claude-haiku-5-5": { input: 0.1, output: 0.5, cacheWrite: 0.125, cacheRead: 0.01 },
  "claude-haiku-4-5": { input: 1, output: 5, cacheWrite: 1.25, cacheRead: 0.1 },
  "claude-sonnet-5-5": { input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.1 },
  "claude-sonnet-4-6": { input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3 },
  "claude-sonnet-4-5": { input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3 },
};

export const ALLOWED_MODELS = Object.keys(PRICES);

export function emptyUsage() {
  return { input: 0, output: 0, cacheWrite: 0, cacheRead: 0 };
}

export function addUsage(total, delta) {
  return {
    input: total.input + (delta.input || 0),
    output: total.output + (delta.output || 0),
    cacheWrite: total.cacheWrite + (delta.cacheWrite || 0),
    cacheRead: total.cacheRead + (delta.cacheRead || 0),
  };
}

export function yenFromUsage(model, usage) {
  const price = PRICES[model] || PRICES[DEFAULT_MODEL];
  const usd =
    (usage.input * price.input +
      usage.output * price.output +
      usage.cacheWrite * price.cacheWrite +
      usage.cacheRead * price.cacheRead) /
    1_000_000;
  return usd * JPY_PER_USD;
}

/**
 * 30分の想定。往復40回。
 * システムとツール定義（約1250トークン）は初回だけキャッシュ作成、以降は読み。
 * 各回の新規入力は要約した履歴込みで330。リポジトリは6回、抜粋800。
 * 出力は返事70＋思考80。最後に議事録、依頼の下書き2件。
 */
export function designedMeetingUsage() {
  const turns = 40;
  const cached = 1250;
  return {
    turns,
    cacheWrite: cached,
    cacheRead: cached * (turns - 1),
    input: turns * 330 + 6 * 800 + 1200 + 2 * 400,
    output: turns * 150 + 500 + 2 * 150,
  };
}

/** キャッシュが効かず、毎回頭打ち（出力180）まで使った場合。 */
export function cappedMeetingUsage() {
  const turns = 40;
  const cached = 1250;
  return {
    turns,
    cacheWrite: 0,
    cacheRead: 0,
    input: turns * (cached + 330) + 6 * 800 + 1200 + 2 * 400,
    output: turns * 180 + 500 + 2 * 150,
  };
}

export function designedMeetingYen(model) {
  return yenFromUsage(model, designedMeetingUsage());
}

export function cappedMeetingYen(model) {
  return yenFromUsage(model, cappedMeetingUsage());
}

export function formatYen(value) {
  const number = Number(value) || 0;
  return number.toFixed(number < 10 ? 2 : 1);
}
