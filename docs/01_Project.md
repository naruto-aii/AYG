# 01 — Project

> **Document type:** Engineering Handbook  
> **Audience:** 将来の自分 / 共同開発者 / デザイナー / AI  
> **Status:** Version 1.1（承認済み）  
> **Last updated:** 2026-07-22

---

## このドキュメントについて

カロナビ Engineering Handbook は、**現時点でのプロダクト Owner の正式な意思決定** を記録するための文書群である。

**目的:**

- コードの説明書ではない
- **設計思想・判断基準** を将来へ残すことが目的である

**コードとドキュメントが食い違った場合:**

次のいずれかを確認し、Owner の判断のもと整合を取る。

1. **コードが古い** — 実装が Owner Decision に追いついていない
2. **ドキュメントが古い** — 実装変更後に Handbook が未更新
3. **Owner Decision が変更された** — 意図的な方針変更。Decision Log を更新する

コードを自動的に正とせず、ドキュメントを自動的に正としない。

---

## Engineering Handbook のルール

### Owner Decision

- **最終意思決定者はプロダクト Owner** である
- **AI は提案・比較・レビューを行うが、仕様を決定しない**
- **正式仕様は、Owner Decision として明示的に承認されたもののみ** 採用する

### Owner Decision の更新ルール

- **Owner Decision は、プロダクト Owner の明示的な承認によってのみ変更される**
- AI や共同開発者は **【Proposal】** を作成できる
- Proposal はレビューを経て、**Owner が承認した時点で Owner Decision へ昇格** する
- Owner Decision を変更した場合は、必要に応じて **`04_Decision_Log.md` および関連ドキュメント** を更新する

### 分類凡例

| ラベル | 意味 |
|--------|------|
| **【Owner Decision】** | プロダクト Owner が明示的に決定した内容 |
| **【Current Implementation】** | 現在のコード上で確認できる実装状態 |
| **【Proposal】** | 未承認の候補・提案 |
| **【Open Question】** | Owner の判断が必要な未決定事項 |
| **【Planned Review】** | 暫定で、後日再検討する事項 |

**【Current Implementation】を【Owner Decision】として扱わない。**

---

## Version の考え方

### Version 1.1 とは

- Version は **「現時点で実装済みのもの」** を意味しない
- Version 1.1 は、**Version 1.1 として提供するプロダクト全体** を指す
- **未実装でも**、Owner が Version 1.1 に含めると決定したものは **正式スコープ** である
- **実装状態**（実装済み / 未実装 / 実装途中）は **別管理** とする

本章における Version 1.1 正式スコープと、リリース前の必須残タスクは、この考え方に基づいて記載する。

---

## この章の目的

本章は、カロナビが **何のために存在するか**、**Version 1.1 で何を目指すか** を定義する。

本章は実装説明書ではない。コードの写しではなく、**プロダクト Owner が決定した内容** と **現時点の実装状態** を分けて残す。

内部実装・Git 運用・テスト手順は `02_System_Architecture.md`、`05_Development_Guide.md`、`06_Testing.md` に委ねる。

---

## 名称

### 【Owner Decision】

| 種別 | 名称 |
|------|------|
| 会社名 | AYG |
| プロダクト名 | カロナビ |
| ユーザー向け表記 | カロナビ |

### 【Current Implementation】

技術上、以下に AYG という名称が残っている。今すぐ変更する必要はない。名称変更の技術的影響は後続タスクで検討する。

- リポジトリ名
- Bundle ID
- コード内のパッケージ名・定数（例: `AppStrings.appTitle = 'AYG'`）
- Web Preview の HTML タイトル等

---

## プロダクト一言定義

### 【Owner Decision】

カロナビは、**エネルギー管理における意思決定支援アプリ** である。

---

## Vision / Mission

### 【Open Question】

Vision / Mission / 最上位目的は、今後 Owner が確定する。

`docs/00_PROJECT.md` に過去案があるが、**現在の正式方針ではない**。参考資料として参照可能。

---

## コアターゲット

### 【Owner Decision】

**Primary Target:** 24 歳前後の日本の会社員

**ペルソナ（Version 1.1 の設計・検証の中心像）:**

- 最近、体型が気になり始めている
- 食事や運動を改善したいが、何をすべきか分からない
- カロリーや PFC を自分で計算・管理するのは面倒
- 忙しいため、複雑な入力や専門的な操作は続きにくい
- 日々の行動を分かりやすく判断できる支援を求めている

コアターゲットは、将来の利用者をこの属性だけに限定する意味ではない。Version 1.1 における設計・検証の中心人物像として扱う。

---

## 設計原則

### 【Owner Decision】

カロナビの設計判断は、以下 6 原則に従う。説明は `docs/00_PROJECT.md` Philosophy 節を基本とする。

1. **Evidence First** — 可能な限り科学的根拠を基に構築する
2. **Energy First** — エネルギー管理を中心に設計する
3. **Simplicity Outside** — ユーザーに見せる画面は可能な限りシンプルにする
4. **Complexity Inside** — 内部ロジックは可能な限り正確に設計する
5. **Input Minimum** — 入力負担は最小限。継続を最優先する
6. **Trust** — 分からないことは分からないと伝える。信頼を最優先する

### Evidence First と Nutrition Engine の関係

| 項目 | 分類 |
|------|------|
| Evidence First 原則そのもの | **【Owner Decision】** |
| 現在の Nutrition Engine の数値・計算式 | **【Current Implementation】** + **【Planned Review】** |

- Evidence First は正式な設計原則である
- 現在の Nutrition Engine の数値・計算式は Version 1.1 時点の暫定実装である
- 現在の数値を最終的に科学的に確定したという意味ではない
- 後続フェーズで論文・ガイドラインを再レビューする
- レビュー後、必要に応じて計算式・係数・安全基準を更新する

---

## プラットフォーム方針

### モバイル本線

#### 【Owner Decision】

- カロナビの **正式プロダクトはモバイルアプリ** である
- **iOS / Android の両方** を本線プラットフォームとして設計する
- **初回の正式公開は Apple App Store を優先** する
- Android も同時公開を意味する表現は用いない

#### 【Open Question】

- Google Play 公開時期

### Web Preview

#### 【Owner Decision】

Web 版は、カロナビの **正式な一般ユーザー向けプロダクトではなく**、モバイル版の検証・共有を目的とした **Preview 環境** である。

**目的:**

- 友人・関係者によるテスト
- 動作確認
- フィードバック収集
- デザイナーや開発関係者への共有
- モバイル公開前の簡易検証

現時点では一般ユーザー向け本番 Web へ発展させる予定はないが、将来の意思決定を永久に拘束するものではない。

#### 【Current Implementation】

- Web Preview は GitHub Pages 上で公開されている
- Mobile 本線と Web Preview は別 Git ブランチで管理されている

※ ブランチ名・デプロイ手順等の詳細は `05_Development_Guide.md` を参照。

---

## Version 1.1 ユーザー向け正式スコープ

以下は **【Owner Decision】** として確定した Version 1.1 のプロダクト仕様である。  
実装状態（実装済み / 未実装）は **§Version 1.1 リリース前の必須残タスク** で別途記載する。

---

### 認証・アカウント

| 仕様 |
|------|
| 初回利用時はログイン必須 |
| Google アカウント **または** Apple ID でログイン可能 |
| セッション復元 |
| ログアウト |
| ユーザー単位のデータ保存・復元 |

#### ログイン方式の Owner Decision と実装状態

| 項目 | 【Owner Decision】 | 【Current Implementation】 |
|------|-------------------|---------------------------|
| ログイン方式 | Google **または** Apple ID | — |
| Google ログイン | Version 1.1 正式スコープに含む | **実装済み** |
| Apple ログイン | Version 1.1 正式スコープに含む | **未実装** |

未実装であることは、正式スコープから外れる理由ではない。

Apple ログインの技術詳細・App Store 要件は `04_Decision_Log.md` および後続の Release / Legal 文書で扱う。

---

### 初期設定・設定変更

| 仕様 |
|------|
| 基本情報（生年月日、性別、身長、現在体重） |
| 目標（目標区分、目標体重、目標日） |
| Health 連携の利用有無 |
| Health 非利用時の活動量 |
| 上記を後から設定画面で変更可能 |
| 変更後の日次カロリー・PFC の自動再計算 |

---

### ホーム

| 仕様 |
|------|
| 目標カロリー |
| 残りカロリー |
| PFC 目標・残量 |
| 当日の食事・運動 |
| 食事・運動・体重の追加導線 |

---

### 食事

| 仕様 |
|------|
| 手入力 |
| 食事履歴 |
| バーコード番号検索 |
| カメラによるバーコード読取 |
| Open Food Facts からの商品情報取得 |
| 取得できない場合の手入力フォールバック |

---

### 運動

| 仕様 |
|------|
| 手入力 |
| 運動履歴 |
| 消費カロリーの記録 |

---

### 体重

| 仕様 |
|------|
| 手入力記録 |
| Health からの体重取得 |
| 設定からの現在体重変更 |
| 体重履歴を保持し、既存記録を上書きしない |

#### 体重タブ UI について

| 項目 | 分類 |
|------|------|
| 上記の体重記録機能 | **【Owner Decision】** — Version 1.1 正式スコープ |
| 専用タブの履歴 UI・グラフ等 | **【Open Question】** |
| 現状の体重タブがプレースホルダーであること | **【Current Implementation】** |

プレースホルダー表示は正式スコープではない。

---

### Health・活動量

| 仕様 |
|------|
| Apple Health / Health Connect との連携 |
| Health 利用時は Health データを計算に使用 |
| Health 非利用時は Activity Level を使用 |
| Health 再同期 |
| Web Preview では Health 非対応 |

#### Health Workout について

| 項目 | 分類 |
|------|------|
| 上記 Health・活動量仕様 | **【Owner Decision】** |
| Health から取得した Workout を運動履歴・消費カロリー計算へどう反映するか | **【Open Question】** |

---

### Nutrition Engine

| 仕様 |
|------|
| 基礎情報、目標、活動量または Health データから日次カロリーと PFC を計算 |
| 食事と運動の記録から残量を更新 |

#### 数値・計算式

**【Planned Review】**

- 現在の式・係数は Version 1.1 時点の暫定仕様
- 後続フェーズで論文・ガイドラインを再レビューする
- レビュー対象の例: BMR 式、7200 kcal/kg、Activity Factor、TDEE 計算、Health Active Energy の扱い、目標カロリー調整、PFC 量、運動消費の加算方法、安全上の上限・下限

計算の詳細な記録は `03_Nutrition_Engine.md`（執筆予定）に委ねる。

---

### データ保存

| 仕様 |
|------|
| 端末内保存 |
| Supabase へのクラウド保存 |
| 再起動・再ログイン後の復元 |
| ユーザー間のデータ分離 |

※ 永続化の内部方式（Isar、Repository 等）は `02_System_Architecture.md` を参照。

---

### 表示

| 仕様 |
|------|
| Version 1.1 のユーザー向け表示は日本語 |
| ブランド名・一般略語等は例外（例: Google, Apple, Open Food Facts, PFC, kcal, API, HealthKit, Health Connect 等） |

---

## Core Value

### 【Owner Decision】

Core Value は、プロダクト一言定義 **「エネルギー管理における意思決定支援アプリ」** として表現する。

### 【Proposal】

具体的な問い・例（「今日あと何 kcal 食べられるか」等）は、今後 Owner が確定する候補として `04_Decision_Log.md` または後続章で整理する。現時点では本文に詳細を載せない。

---

## 「やらないこと」について

### 【Owner Decision】

現時点では「やらないこと」の一覧を作成しない。必要になった時点で個別に判断する。

法令・安全性・App Store 規約上の制約、医療行為ではない等の免責は、後続の Legal / Privacy 文書で別途扱う。

---

## Version 1.1 リリース前の必須残タスク

以下は **【Owner Decision】** として Version 1.1 正式スコープに含まれるが、**現時点で未完成** の項目である。  
「将来機能」ではなく、Version 1.1 リリース前に完了すべきタスクとして扱う。

| # | タスク | 【Current Implementation】 |
|---|--------|---------------------------|
| 1 | **Apple ログイン** | 未実装（Google ログインは実装済み） |
| 2 | **App Store 公開に必要な法務・Privacy・審査対応** | 未完了 |
| 3 | **TestFlight 配布準備** | 未完了 |

---

## App Store 公開に向けたリリース目標

ユーザー機能ではなく、Version 1.1 の **リリース目標** として分離して記載する。

### 【Owner Decision】

- カロナビは **Apple App Store での公開を予定** する
- App Store 公開前に、法務、Privacy、Apple Sign-In、審査要件、セキュリティ、TestFlight 等を完了する
- 詳細は後続の Release / Legal 文書で定義する

### 【Open Question】

- Google Play 公開時期

---

## Open Questions（一覧）

| # | 項目 |
|---|------|
| Q1 | Vision / Mission / 最上位目的 |
| Q2 | Core Value の具体的な問い・例 |
| Q3 | 体重専用タブの本格 UI（履歴・グラフ等）を Version 1.1 に含めるか |
| Q4 | Health から取得した Workout を運動履歴・消費カロリー計算へどう反映するか |
| Q5 | Google Play 公開時期 |

---

## 他章への委譲

| 内容 | 参照先 |
|------|--------|
| 内部アーキテクチャ（Isar、Repository、AppController 等） | `02_System_Architecture.md`（執筆予定） |
| Nutrition Engine 計算詳細 | `03_Nutrition_Engine.md`（執筆予定） |
| ADR 形式の意思決定記録 | `04_Decision_Log.md`（執筆予定） |
| 開発環境・Git 運用・デプロイ | `05_Development_Guide.md`（執筆予定） |
| テスト・品質ゲート | `06_Testing.md`（執筆予定） |
| ロードマップ | `07_Roadmap.md`（執筆予定） |
| 過去プロジェクト概要（参考） | `docs/00_PROJECT.md` |
| AI 開発支援ルール | `rules/AI_RULES.md` |

---

## Document Philosophy

Engineering Handbook 全体が従う思想を、本章末尾に記す。

- この Handbook は **コードの説明書ではない**
- **設計思想と意思決定** を残すことが目的である
- コードが変わっても、**なぜその設計なのか** を失わないことを重視する
- 大きな仕様変更があれば **`04_Decision_Log.md` を更新** し、必要に応じて各章も更新する

---

## 改訂履歴

| 日付 | 変更 |
|------|------|
| 2026-07-22 | 初版（Phase B — Owner Decision 反映版） |
| 2026-07-22 | Handbook 全体ルール・Version 定義・Document Philosophy を追加 |
| 2026-07-22 | Owner Decision 更新ルールを追加。本章正式承認 |
