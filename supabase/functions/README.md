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
```
