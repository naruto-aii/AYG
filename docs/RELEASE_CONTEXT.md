# カロナビ 1.0.0 リリース前提メモ（コード外の情報）

最終更新: 2026-10-10 JST。秘密の値（鍵・パスワード）は書かない。場所と設定内容だけを書く。
コードを直す人・審査対応する人は、作業前に必ず読むこと。

## 1. 現在の状態
- 審査提出: 1.0.0 (10)、ブランチ `cursor/release-submit` の c4ad66c から Archive。2026-10-09 23:42 JST 提出、優先審査申請済み。
- 2026-10-10 12:54 JST に Guideline 2.1 - Information Needed で保留。Apple の要求:
  1. 最新 OS の実機で、アプリ起動から始まる画面収録。登録・ログイン・アカウント削除・UGC の通報/ブロック・有料機能（購入の流れ）を含める。
  2. アプリの目的と対象ユーザー
  3. 使い方（ログイン方法。デモアカウントは無く Apple/Google ログインのみ）
  4. 外部サービス（Supabase、Anthropic API、Sign in with Apple、Google Sign-In、StoreKit）
  5. 地域による違い
  6. 規制業種かどうか（該当しない）
- 2.1 対応中に見つかった不具合（1.0.0 (11) で修正予定）:
  - カロナビ+判定が端末（StoreKit）とサーバー（calonavi_plus_entitlements）でずれ、AIで探す等が「限定機能」とだけ出て課金画面に行けない。ウィジェット・Siri は開く。
  - ログアウト/アカウント削除後に最初の画面へ戻らないことがあり、遅い。
  - 署名チーム（DEVELOPMENT_TEAM）がリポジトリに無く、毎回 Xcode で選び直していた。

## 2. ログイン設定（Supabase project `vdzzusqisymtejcjnikb`）
- Bundle ID: `com.narutoaii.ayg`。Apple Team ID: `B98NSNN924`。
- Google: Google Cloud プロジェクト「Calonavi」（project id `calonavi`）。
  - iOS クライアント（432427976502-lou2…）、Web クライアント（432427976502-giv1…、リダイレクト `https://vdzzusqisymtejcjnikb.supabase.co/auth/v1/callback`）。
  - Supabase の Google プロバイダ: Client IDs は「Web,iOS」の順でカンマ区切り、Secret は Web クライアントのもの、**Skip nonce checks = ON**（google_sign_in 6.x の iOS id_token に nonce が入るため。OFF だと 400）。
  - iOS の URL スキームは `tool/configure_google_signin_ios.sh` が `ios/Flutter/GoogleSignIn.generated.xcconfig` を生成。未生成だと Google ログインでクラッシュ（build 9 で発生）。
- Apple: Supabase の Apple プロバイダ Client ID に `com.narutoaii.ayg` を含める。Key ID `HPK8B862HT`（Secret JWT の再生成には対応する .p8 が必要。期限に注意）。
- 同じ Apple ID で再ログインしても初回設定をやり直させないこと（c4ad66c、`test/relogin_restores_onboarding_test.dart`）。

## 3. ビルド手順の必須事項
- 作業場所はオーナーの Mac の `~/Developer/AYG` のみ（Desktop/Documents の AYG は古いコピー）。
- `tool/dart_defines.local.json` は gitignore。SUPABASE_URL（/rest/v1 なし）、anon（publishable）key、Google の iOS/Web クライアントID。iOS ID の欄に bundle ID やカンマ区切りを入れない。
- 必ず `tool/prepare_ios_release.sh` を通す（json 検証→Google スキーム生成→`flutter build ios --config-only --release --dart-define-from-file=tool/dart_defines.local.json --dart-define=officialFoodsEnabled=true`）。`--dart-define-from-file` 無しの config-only は Generated.xcconfig から SUPABASE 等が消え、Apple/Google ログインが両方壊れる（build 7/8 の事故）。
- 出力に `FLUTTER_BUILD_NUMBER=<番号>`、`DART_DEFINES: OK`、`Google URL スキーム: OK`、`準備完了` が出ることを確認してから Archive。
- `flutter clean` / `pub get` を Archive 直前に挟まない。ビルド番号は pubspec と Generated.xcconfig の両方で確認する。

## 4. App Store Connect
- アプリ ID 6814054275。カロナビ+ は月額 980円 / 半年 4,900円 / 年額 8,800円、3プランすべてに 3日間無料トライアル（Introductory Offer）。
- 審査で Sign-in required はチェックなし（Apple/Google ログインのみでデモアカウント無し）。
- オーナーは Sandbox アカウントを使えない。有料機能の確認は TestFlight 購入で行う（購入済みになると課金画面の確認がしにくい）。

## 5. オーナーの方針（実装で守ること）
- AI 送信や同意のための専用画面を出さない。利用規約・プライバシーポリシーに「AI機能では入力内容をAnthropic, PBC（米国）に送ります」を含め、その同意で AI 機能にも同意したことにする。
- 規約から「期限が来たら捨てます」を削除（期限切れキャッシュ削除は実装しない）。
- カロナビ+の案内では「有料」と書かず、「カロナビ+の機能」などメリット訴求の言い方。有料機能を押したら毎回課金画面。見出しは「3日間無料でお試し → その後自動でカロナビ+」、金額は大きく明記。
- 食事・運動のメモは無料。課金画面の文言「β版機能に先行アクセス出来ます！」。
- 「今日のコーチ」は「パーソナルコーチ (β)」。自炊コーチの PFC 優先順位は カロリー → タンパク質 → 炭水化物 → 脂質（上位を犠牲に下位を合わせない）。0件を出さない。
- AI 量入力は数字のみ、単位（g）は入力欄の外。
- 目標カロリー/PFC は初回設定と設定画面の両方で、必要項目が揃えば即全自動計算、欠けていれば何が欠けているか表示、変更で即再計算。
- AI 処理は API 費用を節約（画像圧縮等）。テストで本物の Anthropic API を呼ばない。
- PR #80（テスト用ワンタップでカロナビ+切替）は申請ビルドに含めない（`CALONAVI_TEST_PURCHASE` 付きでビルドしない）。
- サーバー同期の変更は、端末内・サーバー・再インストールの3通りで往復して時刻・内容・件数が変わらないことをテストしてから出す。

## 6. KPI 集計
- オーナー本人の2アカウント（Apple 11026757-564c-4e5f-b576-f2021d840f07、Google f23768db-9e15-44f0-b1c0-de58c1487ee4）は `public.kpi_excluded_users` で集計除外。ただしオーナーは 2026-10-10 にアカウント削除と再作成を繰り返したため、新しい user id は未除外の可能性あり。
- 未対応: app-store-notifications / import 関数の本番デプロイと ASC への URL 登録、`purchase_result` の is_trial/offer_type、entitlements のトライアルフラグ。
