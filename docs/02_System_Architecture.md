# 02 — System Architecture

> **Document type:** Engineering Handbook  
> **Audience:** 将来の自分 / 共同開発者 / デザイナー / AI  
> **Status:** Version 1.1（承認済み）  
> **Last updated:** 2026-07-22  
> **前提:** [`01_Project.md`](01_Project.md)（承認済み）

---

## この章の目的

本章は、カロナビの **コード構成を説明する章ではない**。

**「なぜこのシステム構成を採用したのか」** を残すことが目的である。

- クラス名・ファイル名・ディレクトリツリーの列挙は **必要最低限** にとどめる
- 各アーキテクチャ判断について、**目的・思想・理由・代替案・トレードオフ** を記録する
- 個別の意思決定の経緯・日付・却下理由の詳細は **`04_Decision_Log.md`** に委ねる（本章では重複しない）
- 画面仕様・データモデル・API 詳細等の具体仕様は **`docs/specifications/`**（執筆予定）に委ねる

プロダクト仕様（何を作るか）は `01_Project.md` を正とする。本章は **どう組み立てるか、その理由** を扱う。

Handbook 全体のルール・分類凡例は `01_Project.md` を参照。

---

## 04 章との役割分担

| 章 | 役割 | 書くこと | 書かないこと |
|----|------|---------|-------------|
| **02（本章）** | Architecture の全体像 | レイヤー間の関係、設計思想、採用理由の概要、トレードオフ | ADR 形式の個別決定記録、実装手順 |
| **04** | 個々の意思決定の詳細 | 各判断の背景、選択肢、採用理由、トレードオフ、変更条件（ADR 形式） | アーキテクチャ全体の再説明 |

**A1〜A12** の個別 ADR は **`04_Decision_Log.md` 作成時に起票** する。現時点では本章内の判断概要で十分とする。02 章と 04 章で同じ説明を重複させない。

| 文書 | 役割 |
|------|------|
| **02（本章）** | アーキテクチャ全体像と、採用した設計方針の **要約** |
| **04** | 各判断の背景・選択肢・トレードオフ・変更条件の **詳細** |

---

## アーキテクチャ全体像

### 概念レイヤー

```
┌──────────────────────────────────────────────┐
│  UI（画面・Widget）                            │
└────────────────────┬─────────────────────────┘
                     │ ユーザー操作・表示
┌────────────────────▼─────────────────────────┐
│  App State（単一状態ハブ — Version 1.1）       │
└──────┬─────────────┬──────────────┬──────────┘
       │             │              │
       ▼             ▼              ▼
  Repositories   Services      Nutrition Engine
       │             │
       ▼             ▼
  Local Store    External APIs
  (Isar / memory)  (Supabase, OFF, Health)
```

### 【Owner Decision】— 01_Project より（プロダクト制約）

- 正式プロダクトは **モバイルアプリ**（iOS / Android）。App Store 先行
- **Web Preview** は検証・共有専用。一般向け本番 Web ではない
- 初回ログイン必須（Google / Apple ID）
- Health 連携は **オプション**
- ユーザー間のデータ分離はプロダクト要件

### 【Owner Decision】— 本章（Version 1.1 アーキテクチャ方針 — 承認済み）

Version 1.1 時点の正式な Owner Decision:

| # | 方針 |
|---|------|
| A1 | **Local First** — ユーザー体験（UX）の基準はローカルデータとし、クラウドは同期・バックアップ・複数端末利用を実現するためのレイヤー |
| A2 | **単一端末利用前提** — Version 1.1 ではマルチデバイス競合解決は **サポート対象外** |
| A3 | **正式技術スタック** — Flutter（Dart）+ Supabase（Auth + PostgreSQL + RLS） |
| A4 | **セキュリティ** — RLS を主防御とし、クライアントには anon key のみを保持する |
| A5 | **Web Preview 技術的分離** — Mobile 品質を最優先。Preview と Mobile の完全一致は保証しない。Web は Preview 用途に必要な範囲のみ実装 |
| A6 | **単一 AppController** — Version 1.1 の状態管理ハブ。Version 1.2 以降で必要性が生じた場合に分割を検討。Riverpod / Bloc 等は Version 1.1 では導入しない |
| A7 | **Repository Pattern** — UI とデータ取得方法を分離し、Web / Mobile 差分や将来の DB 変更を Repository 層で吸収する |
| A8 | **Isar（モバイルローカル DB）** — Version 1.1 ではモバイルのローカル DB として Isar を正式採用。Version 1.1 途中での SQLite 等への置換は行わない。永久採用を意味せず、将来必要時は Decision Log 更新のうえ移行を検討 |
| A9 | **Health Repository 分離** — Health 連携を独立 Repository として分離。オプション・モバイル固有・外部データソースであり、アプリ本体・永続化処理へ直接依存させない |
| A10 | **Nutrition Engine 独立 Service** — 計算ロジックを UI・状態管理・永続化から分離（計算式・係数の妥当性は 03 章 + Planned Review で別管理） |
| A11 | **Platform Builder** — Web / Mobile の UI 差分を Builder 差し替えで吸収。Mobile 共通画面を再利用し、Web 固有部分のみ差し替える |
| A12 | **手動 DI** — Version 1.1 では Composition Root での手動配線を正式採用。get_it / injectable / Riverpod Provider 等は Version 1.1 では導入しない |

各節の代替案比較・トレードオフの補足は **【Proposal】** として記載する（採用理由の本体は上記 Owner Decision）。

---

## 1. Flutter を採用した理由

**分類:** 【Owner Decision】（A3 — Flutter + Supabase 正式スタック）

| 項目 | 内容 |
|------|------|
| **目的** | iOS / Android 両対応を、Version 1.1 のリソースで実現する |
| **設計思想** | プロダクト本体はモバイル。UI とビジネスロジックを 1 コードベースで共有し、プラットフォーム差は境界レイヤー（Repository / Builder）で吸収する |
| **採用理由** | 【Owner Decision】Version 1.1 の正式クライアント技術として Flutter（Dart）を採用する。【Proposal】同一コードベースによる iOS / Android 開発、Material 3 UI、Web Preview 用ビルドの同一リポジトリ管理 |
| **代替案** | 【Proposal】ネイティブ 2 実装（Swift + Kotlin）、React Native、Kotlin Multiplatform |
| **採用しなかった理由** | 【Proposal】ネイティブ 2 実装は開発・保守コストが倍増。React Native / KMP は Version 1.1 のリソース・エコシステム（Health 連携等）の観点で過剰または不確実 |
| **メリット** | 【Proposal】単一リポジトリ、UI / ロジックの共有、開発速度 |
| **デメリット** | 【Proposal】プラットフォーム固有 API との橋渡しが必要。Web ビルドは Preview 限定（A5） |
| **今後変更予定** | Version 1.1 では変更なし。部分ネイティブ化等は 04 で検討 |

---

## 2. Local First を採用した理由

**分類:** 【Owner Decision】（A1）

| 項目 | 内容 |
|------|------|
| **目的** | 食事記録・目標確認など、**日常の高頻度操作** を快適に行える UX を実現する |
| **設計思想** | 【Owner Decision】**ユーザー体験（UX）の基準はローカルデータとし、クラウドは同期・バックアップ・複数端末利用を実現するためのレイヤー** とする。UI はネットワーク完了を待たずに応答する |
| **採用理由** | 【Owner Decision】Version 1.1 の正式データアーキテクチャ方針として Local First を採用する。【Proposal】コア体験（記録 → 残量確認）は短時間・高頻度であり、通信遅延・圏外で操作が止まると Input Minimum 原則（01）に反する |
| **代替案** | 【Proposal】Cloud First、オフラインキャッシュ付き Cloud First |
| **採用しなかった理由** | 【Proposal】Cloud First は体感速度が落ちる。キャッシュ付き Cloud First は Version 1.1 に対して設計コストが過大 |
| **メリット** | 【Proposal】オフラインでも記録・閲覧可能。UI 応答が速い。Supabase 障害時もローカル利用を継続できる |
| **デメリット** | 【Proposal】ローカルとクラウドの整合管理が必要。アカウント切替時のローカルクリアが必要 |
| **今後変更予定** | Version 1.1 では方針維持。複数端末利用の正式サポートは Version 1.2 以降で検討（§2.1 参照） |

### 2.1 単一端末利用とマルチデバイス

**分類:** 【Owner Decision】（A2）

| 項目 | 内容 |
|------|------|
| **目的** | Version 1.1 のスコープとユーザー期待値を明確にする |
| **設計思想** | Local First（A1）のもと、クラウドは同期・バックアップ **のためのレイヤー** であるが、Version 1.1 では **単一端末利用を前提** とする |
| **採用理由** | 【Owner Decision】マルチデバイス競合解決は Version 1.1 の **サポート対象外**。同一ユーザーが複数端末で同時に編集した場合の整合性は保証しない |
| **代替案** | 【Proposal】Last Write Wins、タイムスタンプベース競合解決、CRDT |
| **採用しなかった理由** | 【Owner Decision】Version 1.1 スコープ外として意図的に見送り |
| **メリット** | 【Proposal】開発コスト抑制。Local First の UX メリットを優先できる |
| **デメリット** | 【Proposal】再ログイン時の pull 等で、複数端末利用時にデータ上書きが起こりうる |
| **今後変更予定** | Version 1.2 以降で複数端末利用の正式サポートを検討する場合、04 に ADR を起票し Sync 戦略を見直す |

---

## 3. Isar と Supabase を分離した理由

**分類:** 【Owner Decision】（A8 — Isar）、（A3 — Supabase）、（A1 — 役割分担）

| 項目 | 内容 |
|------|------|
| **目的** | Local First（A1）を実現するため、ローカル永続化とクラウドを役割分担させる |
| **設計思想** | 【Owner Decision】**Isar = 端末内の UX 基準データ（A8）**、**Supabase = 同期・バックアップ・認証のレイヤー（A3 / A1）**。UI は Repository（A7）経由でのみデータに触れる |
| **採用理由** | 【Owner Decision】Version 1.1 ではモバイルのローカル DB として **Isar を正式採用** する（A8）。【Proposal】embedded DB として Local First に適合。Supabase（A3）は Auth + RLS を一体提供。同期ロジックを DataSync に集約 |
| **代替案** | 【Proposal】Supabase のみ、SQLite / drift 等への置換、Firebase |
| **採用しなかった理由** | 【Owner Decision】Version 1.1 途中での SQLite 等への置換は行わない（A8）。【Proposal】Supabase のみでは Local First 不可 |
| **メリット** | 【Proposal】オフライン UX とクラウド同期の両立。RLS によるユーザー分離（A4） |
| **デメリット** | 【Proposal】2 ストア間の同期コード維持。スキーマ変更時の Isar Entity と Supabase テーブルの二重管理 |
| **今後変更予定** | 【Owner Decision】Isar の永久採用を意味しない。保守性・互換性・パッケージ継続性・要件変化により必要があれば、**Decision Log を更新したうえで** SQLite 等への移行を検討。スキーマ変更手順は Specification / Development Guide に委譲 |

---

## 4. Repository Pattern を採用した理由

**分類:** 【Owner Decision】（A7）

| 項目 | 内容 |
|------|------|
| **目的** | UI とデータ取得・保存・同期の方法を分離する |
| **設計思想** | 【Owner Decision】**UI とデータ取得方法を分離し、Web / Mobile 差分や将来の DB 変更を Repository 層で吸収する** |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式設計として採用。【Proposal】Web Preview（A5）で Isar を除外しつつ Mobile と同一 App State を共有。テスト時 Mock 注入。Auth / Sync / Health の責務分離 |
| **代替案** | 【Proposal】UI から直接 DB/API、Service Layer のみ、Clean Architecture（UseCase 層） |
| **採用しなかった理由** | 【Proposal】直接呼び出しはプラットフォーム分岐が UI に漏れる。UseCase 層は Version 1.1 規模に対して過剰 |
| **メリット** | 【Proposal】プラットフォーム差の吸収。テスト容易性。同期・外部 API の集約 |
| **デメリット** | 【Proposal】契約 + 実装のボイラープレート。Entity ↔ ドメインモデル変換の維持コスト |
| **今後変更予定** | Version 1.1 では現構成維持。分割・統合の個別判断は 04 に記録 |

---

## 5. Web Preview を Mobile 本線と別レイヤーにした理由

**分類:** 【Owner Decision】（A5）。01 の Preview 目的と整合。

| 項目 | 内容 |
|------|------|
| **目的** | 共同開発者・デザイナー・AI が **実機なしで UI / フローを検証** できる環境を提供する |
| **設計思想** | 【Owner Decision】**Mobile 品質を最優先** とする。Web Preview は派生系統であり、**Preview と Mobile の完全一致は保証しない**。**Web は Preview 用途に必要な範囲のみ実装** する。差分は Web 専用レイヤー（別 bootstrap、in-memory Repository、Builder 注入等）に閉じ込める |
| **採用理由** | 【Owner Decision】上記技術的分離を Version 1.1 の正式設計とする。【Proposal】GitHub Pages 等での URL 共有。Isar / Health / ネイティブ Sign-In 等の Web 非対応部分を本線から除外 |
| **代替案** | 【Proposal】正式 Web 同等品質、TestFlight のみ、エミュレータ必須 |
| **採用しなかった理由** | 【Proposal】01 で一般向け Web はスコープ外。配布のみでは非エンジニアの UI レビューが困難 |
| **メリット** | 【Proposal】低コストな UI 検証・共有。Mobile 本線への Web 固有妥協を持ち込まない |
| **デメリット** | 【Owner Decision として許容】Mobile と Web で挙動差が生じうる。2 系統（DI・認証方式等）の維持コスト |
| **今後変更予定** | 一般向け Web 化は 01 の Owner Decision 変更が必要。Preview 範囲拡大（Health 等）は 01 Open Question |

---

## 6. AppController に責務を集約した理由

**分類:** 【Owner Decision】（A6）

| 項目 | 内容 |
|------|------|
| **目的** | アプリ全体の状態の **所在を 1 箇所に固定** し、画面間のデータ共有を単純化する |
| **設計思想** | 【Owner Decision】Version 1.1 では **単一 AppController** を状態管理ハブとする。UI は状態を直接永続化せず、ハブ経由で操作する。**Riverpod / Bloc 等は Version 1.1 では導入しない** |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式方針とする。【Proposal】Version 1.1 の規模では単一ハブが追いやすい。Repository 注入（A7）によりテスト可能 |
| **代替案** | 【Proposal】Riverpod / Bloc による Feature 分割、ProfileController / SyncController 分割 |
| **採用しなかった理由** | 【Owner Decision】Version 1.1 では導入しない。【Proposal】追加パッケージ・学習コスト。分割の利益より見通しの良さを優先 |
| **メリット** | 【Proposal】状態の所在が明確。画面追加時の配線が単純 |
| **デメリット** | 【Proposal】ファイル肥大化。機能増加時に変更影響が広がる |
| **今後変更予定** | 【Owner Decision】**Version 1.2 以降で必要性が生じた場合に分割を検討**。分割時は 04 に ADR を起票 |

---

## 7. Health を Repository として切り離した理由

**分類:** 【Owner Decision】（A9）。01 の Health 仕様（オプション、Web 非対応）と整合。

| 項目 | 内容 |
|------|------|
| **目的** | HealthKit / Health Connect を、コア永続化・同期パスから独立させる |
| **設計思想** | 【Owner Decision】Health 連携は **独立した Health Repository** として分離する（A9）。Health は **(1) オプション機能 (2) モバイル固有機能 (3) 権限拒否・非対応端末があり得る外部データソース (4) Web Preview では利用しない機能** であるため、**アプリ本体や永続化処理へ直接依存させない** |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式設計とする。【Proposal】取得結果を正規化して Nutrition Engine に渡す。Web ではスタブ差し替え（A5）。Mock 注入可能 |
| **代替案** | 【Proposal】AppController 内直接呼び出し、Supabase 経由のみ、Health 必須化 |
| **採用しなかった理由** | 【Proposal】直接呼び出しは Web 分岐が状態管理に漏れる。必須化は 01（オプション）に反する |
| **メリット** | 【Proposal】オプション機能の境界明確。権限拒否・非対応端末でも Activity Level 経路で本体が動作継続 |
| **デメリット** | 【Proposal】Health ON/OFF 切替・再計算の orchestration が AppController（A6）側に残る |
| **今後変更予定** | **Health Workout → 運動履歴・消費カロリー反映は別の Owner Decision**（01 Q4 — 【Open Question】）。判断後、03 / 04 で詳細化 |

---

## 8. 手動 DI（DI フレームワーク不使用）を採用した理由

**分類:** 【Owner Decision】（A12）

| 項目 | 内容 |
|------|------|
| **目的** | 依存関係の組み立てを明示的に保ち、Mobile / Web Preview の差分を Composition Root に集約する |
| **設計思想** | 【Owner Decision】Version 1.1 では **手動 DI を正式採用** する（A12）。Mobile / Web それぞれの Composition Root で Repository・Service を明示的に構築し、AppController（A6）へ注入する。**get_it / injectable / Riverpod Provider 等の DI フレームワークは Version 1.1 では導入しない** |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式方針とする。【Proposal】依存グラフが有限。Mobile / Web の Repository 差分が一目で分かる。フレームワーク lock-in 回避 |
| **代替案** | 【Proposal】get_it + injectable、Riverpod Provider、flutter_modular |
| **採用しなかった理由** | 【Owner Decision】A6 / A12 により Riverpod Provider 等は Version 1.1 非採用。【Proposal】get_it 等も現規模では setup コストに見合わない |
| **メリット** | 【Proposal】依存関係が明示的。デバッグ・AI レビュー時に追いやすい |
| **デメリット** | 【Proposal】Composition Root 肥大化。依存追加のたび手動更新 |
| **今後変更予定** | 【Owner Decision】**Version 1.2 以降**、依存数・初期化順序・ライフサイクル管理が複雑化した場合は **get_it 等の導入を再検討**。判断時は 04 に ADR を起票 |

---

## 9. Platform Builder パターンを採用した理由

**分類:** 【Owner Decision】（A11）。A5（Web Preview 技術的分離）の UI 差分吸収手段。

| 項目 | 内容 |
|------|------|
| **目的** | Mobile 本線の共通画面を **複製せず共有** し、Web Preview 固有 UI だけを差し替える |
| **設計思想** | 【Owner Decision】Web / Mobile の UI 差分は **Platform Builder による差し替え** で吸収する（A11）。(1) Mobile 本線の共通画面を可能な限り再利用 (2) Web 固有部分だけ Builder で差し替え (3) Web 画面の丸ごと複製を避ける (4) Mobile 本線へ Web 分岐を散在させない (5) Mobile 品質を最優先（A5） |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式設計とする。【Proposal】修正漏れ防止。Repository 層（A7）がデータ差分、Builder が UI 差分を担当 |
| **代替案** | 【Proposal】Web 画面完全複製、Widget 内 Web 分岐、go_router 完全分離 |
| **採用しなかった理由** | 【Proposal】完全複製は A5 に反する。Widget 内分岐は Mobile 本線の可読性を損なう |
| **メリット** | 【Proposal】共有画面の修正が 1 箇所。Mobile デフォルト挙動を維持 |
| **デメリット** | 【Proposal】Builder 注入漏れ時に Mobile UI が Web に出る |
| **今後変更予定** | Builder の命名・配置・注入箇所等の具体規約は **`04_Decision_Log.md` または Technical Specification** に委譲 |

---

## 10. Supabase をバックエンドに採用した理由

**分類:** 【Owner Decision】（A3 — Flutter + Supabase 正式スタック）

| 項目 | 内容 |
|------|------|
| **目的** | 認証・ユーザー別データ保存を **少人数チームで運用可能** な形で実現する |
| **設計思想** | 【Owner Decision】Version 1.1 の正式バックエンドとして Supabase（Auth + PostgreSQL + RLS）を採用 |
| **採用理由** | 【Owner Decision】A3 に含まれる。【Proposal】Auth と PostgreSQL の一体運用。RLS（A4）によるユーザー分離。自前 API より初期コスト低 |
| **代替案** | 【Proposal】自前 REST/GraphQL + PostgreSQL、Firebase、AWS Amplify |
| **採用しなかった理由** | 【Proposal】自前 API は運用コスト大。Firestore はリレーショナルデータ表現に不適 |
| **メリット** | 【Proposal】Auth + DB + RLS 一体。SQL ベースでスキーマ明示 |
| **デメリット** | 【Proposal】ベンダー依存。同期ロジックはクライアント側に残る |
| **今後変更予定** | Version 1.1 では維持 |

---

## 11. Nutrition Engine を独立 Service にした理由

**分類:** 【Owner Decision】（A10 — Service 分離）。計算式・係数は 【Current Implementation】+ 【Planned Review】（01 / 03 章）。

| 項目 | 内容 |
|------|------|
| **目的** | 栄養計算ロジックを UI・状態管理・永続化から分離し、単体で検証・見直し可能にする |
| **設計思想** | 【Owner Decision】**Nutrition Engine は独立 Service として UI・状態管理・永続化から分離する**（A10）。計算式・係数の妥当性は **別問題** とし、`03_Nutrition_Engine.md` + Planned Review で管理する |
| **採用理由** | 【Owner Decision】上記を Version 1.1 の正式設計とする。【Proposal】Evidence First / Complexity Inside（01）— 計算は内部で正確に。AppController（A6）の肥大化回避。Local First（A1）— 計算は端末内完結 |
| **代替案** | 【Proposal】AppController 直書き、サーバー側計算、Repository 内計算 |
| **採用しなかった理由** | 【Proposal】直書きは A6 に反する。サーバー計算は A1 と相性が悪い |
| **メリット** | 【Proposal】計算ロジックの所在が明確。式変更時の影響範囲を Service に限定 |
| **デメリット** | 【Proposal】入力前処理（日付スコープ等）が AppController 側に残る可能性 |
| **今後変更予定** | **計算式・係数:** `03_Nutrition_Engine.md` + Planned Review。**Service 分離方針:** Version 1.1 では A10 を維持 |

---

## 12. セキュリティアーキテクチャの方針

**分類:** 【Owner Decision】（A4）

| 項目 | 内容 |
|------|------|
| **目的** | ユーザー間のデータ漏洩を防ぎ、クライアント secret を最小化する |
| **設計思想** | 【Owner Decision】**RLS を主防御とし、クライアントには anon key のみを保持する**。service_role はクライアントに載せない。設定値は dart-define で注入し Git に含めない |
| **採用理由** | 【Owner Decision】A4。【Proposal】01 のユーザー分離要件を DB 層で強制。アプリバグがあっても他ユーザーデータを返しにくい |
| **代替案** | 【Proposal】アプリ層のみ user_id フィルタ、カスタム API 認可 |
| **採用しなかった理由** | 【Proposal】アプリ層のみは漏洩リスク高。カスタム API は運用コスト増 |
| **メリット** | 【Proposal】サーバー側強制のアクセス制御 |
| **デメリット** | 【Proposal】RLS ポリシーの正しさが critical path |
| **今後変更予定** | RLS 検証手順は Handbook `06_Testing.md` / Specification `08_Acceptance_Criteria.md` に委譲 |

---

## レイヤー間のデータの流れ（概念のみ）

**分類:** 【Owner Decision】A1 の具体化。実装詳細は Specification に委譲。

1. **ユーザー操作** → App State が Repository 経由で Local Store に書き込む（即時 UI 更新）
2. **App State** → バックグラウンドで DataSync が Supabase へ push（同期・バックアップ）
3. **ログイン / アカウント切替** → Local Store をクリア → Supabase から pull → App State 再構築
4. **記録変更** → Nutrition Engine が再計算 → UI 更新

※ Version 1.1 では単一端末利用を前提とし（A2）、マルチデバイス競合解決は行わない。

---

## 残存する Proposal / Open Question / Planned Review

本章の **アーキテクチャ Owner Decision（A1〜A12）は確定済み**。以下は **02 章の承認を妨げない** 分類として現状維持する。

### 【Proposal】— Owner Decision ではない

| 論点 | 備考 |
|------|------|
| 各判断の代替案・トレードオフの補足 | 02 各節内。採用理由の本体は A1〜A12 |
| Flutter / Supabase の不採用案の詳細 | §1, §10。04 ADR 起票時に詳細化 |
| Web Preview の具体的な in-memory 実装方式 | §5。A5 の実装手段。Specification へ委譲 |

### 【Open Question】— Owner 判断待ち

| 論点 | 参照 |
|------|------|
| Health Workout を運動履歴・消費カロリー計算へどう反映するか | 01 Q4。A9 とは **別の Owner Decision** |
| Web Preview の機能範囲を将来拡大するか | 01 / §5。A5 の範囲変更に該当 |

### 【Planned Review】— 暫定・後日再検討

| 論点 | 参照 |
|------|------|
| Nutrition Engine の計算式・係数 | 01 / `03_Nutrition_Engine.md`。A10（Service 分離）とは **別管理** |
| Nutrition Engine へ渡す食事・運動データの日付スコープ | 01 / 03 章 |

### Version 1.1 スコープ外（Owner Decision 済み — 02 章に明記）

| 論点 | 分類 | 備考 |
|------|------|------|
| マルチデバイス競合解決 | A2 — サポート対象外 | Open Question ではない |
| Version 1.2 以降の AppController 分割 | A6 | 将来検討 |
| Version 1.2 以降の get_it 等 DI 導入 | A12 | 将来検討 |
| Isar から他 DB への移行 | A8 | Decision Log 更新のうえ将来検討 |

---

## 他章・Specification への委譲

| 内容 | 参照先 |
|------|--------|
| プロダクト定義・Version 1.1 スコープ | `01_Project.md` |
| 栄養計算の式・根拠 | `03_Nutrition_Engine.md`（執筆予定） |
| 個別 ADR・却下案の詳細 | `04_Decision_Log.md`（執筆予定） |
| ビルド・dart-define・Git 運用 | `05_Development_Guide.md`（執筆予定） |
| テスト・RLS 検証手順 | `06_Testing.md`（執筆予定） |
| 画面仕様（デザイナー向け） | `specifications/03_Screen_Specification.md`（執筆予定） |
| 技術仕様・DI 詳細・同期実装 | `specifications/04_Technical_Specification.md`（執筆予定） |
| データモデル・Isar / Supabase スキーマ | `specifications/05_Data_Model_and_Database.md`（執筆予定） |
| API・外部サービス・認証フロー | `specifications/06_API_and_External_Services.md`（執筆予定） |
| Mobile / Web Preview 差分 | `specifications/07_Platform_Differences.md`（執筆予定） |

---

## 改訂履歴

| 日付 | 変更 |
|------|------|
| 2026-07-22 | 初版（コード構成中心 — 撤回） |
| 2026-07-22 | 全面見直し — 「なぜこの構成か」を主題に再執筆 |
| 2026-07-22 | Owner Decision 反映（Local First / 単一端末 / Flutter+Supabase / セキュリティ / Web Preview / AppController / Repository Pattern） |
| 2026-07-22 | Owner Decision 追認（Isar / Health Repository / Nutrition Engine Service / Platform Builder / 手動 DI） |
| 2026-07-22 | 本章正式承認（A1〜A12 を Version 1.1 Owner Decision として確定） |
