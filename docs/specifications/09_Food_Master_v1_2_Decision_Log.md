# Food Master — Version 1.2 Decision Log（Deferred Candidates）

> **Document type:** Decision Log  
> **Status:** Updated — Owner scope review（2026-07-23）  
> **Audience:** 開発者 / Owner

---

## Version 1.1 正式スコープ（確定 — App Store UGC 最小）

- 公開食品（`saved_foods`）
- Good / Bad 評価（`food_ratings`, `food_rating_stats`）
- 完全重複防止（partial unique index）
- 公開前確認（アプリ層 Popup）
- 食品テンプレート（`meal_templates`, `meal_template_items`）
- **`food_reports`（通報）**
- **`blocked_food_creators`（作成者ブロック）**
- **`report_count` Trigger 同期**
- **公開食品 SELECT Policy にブロック除外（Option A）**
- 管理者による `moderation_status` hidden / suspended（service_role / Dashboard）
- `food_entries` 拡張列

### Version 1.1 残タスク（DB 外 — App Store 公開前）

- アプリ内運営連絡先表示（`OFF_CONTACT_EMAIL` 案）
- Support URL
- Privacy Policy
- 利用規約 / コミュニティルール（公開食品・禁止投稿・通報対応方針）
- 公開食品詳細からの通報 UI
- 食品作成者ブロック UI

---

## Version 1.2 候補一覧

| ID | 候補 | 概要 |
|----|------|------|
| V12-D1 | 高度な **Good/Bad 評価** レート制限 | D17 完全実装（20/h・100/day）— V1.1 は UI debounce + 直接 RLS |
| V12-D2 | `mutate_food_rating` RPC | 評価変更の RPC 一本化 |
| V12-D3 | 評価クールダウン（3〜5秒/食品） | RPC または Trigger |
| V12-D4 | `search_public_saved_foods` RPC | 高度な検索ランキング・全文最適化 |
| V12-D5 | 専用管理者 Web 画面 | Supabase Dashboard 以外の運用 UI |
| V12-D6 | 信頼スコア | Good/Bad + 通報からの複合スコア |
| V12-D7 | CAPTCHA / IP / 端末分析 | スパム抑止の強化 |
| V12-D8 | ML スパム検知 | 自動分類 |
| V12-D9 | `food_usage_events` | 利用イベント分析 |
| V12-D10 | 作成者へのアプリ内警告・通知 | 通報・モデレーション通知 |
| V12-D11 | 修正提案機能 | ユーザーからの修正提案ワークフロー |

---

## 公開検索方式（V1.1 確定）

| 案 | 採用 | 理由 |
|----|------|------|
| **A: RLS Policy で `blocked_food_creators` 参照** | **V1.1 採用** | 検索・ID 詳細が同一 Policy でブロック除外。SECURITY DEFINER 不要 |
| B: SECURITY DEFINER 検索 RPC | V1.2 | 高度ランキング時に再検討 |
| C: Policy + RPC 併用 | 不採用 | 二重保守 |

---

## テンプレート × ブロック作成者（V1.1 提案）

- スナップショット行は削除しない
- テンプレート適用時、source owner がブロック済みなら **`source_hidden` と同様の警告**
- 過去 `FoodEntry` は変更しない

---

## 参照

- Version 1.1 仕様: `docs/specifications/08_Food_Master_Public_v1_1.md`
- Version 1.1 migration: `supabase/migrations/20260723120000_add_food_master_public_v1_1.sql`
