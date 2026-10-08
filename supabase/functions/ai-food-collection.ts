// AIが返した食品を収集する。検索や他の利用者には出さない。

import type { FetchLike } from "./analyze-meal-photo/provider.ts";

export type FoodCollectionSource = "ai_search" | "photo";

export type FoodCollectionRow = {
  userId: string;
  sourcePath: FoodCollectionSource;
  normalizedName: string;
  chainName: string | null;
  amount: string;
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  model: string;
};

export async function collectIds(
  insert: ((rows: FoodCollectionRow[]) => Promise<Array<string | null>>) | undefined,
  rows: FoodCollectionRow[],
): Promise<Array<string | null>> {
  const none: Array<string | null> = rows.map(() => null);
  if (!insert) {
    return none;
  }
  const pending = rows
    .map((row, index) => ({ row, index }))
    .filter((item) =>
      item.row.normalizedName.length >= 1 && item.row.normalizedName.length <= 80
    );
  if (pending.length === 0) {
    return none;
  }
  try {
    const ids = await insert(pending.map((item) => item.row));
    for (let i = 0; i < pending.length; i++) {
      const id = ids[i];
      none[pending[i].index] = typeof id === "string" && id.length > 0 ? id : null;
    }
    return none;
  } catch {
    return rows.map(() => null);
  }
}

export async function insertFoodCollections(
  base: string,
  serviceKey: string,
  fetchImpl: FetchLike,
  rows: FoodCollectionRow[],
): Promise<Array<string | null>> {
  if (!base || !serviceKey || rows.length === 0) {
    return rows.map(() => null);
  }
  const response = await fetchImpl(`${base}/rest/v1/ai_food_result_collections`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(rows.map((row) => ({
      user_id: row.userId,
      source_path: row.sourcePath,
      normalized_name: row.normalizedName,
      chain_name: row.chainName,
      amount: row.amount,
      kcal: row.kcal,
      protein_g: row.proteinG,
      fat_g: row.fatG,
      carb_g: row.carbG,
      model: row.model,
      advertising_use: false,
    }))),
  });
  if (!response.ok) {
    return rows.map(() => null);
  }
  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  if (!Array.isArray(body)) {
    return rows.map(() => null);
  }
  return rows.map((_, index) => {
    const item = body[index];
    const id = item && typeof item === "object" ? (item as { id?: unknown }).id : null;
    return typeof id === "string" && id.length > 0 ? id : null;
  });
}
