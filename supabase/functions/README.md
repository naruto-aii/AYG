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

## 利用者チェックポイントの Slack 通知

`userlog-notify` が Slack に出すのは次の 6 種類だけ。

- 新規会員登録（`app_events` の `onboarding_complete`。文面の旧名は「初回登録完了」）
- 無料トライアル開始
- 有料開始（同じ購入が無料トライアルで始まり、そのあと最初の `DID_RENEW`）
- トライアル解約とサブスク解約（どちらも `DID_CHANGE_RENEWAL_STATUS` / `AUTO_RENEW_DISABLED`。記録の種類は `cancel` のまま。同じ購入がトライアルから始まり、オフより前に `DID_RENEW` がなければ文面は「トライアル解約」、それ以外は「サブスク解約」）
- アカウント削除（`account_deletion_stats` に行が増えたとき。プランと使った期間の区分だけ。利用者 ID と表示名は出さない）

インストール、ログイン、期限切れ（`EXPIRED`）、返金（`REFUND`）は出さない。ログインは `userlog_app_events_login_insert` を外すだけにする。集計対象外は文面の末尾に「（集計対象外）」を付ける。`app-store-notifications` は変更しない。

既存の表の列・制約・行は変えない。`public.userlog_notifications_sent` の種類制約も変えない。アカウント削除の二重送信は `public.userlog_account_deletion_sent` で止める。トリガーは失敗を飲み、元の INSERT は成功する。この変更では関数を配備せず、マイグレーションも本番へ適用しない。

秘密の名前（値は git に書かない）:

- `SLACK_USERLOG_WEBHOOK_URL` — Incoming Webhook。Edge Function の秘密。
- `SLACK_USERLOG_MENTION` — 投稿の先頭でメンションする Slack メンバー ID。Edge Function の秘密。
- `USERLOG_NOTIFY_SECRET` — 32 文字以上。Edge Function の秘密。Vault の `userlog_notify_secret` と同じ値。
- Vault の `project_url` — 関数の起点。取り込み用と同じ名前。この節には値を書かない。

本番へ出す順番（関数が先。マイグレーションを先にすると、アカウント削除の呼び出しを古い関数が理解できない）:

1. `userlog-notify` を配備する。秘密はすでに入っているものを使う。この時点ではトリガーはまだ切り替えない。配備した関数は、インストール、ログイン、期限切れ、返金が届いても投稿しない。
2. `20261017033236_userlog_six_checkpoints.sql` を適用する。ログインのトリガーを外し、インストールを新規会員登録のトリガーから外し、期限切れと返金を購入通知の候補から外し、アカウント削除のトリガーを足す。このファイルは過去分を送らない。pg_cron は有効にしない。`userlog.enqueue_backfill()` は実行しない。
3. 件数だけを見る。

```sql
select count(*)
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where t.tgname = 'userlog_app_events_login_insert'
  and not t.tgisinternal;

select c.relname, pg_get_triggerdef(t.oid)
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and t.tgname in ('userlog_app_events_insert', 'userlog_account_deletion_insert')
  and not t.tgisinternal
  and c.relname in ('app_events', 'account_deletion_stats');
```

ログインのトリガーは 0 件。`app_events` のトリガー条件は `onboarding_complete` だけ。`account_deletion_stats` に挿入トリガーがある。

戻すときは、先に #138 時点（この変更前の main）の `userlog-notify` を配備し直してから、`supabase/rollback/20261017033236_userlog_six_checkpoints_down.sql` を手で流す。コミットは `d84544a8c5ac0c3eea01b00b8b6514311f4fb55f`（ログイン通知をインストールごとに1回にする）。rollback SQL だけだと、新しい関数がインストール、ログイン、期限切れ、返金を捨てるので投稿は戻らない。SQL のあと、ログインのトリガーと、インストール・期限切れ・返金の候補が戻る。アカウント削除用の新しい表は落ちる。`userlog_notifications_sent` の行は残る。通知全体を外すときは、そのあと以前の rollback を流す。pg_net と既存の表は残る。

```sh
deno test --allow-env --config supabase/functions/deno.json supabase/functions/userlog_notify_test.ts
bash supabase/tests/run_userlog_notifications_test.sh
```

付与表（課金ではないカロナビ+）は本番の DB では試さない。写真、料理、食品検索は、加入行があるときは付与を見ない。加入の問い合わせが失敗したときは今までどおり 503。付与の問い合わせが失敗したときは、無料の利用者と同じく未加入にする。

```sh
bash supabase/tests/run_complimentary_plus_test.sh
deno test --allow-env --config supabase/functions/deno.json supabase/functions/complimentary_plus_gate_test.ts supabase/functions/plus_gate_retry_test.ts
```
