# iOS の Google ログインと Health 連携

実機でこの2つを通すための手順です。アプリ側の配線は入っています。残るのはコンソール作業です。

Bundle ID は `com.narutoaii.ayg` です。

## 1. Google ログイン

### 1-1. Google Cloud で iOS クライアントを作る

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) を開く
2. Supabase の Google ログインで使っているのと同じプロジェクトを選ぶ
3. 認証情報 → 認証情報を作成 → OAuth クライアント ID
4. アプリケーションの種類: **iOS**
5. Bundle ID: `com.narutoaii.ayg`
6. 作成したクライアント ID（`xxxx.apps.googleusercontent.com`）をコピーする

Web クライアント（Supabase Auth の Google プロバイダに入っているもの）は消さない。

### 1-2. 手元の dart_defines に入れる

`tool/dart_defines.local.json`

```json
"GOOGLE_WEB_CLIENT_ID": "（Supabase に入っている Web クライアント）",
"GOOGLE_IOS_CLIENT_ID": "（今作った iOS クライアント）"
```

空の `GOOGLE_IOS_CLIENT_ID` のままにしない。空だと端末の Google は Safari 経由になる。

### 1-3. Supabase の戻り先

Authentication → URL Configuration → Redirect URLs に追加する。

```
com.narutoaii.ayg://login-callback
```

すでに入っている GitHub Pages の Web 用 URL は残す。

### 1-4. 確認

1. `./tool/run_ios.sh`
2. Googleでログイン
3. アカウント選択のあと、カロナビに戻ること

iOS クライアントを入れたあとは、Google のシートがアプリ内で出る。

## 2. Health 連携

アプリは読み取りだけを要求する（生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト）。

### 2-1. Xcode

1. `ios/Runner.xcworkspace` を開く
2. Runner → Signing & Capabilities
3. **HealthKit** があること。無ければ + Capability → HealthKit
4. Team はこれまで通り（Naruto Kikuchi）
5. USB で実機に入れ直す。Capabilities を足したあとは Wi-Fi 実行だけだと古い権限のままになることがある

### 2-2. iPhone

1. オンボーディングまたは設定 → Health / 活動量 で「利用する」
2. ヘルスケアの許可シートで、上の項目をオン
3. シートが出ない / 失敗するときは、設定 → プライバシーとセキュリティ → ヘルスケア → カロナビ

ヘルスケアアプリに体重や身長が入っていないと、許可は通っても値は空です。その場合は手入力でよい。

### 2-3. 失敗メッセージ

失敗時は「取得できませんでした」だけではなく、権限・ビルド・ヘルスケア側のどれかを日本語で出す。
