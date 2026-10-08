# Sign in with Apple のトークン失効

iOS / macOS の Sign in with Apple は、認可コードを `store-apple-refresh-token` へ送ります。関数は Apple と交換したリフレッシュトークンを `internal.apple_refresh_tokens` に保存します。アプリには返しません。購入のレシート本文や購入トークンは保存しません。

`delete-account` は、呼び出し元の JWT からユーザーIDを決めます。リクエスト本文のユーザーIDは使いません。保存済みトークンを読んだあと、`public.delete_own_account(uuid)` を service role で呼びます。`anon` と `authenticated` はこの関数を実行できません。削除が成功したあとだけ Apple の `https://appleid.apple.com/auth/revoke` を呼び、その後トークン行を消します。削除に失敗したときは Apple を呼ばず、トークン行も残します。

トークンがあったのに失効が失敗したときは、アカウント削除は済んだまま `{ ok: true, apple_revoke_failed: true }` を返します。アプリは、Apple ID の設定からカロナビを外すよう案内します。トークンが無く、Auth 上は Apple ログインのときは同じフラグを立て、Apple は呼びません。Apple ログインでなければフラグは付けません。

Web と Android の Apple OAuth は認可コードをアプリに渡さないので、保存できるトークンはありません。削除自体は実行します。

この変更は関数をデプロイせず、マイグレーションも本番へ適用しません。

## シークレット

値は Supabase のシークレットにだけ置き、git や `supabase/config.toml` には書きません。

- `APPLE_TEAM_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`（`.p8` の中身。`\n` の文字も受け付けます）
- `APPLE_CLIENT_ID` — バンドルID `com.narutoaii.ayg`

`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY` はプラットフォームが注入します。本番では `ALLOW_LOCALHOST_ORIGIN` を設定しません。ブラウザからの呼び出しは `https://naruto-aii.github.io` だけを許します。ネイティブアプリは Origin を送りません。

両関数とも `verify_jwt = true` です。

公開前の順番:

1. `20261003200000_apple_token_revoke_on_delete.sql` までを、タイムスタンプ順に適用する。
2. 上の4つの Apple シークレットを設定する。
3. `store-apple-refresh-token` と `delete-account` をデプロイする。
4. そのあとで、この削除を呼ぶアプリを出す。

`delete-account` が無いときは、アプリは削除していないと表示し、ログアウトしません。`delete_own_account` をアプリから直接は呼びません。

## 戻し方

1. アプリを、この関数を呼ばない版へ戻す。
2. マイグレーションを適用済みなら、`supabase/rollback/20261003200000_apple_token_revoke_on_delete_down.sql` を手で流す。トークン行は消え、食事などの行は残る。`delete_own_account()` は再び本人が引数なしで呼べる。
3. 関数を出していれば削除する。
4. 任意で Apple の4シークレットを unset する。

## テスト

```sh
deno test --allow-env=ALLOW_LOCALHOST_ORIGIN --config supabase/functions/deno.json supabase/functions/_shared/apple_account_test.ts
deno test --allow-env --allow-net supabase/functions/app_events_edge_test.ts supabase/functions/store_live_test.ts
```

## 操作の記録と App Store の取り込み

`app-store-notifications`、`store-analytics-import`、`store-sales-import`、`store-analytics-setup` はリポジトリに置くだけです。この変更では配備しません。マイグレーションも本番へ適用しません。秘密の値は書きません。

`verify_jwt = false` です。取り込みの 3 つはヘッダ `x-store-import-secret` を見ます。通知は Apple の署名を、本番とサンドボックスの両方で確かめます。

秘密の名前:

- `ASC_ISSUER_ID`
- `ASC_ADMIN_KEY_ID` / `ASC_ADMIN_PRIVATE_KEY`（分析レポートの依頼が済んだら、鍵を無効化してこの 2 つを消す）
- `ASC_REPORTS_KEY_ID` / `ASC_REPORTS_PRIVATE_KEY`
- `ASC_VENDOR_NUMBER`
- `ASC_APP_APPLE_ID`
- `APP_BUNDLE_ID`（`com.narutoaii.ayg`）
- `STORE_IMPORT_SECRET`（32 バイト以上。Vault の `store_import_secret` と同じ値）
- `APPLE_ROOT_CA_BASE64`（通知の検証に使う Apple のルート証明書。DER を Base64 にしたもの）

公開前の順番:

1. `20261007094059_app_events.sql` と `20261007094142_app_events_retention.sql` は本番に適用済み。アプリは `public.insert_app_events` で追加する。表への直接 INSERT は渡していない。
2. `app-store-notifications` を配備し、App Store Connect の通知先（本番とサンドボックス、バージョン 2）を `https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications` にする。
3. 上の秘密を入れる。
4. `store-analytics-setup` を 1 回だけ実行する。そのあと管理者鍵を無効化し、`ASC_ADMIN_KEY_ID` と `ASC_ADMIN_PRIVATE_KEY` を消す。
5. pg_cron と pg_net を有効にする承認のあと、Vault に `project_url`（`https://vdzzusqisymtejcjnikb.supabase.co`）と `store_import_secret` を入れ、`20261008090100_store_import_schedule.sql` を適用する。
6. `store-analytics-import` と `store-sales-import` を配備する。
7. `20261007095347_app_events_rollup_additive.sql` は本番に適用済み。集計は足し算。
8. `20261007103757_app_events_closed_month.sql` は本番に適用済み。集計済みの月の操作は受け付けない。
9. `20261007112725_kpi_excluded_users.sql` は本番に適用済み。開発者アカウントは日次集計と退会集計から外す。手順 8 のあと。
10. pg_cron の承認のあと、`20261008090300_app_events_retention_schedule.sql` を適用する。毎日、90 日より古い月を集計してから表ごと消す。手順 8 と 9 は適用済み。

## 写真で登録

`analyze-meal-photo` は、食事の JPEG と任意の料理名・量・補足を受け取り、栄養の推定を返します。写真と補足の文面は関数の中だけで使い、Storage にも表にも残しません。表に残すのは補足があったかどうかだけです。API キーはアプリに置きません。

この変更では関数をデプロイせず、マイグレーションも本番へ適用しません。

既定の提供元は Anthropic です。写真に料理名と量が両方あるときだけ `claude-haiku-5-5`、写真だけ、または片方だけのときは `claude-sonnet-5-5` です。補足は振り分けに使いません。高性能の月間回数を超えて料理名か量が無いときは、モデルを呼ばず、名前と量を入れるよう返します。両方あれば軽いモデルのままです。日付の境は日本時間です。

写真で登録と AIで探すは、どちらもカロナビ+だけです。無料の回数はありません。サーバは加入が無い呼び出しを 403 で返します。

1日の回数は、写真で登録、外食・コンビニ、AIで探す、自炊コーチの合計です。未設定なら 15 回です。`AI_COMBINED_DAILY_LIMIT` を変えると、アプリを出さずに変わります。空のときは `AI_DAILY_LIMIT`、それも空のときは `PHOTO_AI_DAILY_LIMIT` を見ます。超えたときは「本日の上限に達しました」を返します。日付の境は日本時間です。自炊コーチの表 `ai_feature_uses` がまだ無いときは、その分は 0 として数えます。数えるのは `feature = cook_coach` だけです。AIで探すは `meal_text_lookups` に入るので、`ai_search` の行は足しません。月の回数と月の費用は、環境変数が空のあいだは止めません。オーナーはまだ決めていません。高性能モデルの月間回数の初期値は 20 のままです。

推定はカロナビの食品データベースに合わせません。モデルは学習した知識だけから答えます。チェーン店やコンビニの公式な栄養成分、日本食品標準成分表、一般的なレシピのうち、その食事に合うものを使います。返った数値をデータベースの食品へ置き換えません。Web 検索は使いません。

思考のオンオフ、`max_tokens`、写真の長辺は階層ごとに環境変数です。精度の比較で決めます。空のときは思考オフ、`max_tokens` 300、長辺 1024 です。システムプロンプトは prompt caching を使います。モデルへ渡す JSON のキーは短くします。

Gemini は既定にしません。`PHOTO_AI_PROVIDER=gemini` または `openai` は、アダプタが無いので日本語の準備中を返します。未成年が使うアプリに Gemini の API を既定で使わないためです。

`verify_jwt = true` です。利用者は JWT から決めます。カロナビ+ は `public.calonavi_plus_entitlements` の `status = 'active'` かつ `expires_at > now()` です。この行はアプリが書きません。購入、復元、起動時の再読込は、StoreKit 2 の署名付き取引を `verify-store-transaction` に渡します。関数が Apple の署名を確かめ、`service_role` で行を書きます。写真で登録、AIで探す、自炊コーチは、その行が無い呼び出しを `not_plus` で返します。

審査と TestFlight は Sandbox の取引です。`verify-store-transaction` は Production と Sandbox のどちらも、Apple の署名が通り、bundleId と商品IDが合うとき受けます。Sandbox を拒む設定は置きません。

期限を過ぎた `ai_food_estimate_cache` と `cook_coach_cache` は、それぞれの関数が呼ばれるたびに最大 20 行消します。

### シークレットと環境変数

値は Supabase のシークレットにだけ置き、git や `supabase/config.toml` には書きません。

必須:

- `ANTHROPIC_API_KEY`

任意（未設定なら括弧の既定）:

- `PHOTO_AI_PROVIDER`（`anthropic`）
- `PHOTO_AI_LIGHT_MODEL`（`claude-haiku-5-5`）
- `PHOTO_AI_HEAVY_MODEL`（`claude-sonnet-5-5`）
- `AI_COMBINED_DAILY_LIMIT`（`15`。写真、外食・コンビニ、AIで探す、自炊コーチの合計。空なら `AI_DAILY_LIMIT`、それも空なら `PHOTO_AI_DAILY_LIMIT`）
- `PHOTO_AI_MONTHLY_LIMIT`、`PHOTO_AI_MONTHLY_SPEND_JPY`（空なら止めない。オーナー未決）
- `PHOTO_AI_HEAVY_MONTHLY_LIMIT`（`20`）
- `PHOTO_AI_USD_JPY`（`158`）
- `PHOTO_AI_LIGHT_INPUT_USD_PER_MILLION`（`0.10`）、`PHOTO_AI_LIGHT_OUTPUT_USD_PER_MILLION`（`0.50`）、`PHOTO_AI_LIGHT_CACHE_READ_USD_PER_MILLION`（`0.01`）、`PHOTO_AI_LIGHT_CACHE_WRITE_USD_PER_MILLION`（`0.125`）
- `PHOTO_AI_HEAVY_INPUT_USD_PER_MILLION`（`2`）、`PHOTO_AI_HEAVY_OUTPUT_USD_PER_MILLION`（`10`）、`PHOTO_AI_HEAVY_CACHE_READ_USD_PER_MILLION`（`0.10`）、`PHOTO_AI_HEAVY_CACHE_WRITE_USD_PER_MILLION`（`2.5`）
- `PHOTO_AI_MAX_TOKENS`（`300`）、`PHOTO_AI_LIGHT_MAX_TOKENS`、`PHOTO_AI_HEAVY_MAX_TOKENS`
- `PHOTO_AI_LIGHT_THINKING`、`PHOTO_AI_HEAVY_THINKING`（`off`。`on` は adaptive。Sonnet 5.5 のオフは `between_tools`）
- `PHOTO_AI_LIGHT_EFFORT`、`PHOTO_AI_HEAVY_EFFORT`（`low`。思考オフのときは high まで）
- `PHOTO_AI_LIGHT_IMAGE_MAX_EDGE`、`PHOTO_AI_HEAVY_IMAGE_MAX_EDGE`（`1024`）

費用は、API が返した入力・出力・キャッシュ読み・キャッシュ書きのトークンから計算します。キャッシュの単価には、長いプロンプトの倍率を掛けません。軽いモデルは、キャッシュに入っていない入力が 100k トークンを超えると、その入力と出力を 5 倍で数えます。`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY` はプラットフォームが注入します。キーが無いときは 503 で「いま準備中です。手入力で記録できます。」を返し、食事の保存経路は呼びません。

### 公開前の順番

この変更ではデプロイしない。マイグレーションも本番へ適用しない。出すときは、下の「本番に出す順番」だけを使う。

1. `supabase/migrations/20261008140000_meal_photo_analyses.sql` を、それより前のマイグレーションのあとに適用する。本番へはまだ適用していない。
2. シークレットは設定済み。単価や上限を変えるときだけ、上の任意の環境変数を足す。
3. `analyze-meal-photo` をデプロイする。この変更ではデプロイしない。
4. そのあとで、写真で登録を出すアプリを出す。マイグレーションより先に出すと、案内の `photo_meal` は再送待ちになり、利用記録の `user_edited` は書けない。食事の保存自体は、既存の食事の経路なのでマイグレーションが無くてもできる。

戻すときは、関数を消してから `supabase/rollback/20261008140000_meal_photo_analyses_down.sql` を手で流す。`photo_meal` の案内行を消してから、案内の制約を元に戻す。食事の行は残る。

### テスト

```sh
deno test --config supabase/functions/deno.json supabase/functions/analyze_meal_photo_test.ts
```

## AIで探す

`lookup-food-text` は、入力された食品名だけを受け取り、候補を最大3件返します。写真は使いません。Web 検索も使いません。チェーンの栄養成分を食品データベースへ一括では入れません。返った数値をデータベースの食品へも置き換えません。

モデルは `claude-haiku-5-5`（`PHOTO_AI_LIGHT_MODEL`）だけです。文章だけ、思考はオフ、`max_tokens` は空なら 300 です。推定は学習した知識だけから答えます。チェーン店やコンビニの栄養成分、日本食品標準成分表、一般的なレシピのうち、その食品に合うものを使います。

検索語は、正規化してからプロンプトのデータの枠に入れます。指示としては読みません。同じ利用者の、同じ正規化の検索語だけを `ai_food_estimate_cache` にモデル名と期限つきで残します。主キーは利用者と検索語です。他の利用者には出さず、食品の一覧としても出しません。以前の共有行は、マイグレーションが消します。期限は `TEXT_AI_CACHE_TTL_HOURS` です。空なら仮置きの 168 時間です。オーナーはまだ決めていません。

外食・コンビニも同じ関数です。通常の食品検索が 0 件のときと、結果があるときの「AIで探す (β)」は、どちらも利用者が押したときだけ呼びます。入力のたびにモデルは呼びません。

1日の回数は写真で登録、外食・コンビニ、自炊コーチと合算し、`AI_COMBINED_DAILY_LIMIT`（空なら `AI_DAILY_LIMIT`、それも空なら 15）です。超えたときは「本日の上限に達しました」です。月の回数は `TEXT_AI_MONTHLY_LIMIT` が空なら止めません。月間の費用は、写真で登録と自炊コーチの `estimated_cost_jpy` と合算し、`PHOTO_AI_MONTHLY_SPEND_JPY` が空なら止めません。キャッシュに当たった呼び出しの費用は 0 です。費用の上限が設定されていて、それを超えていても、期限内のキャッシュは返せます。モデルは呼びません。回数の上限はキャッシュも数えます。無料の回数はありません。

返した候補は `ai_food_result_collections` に集めます。アプリの検索には出さず、本人も読めません。保存したあと、そのままか直したかだけを関数 `record_ai_food_result_outcome` で書きます。この書き込みに失敗しても、食事の保存は戻しません。

この変更では関数をデプロイせず、マイグレーションも本番へ適用しません。

### シークレットと環境変数

写真で登録と同じ `ANTHROPIC_API_KEY` と、軽いモデルの単価（`PHOTO_AI_LIGHT_*`、`PHOTO_AI_USD_JPY`）を使います。

任意（未設定なら括弧の仮置き。回数と期限はオーナー未決）:

- `TEXT_AI_MONTHLY_LIMIT`（空なら止めない。オーナー未決）
- `TEXT_AI_CACHE_TTL_HOURS`（`168`）
- `TEXT_AI_MAX_TOKENS`（`300`）

### 公開前の順番

この変更ではデプロイしない。出すときは、下の「本番に出す順番」だけを使う。

戻すときは、関数を消してから `supabase/rollback/20261008190000_ai_food_result_collections_down.sql` を先に流し、そのあと `supabase/rollback/20261008160000_ai_food_lookup_down.sql` を、写真で登録のロールバックより先に手で流す。食事の行は残る。

### テスト

```sh
deno test --allow-read --config supabase/functions/deno.json supabase/functions/lookup_food_text_test.ts supabase/functions/ai_food_collection_test.ts supabase/functions/ai_cost_measure_test.ts
```

## 自炊コーチ

`cook-coach` は、手元の食材とこの食事の目標（kcal と PFC）を受け取り、家庭で作る料理を返します。モデルは料理の中身だけを決めます。kcal と PFC は `official_foods` の値で計算し直します。成分表に無い食品だけ、モデルの目安を使い、画面では「AIの目安」と出します。目標との差は残したまま返します。

届ける範囲は、kcal が目標の ±10%、P/F/C がそれぞれ ±15% か ±5g の広い方です。分量は一律の倍率ではなく、食材ごとの現実的な下限と上限の中で、kcal と PFC の差が小さくなるグラムを解きます。調味料や油は小さじ程度、主菜や主食は家庭の一皿に収まる範囲です。それでも範囲に入らないときだけ、測った値を渡してもう1回モデルを呼びます。揚げ物、真空調理、低温調理、専門の食材、9つ以上の食材、指定が無いときの30分超も、その1回で家庭の手順に直します。3回目は呼びません。同じ食材と、10kcal 単位に丸めた目標は `cook_coach_cache` から返し、モデルは呼びません。思考はオフ、出力は短い JSON、固定のシステムプロンプトは prompt caching です。モデルは `PHOTO_AI_LIGHT_MODEL`（空なら `claude-haiku-5-5`）です。`COOK_AI_MAX_TOKENS` の初期値は 640 です。

1日の回数は、写真で登録（`meal_photo_analyses`）、AIで探すと外食・コンビニ（`meal_text_lookups`）、自炊コーチ（`ai_feature_uses` の `cook_coach`）を合わせて数えます。初期値は 15 回です。`AI_DAILY_LIMIT` と `AI_COMBINED_DAILY_LIMIT` は同じ意味で、空なら 15 です。AIで探すの行は `meal_text_lookups` に入るので、`ai_search` は足しません。写真で登録の行は、自炊コーチの表には入れません。

この変更では関数をデプロイせず、マイグレーションも本番へ適用しません。

`verify_jwt = true` です。利用者は JWT から決めます。カロナビ+ は `public.calonavi_plus_entitlements` の `status = 'active'` かつ `expires_at > now()` です。

### シークレットと環境変数

`ANTHROPIC_API_KEY` は写真で登録と同じです。単価も `PHOTO_AI_USD_JPY` と `PHOTO_AI_LIGHT_*` を使います。

任意:

- `AI_DAILY_LIMIT`（`15`。写真で登録、外食・コンビニ、AIで探す、自炊コーチの合計。`AI_COMBINED_DAILY_LIMIT` と同じ）
- `COOK_AI_MAX_TOKENS`（`640`）
- `PHOTO_AI_LIGHT_MODEL`（`claude-haiku-5-5`）
- `PHOTO_AI_LIGHT_THINKING` は自炊コーチでは使いません。思考はオフ固定です。

### 公開前の順番

1. `supabase/migrations/20261008180000_ai_feature_uses.sql` を、`20261008140000_meal_photo_analyses.sql` のあとに適用する。本番へはまだ適用していない。
2. `ANTHROPIC_API_KEY` が入っていることを確認する。回数を変えるときだけ `AI_DAILY_LIMIT` を足す。
3. `cook-coach` をデプロイする。この変更ではデプロイしない。
4. そのあとで、自炊コーチを出すアプリを出す。マイグレーションより先に出すと、上限の記録は書けません。食事の保存自体は、既存の食事の経路なのでマイグレーションが無くてもできます。

戻すときは、関数を消してから `supabase/rollback/20261008180000_ai_feature_uses_down.sql` を手で流す。`20261008190000` を適用しているときは、そのロールバックを先に流す。食事の行は残る。

### テスト

```sh
deno test --config supabase/functions/deno.json supabase/functions/cook_coach_test.ts
```

## 本番に出す順番

このリポジトリの変更では、マイグレーションを適用せず、関数もデプロイしない。

設定済みで、変えないシークレット:

- `ANTHROPIC_API_KEY`
- `PHOTO_AI_PROVIDER=anthropic`
- `PHOTO_AI_LIGHT_MODEL=claude-haiku-5-5`
- `PHOTO_AI_HEAVY_MODEL=claude-sonnet-5-5`

マイグレーションは、この順に手で適用する。

1. `supabase/migrations/20261008140000_meal_photo_analyses.sql`
2. `supabase/migrations/20261008160000_ai_food_lookup.sql`
3. `supabase/migrations/20261008160100_food_memo_is_free.sql`（食事と運動のメモは無料、というコメントだけ。AIで探すと同じ時刻にならないよう、ファイル名をずらしてあります）
4. `supabase/migrations/20261008180000_ai_feature_uses.sql`
5. `supabase/migrations/20261008190000_ai_food_result_collections.sql`
6. `supabase/migrations/20261008200000_entitlements_server_only.sql`

そのあとで関数をデプロイする。

1. `analyze-meal-photo`
2. `lookup-food-text`
3. `cook-coach`
4. `verify-store-transaction`

アプリは関数のあとで出す。月の回数と月の費用の環境変数は空のままにする。1日の回数は未設定なら 15 です。

`verify-store-transaction` と `app-store-notifications` は、次のシークレットを使います。値はこのリポジトリに書きません。

- `APP_BUNDLE_ID`（`com.narutoaii.ayg`）
- `ASC_APP_APPLE_ID`（App Store Connect の Apple ID。数字）
- `APPLE_ROOT_CA_BASE64`（または `APPLE_ROOT_CA`）

App Store Server Notifications の URL は、これまでどおり `app-store-notifications` です。更新と期限切れは、その通知が検証済みの取引から加入の行を更新します。
