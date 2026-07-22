# 08 — Food Master / Public Foods / Templates (Version 1.1)

> **Document type:** Specification  
> **Status:** Version 1.1（Owner Decision 確定 — 2026-07-22）  
> **Audience:** 開発者 / AI

---

## この文書について

Version 1.1 の食品マスター・公開食品・食事テンプレート・Good/Bad 評価に関する **正式 Owner Decision** を集約する。  
実装 Phase の分割と、Supabase migration 作成時のチェックリストも含む。

---

## Owner Decision 一覧（確定）

| ID | 内容 |
|----|------|
| D1 | 摂取量は `baseAmount` + `unitType` + `consumedAmount` を保存。`multiplier = consumedAmount / baseAmount`（DB 非保存）。`quantity` は互換 getter |
| D5 | 食事テンプレート V1.1 は **private のみ**（検索・公開・共有 URL なし） |
| D15 | Good/Bad 集計は `food_rating_stats` + Trigger（`saved_foods` に count 列なし） |
| D16 | 評価オフラインキューなし。評価失敗で食事記録を失敗させない |
| D17 | 20件/時間・100件/日。変更・取消もカウント。同一食品に数秒クールダウン（具体秒数は実装時 3〜5秒） |
| D18 | アカウント削除時 `food_ratings` 削除（匿名化残存なし）→ Trigger で stats 減算 |
| D19 | `base_amount numeric(12,4)`。部分 Unique Index: `(normalized_name, unit_type, base_amount)` |
| D20 | 類似判定: 名称完全一致+base/unit 相違 / barcode 一致 / 前方一致のみ |
| D21/D22 | `badCount >= 3 && badCount > goodCount × 2` → 順位低下 + 注意表示のみ |
| D23 | 注意文言: 「低い評価が多い食品です。基準量と栄養情報を確認してから利用してください。」 |

---

## Domain Model

### SavedFood（`saved_foods`）

再利用可能な食品マスター。private / public は `visibility` で区別。

- `foodId`, `ownerUserId`
- `visibility`: private | public | unlisted（reserved）
- `status`: active | deleted | suspended
- `moderationStatus`: none | reported | under_review | hidden | suspended
- `name`, `normalizedName`
- `baseAmount` (> 0), `unitType`
- `kcalPerBase`, `proteinPerBase`, `fatPerBase`, `carbPerBase`
- `sourceType`, `barcode`, `brand`, `supplementaryWeight`
- `copiedFromFoodId`, `copiedFromOwnerUserId`
- `useCount`, `lastUsedAt`, `reportCount`（キャッシュ）
- `createdAt`, `updatedAt`, `deletedAt`

**Good/Bad 件数は `saved_foods` に持たない。** `food_rating_stats` を参照。

### FoodEntry（`food_entries` — スナップショット）

食事履歴。マスターを live 参照せず、記録時点の値を保持。

- `baseAmount`, `unitType`, `consumedAmount`
- `multiplier = consumedAmount / baseAmount`（計算値）
- `kcalPerBase` 等（旧 `*PerUnit` 相当）
- `sourceType`, `savedFoodId`, `sourceFoodOwnerUserId`
- `mealGroupId`, `mealGroupName`, `sortOrder`（テンプレート由来）
- `quantity` getter → `multiplier`（互換）

**既存データ移行（合計不変）:**

| 旧 | 新 |
|----|-----|
| `quantity` | `consumedAmount = quantity` |
| — | `baseAmount = 1` |
| — | `unitType = serving` |
| `kcal_per_unit` | `kcal_per_base`（値コピー） |

`totalKcal = kcalPerBase × (consumedAmount / baseAmount)` → 旧 `kcalPerUnit × quantity` と一致。

### MealTemplate / MealTemplateItem

V1.1 は **private のみ**。公開食品を構成要素に使用可。依存関係 Popup は §14（設計報告）参照。

### Good/Bad

- `food_ratings`: 1ユーザー×1食品=1評価（good/bad/取消）
- `food_rating_stats`: Trigger 更新（D15）
- 保守用: `food_ratings` からの再集計 SQL

---

## 完全重複 vs 類似候補

| 種別 | 条件 | 動作 |
|------|------|------|
| **完全重複** | public で `normalizedName` + `baseAmount` + `unitType` 完全一致 | public 登録不可。Popup で既存利用 / private 保存 / 修正 / キャンセル |
| **類似候補** | 名称一致+base/unit 相違 / barcode 一致 / 前方一致 | 警告のみ。登録可能 |

---

## 公開前確認 Popup

表示: 食品名、基準量・単位、kcal、P/F/C、整合性、類似食品、Good/Bad 付き完全一致食品、出典、公開の旨。

必須チェック: 「入力した食品情報と栄養値が正しいことを確認しました」

完全重複がある場合は「公開する」を **表示しない**。

---

## 実装 Phase（Owner 承認済み）

| Phase | 内容 | 停止条件 |
|-------|------|---------|
| 1 | PFC 自動計算 | — |
| 2 | FoodMaster・摂取量 Domain Model | — |
| 3 | Isar Repository | — |
| 4 | Supabase migration **作成** | **SQL 報告後停止（本番実行禁止）** |
| 5 | 公開食品・RLS | — |
| 6 | 重複防止 | — |
| 7 | Good/Bad 評価 | — |
| 8 | 食事テンプレート | — |
| 9 | 元食品変更・削除 Popup | — |
| 10 | Mobile UI | — |
| 11 | Web Preview | — |
| 12 | テスト | — |
| 13 | Documentation | — |

---

## Phase 4 Migration チェックリスト（作成時報告項目）

- 作成ファイル名
- 新規テーブル: `saved_foods`, `meal_templates`, `meal_template_items`, `food_ratings`, `food_rating_stats`, `food_reports`, (`food_usage_events` 任意)
- `food_entries` 追加列
- RLS policies
- Triggers: `updated_at`, rating stats, moderation 列保護, rate limit
- 部分 Unique Index（public 完全重複）
- rollback SQL
- 既存データ影響
- セキュリティリスク

**本番 Supabase への実行は Owner 明示承認まで禁止。**

---

## 禁止事項（常時）

- migration 無断実行
- `service_role` クライアント利用
- 既存 `food_entries` 削除
- 既存 RLS 弱体化
- web-preview → main merge
- 秘密情報の Commit / ログ出力
