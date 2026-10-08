# App Store 提出前の手作業

審査用の Archive の前に、次を手元で確認する。この一覧は自動では走らない。

## 署名とログイン

1. Apple Developer の App ID で **Sign in with Apple** を有効にする。`ios/Runner/Runner.entitlements` には `com.apple.developer.applesignin` / `Default` が入っている。App ID 側が無いと Archive の codesign が失敗する。
2. Archive の前に `tool/configure_google_signin_ios.sh` を実行し、`ios/Flutter/GoogleSignIn.generated.xcconfig` を作る。このファイルは gitignore で、Xcode は生成しない。Google はログインだけに使う。課金は App Store のアプリ内課金。

## Archive

3. **Release** スキームで Archive する。Profile は `developmentPlusPreview` が真になり、購入せずカロナビ+になる。`CALONAVI_TEST_PURCHASE` は渡さない。`ios/Flutter/Release.xcconfig` にもその定義は無い。
4. App Store Connect の価格は、次の商品 ID に合わせる。表示はストアが返した税込価格を使う。
   - `calonavi_plus_monthly` … ¥980
   - `calonavi_plus_half_year` … ¥4,900（980円×5。1か月分お得。月あたり約817円）
   - `calonavi_plus_yearly` … ¥8,800（月あたり約733円。月額より約25%お得）
5. ペイウォールには利用規約、プライバシーポリシー、特定商取引法に基づく表記と、自動更新の説明（確認時に Apple ID へ請求、期間終了の 24 時間以上前に解約しない限り更新、更新料は終了前 24 時間以内に請求、管理と解約は App Store のアカウント設定）がある。AI機能は、写真で登録 (β)、外食・コンビニ (β)、AIで探す (β)、パーソナルコーチ (β)（自炊コーチを含む）です。あわせて1日15回までです。

## サーバ

6. `supabase/migrations/20261007123300_delete_own_account_auth_must_succeed.sql` は 2026-10-07 に本番適用済み。退会時の記録は `anon_subject_id`（退会ごとに新しい uuid。利用者 ID からは作らない）で残し、個人を特定できる列は消す。`auth.identities` / `auth.users` の削除に失敗すると関数は例外で終わる。`kpi.excluded_user_ids` の退会集計の除外は `20261007112725` と同じで、開発者の匿名行は `kpi_excluded` が真になり `kpi.anon_*` から外れる。

## プライバシー

7. 公開するプライバシーポリシーは `docs/legal/privacy.html`。アプリ内は `legal/privacy.html`。両方を同じ内容にする。保存先はシンガポール（Supabase, Inc. のデータベース。Amazon Web Services のシンガポール地域）。ヘルスケアは Apple Health。Health Connect は書かない。Google はログインのみ。

## 課金猶予

8. `in_app_purchase_storekit` 0.4.13 には `Transaction.currentEntitlements` の読み取り API が無い。プラグインは `restorePurchases` の中だけでそれを使い、結果を購入ストリームへ流す。課金猶予（期限は過ぎているが currentEntitlements に残る状態）は、今回のビルドでは判定しない。`Transaction.all` の期限だけを見て、商品ごとに最も遅い期限を残す。

## 実機確認のあと外すワンタップ切替

このビルドには、PR #80 のワンタップ切替を残している。実機確認が終わったら、下の箇所を外す。Xcode の Archive は `CALONAVI_TEST_PURCHASE` を渡さないので、提出用ビルドには付かない。`./tool/run_ios.sh` と `./tool/run_ios.sh --release` だけが `--dart-define=CALONAVI_TEST_PURCHASE=true` を付ける。

切替は端末のカロナビ+表示だけを変える。署名付き取引が無いので `verify-store-transaction` は呼ばれず、`calonavi_plus_entitlements` には書かない。サーバの AI 判定は `not_plus` のまま。`supabase/migrations/20261006140000_calonavi_plus_test_product.sql` は商品IDの制約だけで、この切替を外すときに消さない。

- `lib/config/test_purchase.dart` — `testPurchaseEnabled`。`CALONAVI_TEST_PURCHASE`、既定は false。
- `tool/run_ios.sh` — 上の define を常に付ける。
- `lib/bootstrap/native_bootstrap.dart` — `StoreKitSubscriptionRepository` へ `testPurchaseEnabled` を渡す。
- `lib/repositories/storekit_subscription_repository.dart` — 有効なとき購入は StoreKit を開かず、`calonavi_plus_test_override` と商品 `calonavi_plus_test`、期限 `2099-01-01` で端末だけ有料にする。設定の「テスト用: 無料に戻す」は `clearTestPurchase`。
- `lib/repositories/subscription_repository.dart` — `testPurchaseToggleEnabled`。既定は false。
- `lib/screens/settings/settings_screen.dart` — 行「テスト用: 無料に戻す」（key `test-purchase-revert`）。
- `lib/screens/subscription/calonavi_plus_flow.dart` — ストア価格を読まず、成功の文は「テスト用にカロナビ+にしました」。
- `lib/config/subscription_catalog.dart` — `testPurchaseProductId = calonavi_plus_test`。
- `lib/config/development_plus_preview.dart` — このフラグが真のとき、常時の有料プレビューは切る。
- `test/test_purchase_toggle_test.dart` — 上の存在を確かめている。
- `ios/Flutter/Release.xcconfig` — `CALONAVI_TEST_PURCHASE` を足さない。

## 審査メモ

App Store Connect の審査メモに、日本語と英語の両方を入れる。アプリの画面には出さない。Sandbox の購入で確認する。`tool/run_ios.sh` のテスト切替は Archive に入らない。

日本語:

カロナビ+のAI機能は、写真で登録、外食・コンビニ、AIで探す、自炊コーチです。どれもカロナビ+が必要です。4つあわせて1日15回までです。商品は `calonavi_plus_monthly`（月額980円）、`calonavi_plus_half_year`（半年4,900円）、`calonavi_plus_yearly`（年額8,800円）です。

これらの機能は、食事の写真、料理名、量、補足、店名や食品名、手元の食材と条件のメモを Anthropic, PBC（米国）へ送り、カロリーとPFCの推定に使います。写真はカロナビに保存しません。初めて使う前に同意の画面を出します。同意するまで送りません。「やめる」では何も送りません。

確認手順:
1. Sandbox の Apple ID でアプリにログインする。
2. カロナビ+を Sandbox で1つ購入する。
3. 食事の追加から「写真で登録」、検索の中の「外食・コンビニ」または「AIで探す」、またはパーソナルコーチの「自炊コーチ」を開く。
4. 初回は「AI機能を使う前に」と出ます。「同意して使う」のあとで推定が動きます。

English:

Calonavi+ AI features are Photo Log, Restaurant and Convenience Store, AI Search, and Cook Coach. Each requires Calonavi+. Together they are limited to 15 uses per day. Product IDs: calonavi_plus_monthly (¥980), calonavi_plus_half_year (¥4,900), and calonavi_plus_yearly (¥8,800).

These features send the meal photo, dish name, amount, note, store or food name, or the ingredients and condition memo to Anthropic, PBC in the United States to estimate calories and protein, fat, and carbohydrate. Photos are not stored by Calonavi. Before the first use, the app shows a consent dialog. Nothing is sent until the user agrees. Decline sends nothing.

How to test:
1. Sign in with a Sandbox Apple ID.
2. Buy one Calonavi+ plan in the sandbox.
3. Open Photo Log, Restaurant and Convenience Store, AI Search, or Cook Coach.
4. The first time, the consent dialog appears. Estimation runs after 「同意して使う」.
