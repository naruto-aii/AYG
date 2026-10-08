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

1日の回数、月の回数、高性能モデルの月間回数、1人あたりの月間費用は、すべて環境変数です。オーナーはまだ決めていません（TBD by owner）。未設定のときの仮置きは、1日10回、月120回、高性能モデル月20回、月120円です。これは決まった上限ではありません。画面の「○回まで」は、そのときの環境変数の値です。

推定はカロナビの食品データベースに合わせません。モデルは学習した知識だけから答えます。チェーン店やコンビニの公式な栄養成分、日本食品標準成分表、一般的なレシピのうち、その食事に合うものを使います。返った数値をデータベースの食品へ置き換えません。Web 検索は使いません。

思考のオンオフ、`max_tokens`、写真の長辺は階層ごとに環境変数です。精度の比較で決めます。空のときは思考オフ、`max_tokens` 300、長辺 1024 です。システムプロンプトは prompt caching を使います。モデルへ渡す JSON のキーは短くします。

Gemini は既定にしません。`PHOTO_AI_PROVIDER=gemini` または `openai` は、アダプタが無いので日本語の準備中を返します。未成年が使うアプリに Gemini の API を既定で使わないためです。

`verify_jwt = true` です。利用者は JWT から決めます。カロナビ+ は `public.calonavi_plus_entitlements` の `status = 'active'` かつ `expires_at > now()` です。これは既存のサーバ側の見方と同じで、レシートの再検証はしません。

### シークレットと環境変数

値は Supabase のシークレットにだけ置き、git や `supabase/config.toml` には書きません。

必須:

- `ANTHROPIC_API_KEY`

任意（未設定なら括弧の既定）:

- `PHOTO_AI_PROVIDER`（`anthropic`）
- `PHOTO_AI_LIGHT_MODEL`（`claude-haiku-5-5`）
- `PHOTO_AI_HEAVY_MODEL`（`claude-sonnet-5-5`）
- `PHOTO_AI_DAILY_LIMIT`、`PHOTO_AI_MONTHLY_LIMIT`、`PHOTO_AI_HEAVY_MONTHLY_LIMIT`、`PHOTO_AI_MONTHLY_SPEND_JPY`（空なら仮置き。オーナー未決）
- `PHOTO_AI_USD_JPY`（`158`）
- `PHOTO_AI_LIGHT_INPUT_USD_PER_MILLION`（`0.10`）、`PHOTO_AI_LIGHT_OUTPUT_USD_PER_MILLION`（`0.50`）、`PHOTO_AI_LIGHT_CACHE_READ_USD_PER_MILLION`（`0.01`）、`PHOTO_AI_LIGHT_CACHE_WRITE_USD_PER_MILLION`（`0.125`）
- `PHOTO_AI_HEAVY_INPUT_USD_PER_MILLION`（`2`）、`PHOTO_AI_HEAVY_OUTPUT_USD_PER_MILLION`（`10`）、`PHOTO_AI_HEAVY_CACHE_READ_USD_PER_MILLION`（`0.10`）、`PHOTO_AI_HEAVY_CACHE_WRITE_USD_PER_MILLION`（`2.5`）
- `PHOTO_AI_MAX_TOKENS`（`300`）、`PHOTO_AI_LIGHT_MAX_TOKENS`、`PHOTO_AI_HEAVY_MAX_TOKENS`
- `PHOTO_AI_LIGHT_THINKING`、`PHOTO_AI_HEAVY_THINKING`（`off`。`on` は adaptive。Sonnet 5.5 のオフは `between_tools`）
- `PHOTO_AI_LIGHT_EFFORT`、`PHOTO_AI_HEAVY_EFFORT`（`low`。思考オフのときは high まで）
- `PHOTO_AI_LIGHT_IMAGE_MAX_EDGE`、`PHOTO_AI_HEAVY_IMAGE_MAX_EDGE`（`1024`）

費用は、API が返した入力・出力・キャッシュ読み・キャッシュ書きのトークンから計算します。キャッシュの単価には、長いプロンプトの倍率を掛けません。軽いモデルは、キャッシュに入っていない入力が 100k トークンを超えると、その入力と出力を 5 倍で数えます。`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY` はプラットフォームが注入します。キーが無いときは 503 で「いま準備中です。手入力で記録できます。」を返し、食事の保存経路は呼びません。

### 公開前の順番

1. `supabase/migrations/20261008140000_meal_photo_analyses.sql` を、それより前のマイグレーションのあとに適用する。本番へはまだ適用していない。
2. `ANTHROPIC_API_KEY` を設定する。単価やモデルを変えるときだけ、上の任意の環境変数を足す。
3. `analyze-meal-photo` をデプロイする。この変更ではデプロイしない。
4. そのあとで、写真で登録を出すアプリを出す。マイグレーションより先に出すと、案内の `photo_meal` は再送待ちになり、利用記録の `user_edited` は書けない。食事の保存自体は、既存の食事の経路なのでマイグレーションが無くてもできる。

戻すときは、関数を消してから `supabase/rollback/20261008140000_meal_photo_analyses_down.sql` を手で流す。`photo_meal` の案内行を消してから、案内の制約を元に戻す。食事の行は残る。

### テスト

```sh
deno test --config supabase/functions/deno.json supabase/functions/analyze_meal_photo_test.ts
```

## 自炊コーチ

`cook-coach` は、手元の食材とこの食事の目標（kcal と PFC）を受け取り、確認済みの家庭料理から1品を返します。料理はモデルが作りません。リクエストのたびに `cook_recipes` と `cook_recipe_options` を読み、選んだ食品の `official_foods` で kcal と PFC を計算します。レシピはアプリに埋め込まず、応答キャッシュにもカタログ自体は入れません。行を足すと、アプリの更新なしに候補が増えます。

各材料は、そのレシピで成立する入れ替え候補だけを持ちます。名前は `{protein}` のようなテンプレで、入れ替え後も自然な料理名になります。重量は代替食材ごとの基準gで、主食は 0.5〜1.5 倍、それ以外は 0.8〜1.2 倍の範囲だけ動かします。親子丼に鮭は入りません。候補はレシピごとに明示します。

届ける範囲は、kcal が目標の ±10%（端数 0.51）、P/F/C がそれぞれ ±15% か ±5g の広い方（端数 0.05）です。範囲に入らない組み合わせは返しません。塩・しょうゆ・サラダ油・砂糖・みりん・味噌・酢・こしょう・顆粒だし・料理酒・ごはんは、利用者が避けていなければ家にあるものとして材料に出します。パン・うどん・そば・パスタは家にあるものにしません。手元だけで届かないときは、その料理で使う食材を 1 つか 2 つ買い足す案を出します。買い足し案も、入力した食材を少なくとも1つ使います。どちらも無いときは、空の配列と案内文を返します。空の結果は1日の回数に数えません。

手持ちだけで作れる案が0件の入力は、正規化した食材名と時刻だけを `cook_zero_on_hand` に残します。`user_id` は持ちません。どの組み合わせが多いかは次で見ます。

```sql
select ingredients, count(*) as zero_count
from public.cook_zero_on_hand
group by ingredients
order by zero_count desc, ingredients;

select array_to_string(ingredients, '、') as foods, count(*) as zero_count
from public.cook_zero_on_hand
group by ingredients
order by zero_count desc, foods;
```

品質チェックは型を全展開して見ます。

```sh
deno run -A supabase/functions/cook-coach/check_recipes.ts
```

採点だけ（ネットワーク無し）:

```sh
deno run -A supabase/functions/cook_coach_eval.ts
```

デプロイ後に実関数へ当てるときは、呼び出し回数の上限が必須です。この変更では実行しません。

```sh
COOK_EVAL_CALL_CAP=5 COOK_EVAL_URL=https://<project>.supabase.co/functions/v1/cook-coach \
  COOK_EVAL_TOKEN=<jwt> deno run -A supabase/functions/cook_coach_eval.ts --live
```

1日の回数は、写真で登録（`meal_photo_analyses`）と、`ai_feature_uses` の `cook_coach` と `ai_search` を合わせて数えます。初期値は 15 回です。献立を返せたときだけ、トークン 0 の `cook_coach` 行を1件追加します。モデルは呼びません。

この変更では関数をデプロイせず、マイグレーションも本番へ適用しません。

`verify_jwt = true` です。利用者は JWT から決めます。カロナビ+ は `public.calonavi_plus_entitlements` の `status = 'active'` かつ `expires_at > now()` です。

### レシピを足す

1. `supabase/functions/cook-coach/recipes.ts` に型を足す。候補は、その調理で成立するものだけにする。
2. `deno run -A supabase/functions/cook-coach/check_recipes.ts` が 0 で終わることを確認する。
3. seed を出し直す。

```sh
deno run -A supabase/functions/cook-coach/emit_recipes_sql.ts > supabase/seed/cook_recipes.sql
```

4. `official_foods` が入っているデータベースで `supabase/seed/cook_recipes.sql` を流す。参照する食品番号が足りないときは、何も入れずに戻る。
5. アプリの更新は要りません。次のリクエストから新しい行が候補になります。

### 公開前の順番

1. `supabase/migrations/20261008180000_ai_feature_uses.sql` を適用する。本番へはまだ適用していない。
2. `supabase/migrations/20261008193000_cook_recipes.sql` を適用する。本番へはまだ適用していない。
3. `official_foods` があるデータベースで `supabase/seed/cook_recipes.sql` を流す。
4. `cook-coach` をデプロイする。この変更ではデプロイしない。
5. そのあとで、自炊コーチを出すアプリを出す。

戻すときは、関数を消してから `supabase/rollback/20261008193000_cook_recipes_down.sql` と `supabase/rollback/20261008180000_ai_feature_uses_down.sql` を手で流す。食事の行は残る。

任意の環境変数は `AI_DAILY_LIMIT`（`15`。写真で登録、自炊コーチ、AIで探すの合計）です。献立の選定に `ANTHROPIC_API_KEY` は使いません。

### テスト

```sh
deno test --config supabase/functions/deno.json supabase/functions/cook_coach_test.ts
deno run -A supabase/functions/cook_coach_eval.ts
deno run -A supabase/functions/cook-coach/check_recipes.ts
```
