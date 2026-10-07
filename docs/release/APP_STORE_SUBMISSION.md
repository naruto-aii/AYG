# App Store 提出前の手作業

審査用の Archive の前に、次を手元で確認する。この一覧は自動では走らない。

## 署名とログイン

1. Apple Developer の App ID で **Sign in with Apple** を有効にする。`ios/Runner/Runner.entitlements` には `com.apple.developer.applesignin` / `Default` が入っている。App ID 側が無いと Archive の codesign が失敗する。
2. Archive の前に `tool/configure_google_signin_ios.sh` を実行し、`ios/Flutter/GoogleSignIn.generated.xcconfig` を作る。このファイルは gitignore で、Xcode は生成しない。Google はログインだけに使う。課金は App Store のアプリ内課金。

## Archive

3. **Release** スキームで Archive する。Profile は `developmentPlusPreview` が真になり、購入せずカロナビ+になる。`CALONAVI_TEST_PURCHASE` は渡さない。`ios/Flutter/Release.xcconfig` にもその定義は無い。
4. App Store Connect の価格は、次の商品 ID に合わせる。表示はストアが返した税込価格を使う。
   - `calonavi_plus_monthly` … ¥580
   - `calonavi_plus_half_year` … ¥2,900
   - `calonavi_plus_yearly` … ¥5,400
5. ペイウォールには利用規約、プライバシーポリシー、特定商取引法に基づく表記と、自動更新の説明（確認時に Apple ID へ請求、期間終了の 24 時間以上前に解約しない限り更新、更新料は終了前 24 時間以内に請求、管理と解約は App Store のアカウント設定）がある。

## サーバ

6. `supabase/migrations/20261008120000_delete_own_account_auth_must_succeed.sql` はリポジトリにだけ置く。本番へは自動適用しない。提出者が内容を確認してから適用する。退会時の記録は `anon_subject_id`（退会ごとに新しい uuid。利用者 ID からは作らない）で残し、個人を特定できる列は消す。`auth.identities` / `auth.users` の削除に失敗すると関数は例外で終わる。`kpi.excluded_user_ids` の退会集計の除外は `20261007112725` と同じで、開発者の匿名行は `kpi_excluded` が真になり `kpi.anon_*` から外れる。

## プライバシー

7. 公開するプライバシーポリシーは `docs/legal/privacy.html`。アプリ内は `legal/privacy.html`。両方を同じ内容にする。保存先はシンガポール（Supabase, Inc. のデータベース。Amazon Web Services のシンガポール地域）。ヘルスケアは Apple Health。Health Connect は書かない。Google はログインのみ。

## 課金猶予

8. `in_app_purchase_storekit` 0.4.13 には `Transaction.currentEntitlements` の読み取り API が無い。プラグインは `restorePurchases` の中だけでそれを使い、結果を購入ストリームへ流す。課金猶予（期限は過ぎているが currentEntitlements に残る状態）は、今回のビルドでは判定しない。`Transaction.all` の期限だけを見て、商品ごとに最も遅い期限を残す。
