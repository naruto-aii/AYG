// Plus と AI データ同意の確認。問い合わせが一時的に失敗したら（通信、401、5xx など）、
// 少し待って1回だけやり直す。「行が無い」と確定したときだけ no を返す。

export class GateCheckError extends Error {
  constructor(readonly status: number | null, message = "gate check failed") {
    super(message);
    this.name = "GateCheckError";
  }
}

export type GateResult = "yes" | "no" | "unavailable";

export const gateRetryDelayMs = 300;

export type GateOptions = {
  sleep?: (ms: number) => Promise<void>;
  delayMs?: number;
  log?: (message: string) => void;
  label?: string;
};

const realSleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export async function checkGate(check: () => Promise<boolean>, options: GateOptions = {}): Promise<GateResult> {
  const sleep = options.sleep ?? realSleep;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return (await check()) ? "yes" : "no";
    } catch (error) {
      const status = error instanceof GateCheckError ? error.status : null;
      options.log?.(`${options.label ?? "gate"} check failed (attempt ${attempt + 1}, status ${status ?? "none"})`);
      if (attempt === 0) {
        await sleep(options.delayMs ?? gateRetryDelayMs);
      }
    }
  }
  return "unavailable";
}

// PostgREST の応答から「行があるか」を決める。応答が正常な配列でなければ一時的な失敗として投げる。
export function gateRowsExist(result: { ok: boolean; status: number; body: unknown }): boolean {
  if (!result.ok || !Array.isArray(result.body)) {
    throw new GateCheckError(result.status);
  }
  return result.body.length > 0;
}
