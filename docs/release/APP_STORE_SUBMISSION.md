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
