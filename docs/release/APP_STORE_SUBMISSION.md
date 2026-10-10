# App Store 提出前の手作業

審査用の Archive の前に、次を手元で確認する。この一覧は自動では走らない。

## 署名とログイン

1. Apple Developer の App ID で **Sign in with Apple** を有効にする。`ios/Runner/Runner.entitlements` には `com.apple.developer.applesignin` / `Default` が入っている。App ID 側が無いと Archive の codesign が失敗する。
2. Archive の前に `./tool/prepare_ios_release.sh` を1回だけ実行する。中で `tool/configure_google_signin_ios.sh` が `ios/Flutter/GoogleSignIn.generated.xcconfig` を作る。このファイルは gitignore で、Xcode は生成しない。Google はログインだけに使う。課金は App Store のアプリ内課金。

## Archive

3. **Release** スキームで Archive する。その前の `./tool/prepare_ios_release.sh` が、次を必ず実行する。

   ```sh
   flutter build ios --config-only --release \
     --dart-define-from-file=tool/dart_defines.local.json \
     --dart-define=officialFoodsEnabled=true
   ```

   `flutter build ios --config-only` を、`--dart-define-from-file=tool/dart_defines.local.json` なしで実行しない。外すと `ios/Flutter/Generated.xcconfig` から SUPABASE の定義が消え、Apple ログインと Google ログインが両方壊れる。鍵の値は手順にもログにも書かない。出力に `FLUTTER_BUILD_NUMBER`（pubspec の `+` の後ろ。次の提出は 12）、`DART_DEFINES: OK`、`Google URL スキーム: OK`、`準備完了` が出てから Archive する。`flutter clean` と `flutter pub get` を Archive の直前に挟まない。

   Release では `developmentPlusPreview` は常に偽（`!kReleaseMode`）で、購入しないとカロナビ+にならない。Debug / Profile の `flutter run` では真になり、購入せずカロナビ+になるので、審査用には使わない。
4. App Store Connect の価格は、次の商品 ID に合わせる。表示はストアが返した税込価格を使う。
   - `calonavi_plus_monthly` … ¥980
   - `calonavi_plus_half_year` … ¥4,900（980円×5。1か月分お得。月あたり約817円）
   - `calonavi_plus_yearly` … ¥8,800（月あたり約733円。月額より約25%お得）
   - **3日間の無料お試し（1.0.0 ビルド6〜）**: 3商品それぞれで「サブスクリプション価格」→「お試しオファー（Introductory Offers）」→「作成」→ 全地域 / 開始日=今日 / 終了日なし / 種類「無料」/ 期間「3日」。この設定が無いとアプリは価格だけを表示し、無料お試しは出ない。**お試しオファーを作る前に審査へ出さない。**アプリ側に期間のタイマーは無く、購入すると StoreKit がそのまま適用する（`Sk2PurchaseParam` にオファーを外す指定は無い）。
5. ペイウォールには利用規約、プライバシーポリシー、特定商取引法に基づく表記と、自動更新の説明（確認時に Apple ID へ請求、期間終了の 24 時間以上前に解約しない限り更新、更新料は終了前 24 時間以内に請求、管理と解約は App Store のアカウント設定）がある。AI機能は、写真で登録 (β)、外食・コンビニ (β)、AIで探す (β) の3つです。あわせて1日15回までです。自炊コーチはこの回数に入りません。

## サーバ

6. `supabase/migrations/20261007123300_delete_own_account_auth_must_succeed.sql` は 2026-10-07 に本番適用済み。退会時の記録は `anon_subject_id`（退会ごとに新しい uuid。利用者 ID からは作らない）で残し、個人を特定できる列は消す。`auth.identities` / `auth.users` の削除に失敗すると関数は例外で終わる。`kpi.excluded_user_ids` の退会集計の除外は `20261007112725` と同じで、開発者の匿名行は `kpi_excluded` が真になり `kpi.anon_*` から外れる。

## プライバシー

7. 公開するプライバシーポリシーは `docs/legal/privacy.html`。アプリ内は `legal/privacy.html`。両方を同じ内容にする。保存先はシンガポール（Supabase, Inc. のデータベース。Amazon Web Services のシンガポール地域）。ヘルスケアは Apple Health。Health Connect は書かない。Google はログインのみ。

## 課金猶予

8. `in_app_purchase_storekit` 0.4.13 には `Transaction.currentEntitlements` の読み取り API が無い。プラグインは `restorePurchases` の中だけでそれを使い、結果を購入ストリームへ流す。課金猶予（期限は過ぎているが currentEntitlements に残る状態）は、今回のビルドでは判定しない。`Transaction.all` の期限だけを見て、商品ごとに最も遅い期限を残す。

## ワンタップ切替は 1.0.0 (11) で削除

PR #80 のテスト用切替は、コードと画面から外した。設定の「テスト用: 無料に戻す」は無い。購入ボタンは StoreKit を開く。`CALONAVI_TEST_PURCHASE` はスクリプトもビルドも渡さない。

`supabase/migrations/20261006140000_calonavi_plus_test_product.sql` の商品ID制約は残す。この提出作業では本番データベースに何も適用しない。

## 審査メモ

App Store Connect の審査メモに、日本語と英語の両方を入れる。アプリの画面には出さない。Sandbox の購入で確認する。

日本語:

カロナビ+のAI機能は、写真で登録、外食・コンビニ、AIで探すの3つです。どれもカロナビ+が必要です。3つあわせて1日15回までです。自炊コーチはこの回数に入りません。商品は `calonavi_plus_monthly`（月額980円）、`calonavi_plus_half_year`（半年4,900円）、`calonavi_plus_yearly`（年額8,800円）です。

写真で登録、外食・コンビニ、AIで探すは、食事の写真、料理名、量、補足、店名や食品名を Anthropic, PBC（米国）へ送り、カロリーとPFCの推定に使います。写真はカロナビに保存しません。自炊コーチは Anthropic へ何も送りません。

サインインのあとの利用規約・プライバシーポリシーの同意画面で、送信先Anthropicと、不適切な内容を認めないことを明示して同意を得ている。同意しないとアプリを使えず、何も送らない。同意はアカウントごと（`ai_data_consents`）で、今の版に同意済みの人には出さない。

確認手順:
1. アプリを初めて開く。Apple または Google でログインする。
2. ログインの直後に「利用規約とプライバシーポリシー」の画面が出る。「AI機能では入力内容をAnthropic, PBC（米国）に送ります。」と、不適切な投稿や嫌がらせを認めない一文がある。「同意してはじめる」を押すまで、何も送らない。
3. カロナビ+を Sandbox で1つ購入する。
4. 食事の追加から「写真で登録」、検索の中の「外食・コンビニ」または「AIで探す」を開く。

English:

Calonavi+ AI features are Photo Log, Restaurant and Convenience Store, and AI Search. Each requires Calonavi+. Together they are limited to 15 uses per day. Cook Coach is not part of this limit. Product IDs: calonavi_plus_monthly (¥980), calonavi_plus_half_year (¥4,900), and calonavi_plus_yearly (¥8,800).

Photo Log, Restaurant and Convenience Store, and AI Search send the meal photo, dish name, amount, note, or store or food name to Anthropic, PBC in the United States to estimate calories and protein, fat, and carbohydrate. Photos are not stored by Calonavi. Cook Coach sends nothing to Anthropic.

After sign-in, the Terms and Privacy Policy agreement screen names Anthropic as the recipient and states that objectionable content and abusive behavior are not allowed. If the user does not agree, they cannot use the app and nothing is sent. Agreement is stored per account. Users who already agreed to the current version do not see the screen again.

How to test:
1. Open the app for the first time and sign in with Apple or Google.
2. The Terms and Privacy Policy screen appears immediately after sign-in. It states that AI features send what you enter to Anthropic, PBC (United States). Nothing is sent until the user taps the agree button.
3. Buy one Calonavi+ plan in the sandbox.
4. Open Photo Log, Restaurant and Convenience Store, or AI Search.
