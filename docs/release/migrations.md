# マイグレーションと自炊コーチの seed

この変更では、本番にマイグレーションを適用しない。関数もデプロイしない。`supabase/seed/cook_recipes.sql` も本番には流さない。

出すときは、次の順で手で適用する。ファイル名の時刻順と同じである。

1. `supabase/migrations/20261008140000_meal_photo_analyses.sql`
2. `supabase/migrations/20261008160000_ai_food_lookup.sql`
3. `supabase/migrations/20261008160100_food_memo_is_free.sql`（160000 の直後。食事と運動のメモを無料にする）
4. `supabase/migrations/20261008180000_ai_feature_uses.sql`
5. `supabase/migrations/20261008190000_ai_food_result_collections.sql`
6. `supabase/migrations/20261008193000_cook_recipes.sql`
7. `supabase/migrations/20261008200000_entitlements_server_only.sql`
8. `supabase/migrations/20261008210000_ai_data_consent.sql`
9. `supabase/migrations/20261009010000_fix_search_path.sql`（140000〜210000 で足した関数の search_path を `public, pg_temp` に固定する。cook_recipes のマイグレーションは関数を作っていない）

## 利用規約の同意（2026-10-10）

新しいマイグレーションは無い。同意は既存の `public.ai_data_consents`（`user_id`、`policy_version`、`consented_at`）にアカウントごとに残す。版は `2026-10-10`。`2026-10-08` の行は、次の起動で同意画面をもう一度出す。

本番に `supabase/migrations/20261008210000_ai_data_consent.sql` がまだ無いときは、このビルドの前に手で適用する。適用済みなら、版の文字列を変えただけでは SQL は要らない。アカウント削除で行が消えるトリガーも、そのマイグレーションに入っている。

新規アカウントが同意を保存できない件は、下の「同意を初回設定より前に保存する」を見る。アプリの版の文字列とは別の SQL である。

エッジ関数 `analyze-meal-photo` と `lookup-food-text` は、`2026-10-08` と `2026-10-10` のどちらも有効な同意として受け付ける。AI の送信先の文言は両方の版で同じ。アプリは `2026-10-10` だけを今の版とし、`2026-10-08` のアカウントには同意画面を出す。

関数は審査の前に本番へ出せる。旧アプリ（`2026-10-08` に同意済み）の AI は止まらない。新しい版の同意も、先に出た関数は拒まない。審査中の端末が本番の関数を使うときも、`2026-10-10` の同意で AI が 403 にならない。アプリだけ先に出すと、関数が `2026-10-08` だけを見ているあいだは新しい同意が拒まれる。関数を先に出す。

この変更では本番に適用もデプロイもしない。

`20261008193000` はレシピの表だけを作る。行は seed にある。

## seed の出し方と流し方

レシピを変えたときは、先に型をチェックしてから SQL を出し直す。

```sh
deno run -A supabase/functions/cook-coach/check_recipes.ts
deno run -A supabase/functions/cook-coach/emit_recipes_sql.ts > supabase/seed/cook_recipes.sql
```

流すのは、`20261008193000_cook_recipes.sql` のあと、`official_foods` が入っているデータベースだけである。seed は参照する食品番号が足りないと、何も入れずに戻る。

```sh
psql "$DATABASE_URL" -f supabase/seed/cook_recipes.sql
```

本番のデータベースには、この変更では流さない。

## 公開食品の禁止語（20261010045607）

この変更では本番に適用しない。適用するときは、上の 1〜9 のあと、次の 1 ファイルだけを足す。`20261008090100` と `20261008090300`（pg_cron）は、この禁止語にも App Store の通知にも要らない。

10. `supabase/migrations/20261010045607_reject_banned_public_food_text.sql`
11. `supabase/migrations/20261010143000_order_banned_public_food_trigger.sql`（10 のあと。読みを作ったあとで禁止語を見、公式の食品名と出典も見る）

禁止語だけ戻すときは、先に `supabase/rollback/20261010143000_order_banned_public_food_trigger_down.sql`、そのあと `supabase/rollback/20261010045607_reject_banned_public_food_text_down.sql`。既存の公開行はどちらも書き換えない。

## カロナビ+の取引IDと返金の記録（20261010190000 のあと）

この変更では本番に適用しない。適用するときは、上の 10 と 11 のあと。ファイル名の時刻順と同じで、返金記録は取引IDのあとである。返金記録の SQL は `143000` と `190000` の表や関数を読まない。`public.users` だけを参照する。`20261008090100` と `20261008090300`（pg_cron）は要らない。取引IDの埋め戻しはしない。関数は 12 と 13 の両方のあと。

12. `supabase/migrations/20261010190000_entitlement_source_transaction.sql`
13. `supabase/migrations/20261010200000_revoked_store_transactions.sql`（返金・取り消しされた transactionId。利用者には見せない。加入の行とは別）
14. Edge Function `verify-store-transaction`（返金記録を読む版）
15. Edge Function `app-store-notifications`（返金記録を読む版）
16. App Store Connect の Server Notifications V2（本番とサンドボックス）を `https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications` にする
17. そのあと、今有効な取引だけを送るアプリ

戻すときは、出荷済みなら前のアプリ、次に 15 の関数、14 の関数の順で、返金記録を呼ばない版に戻す。それから `supabase/rollback/20261010200000_revoked_store_transactions_down.sql`。取引IDも戻すなら `supabase/rollback/20261010190000_entitlement_source_transaction_down.sql`。通知 URL は、前の関数に戻したあとも同じ URL のままでよい。関数を止めるときだけ外す。禁止語も戻すなら 11 の戻し、10 の戻し。加入の行自体は残る。新しい関数を載せたまま、返金記録の表は消さない。

## 同意を初回設定より前に保存する（20261010213000）

この変更では本番に適用しない。アプリは出さない。1.0.0 (11) の同意画面は、`public.users` を作る初回設定より前に `ai_data_consents` へ書く。参照先が `public.users` のままだと、新規アカウントは外部キーで 409 になる。

本番に `20261008210000_ai_data_consent.sql` が既にあるときは、次の 1 ファイルだけを足す。返金記録や禁止語より先に流してよい。中身は `ai_data_consents` と `auth.users` だけを見る。`public.users` の行は作らない。初回設定の完了は `app_settings.onboarding_complete` のままである。

18. `supabase/migrations/20261010213000_ai_data_consent_auth_user.sql`

列は変えないので、審査中のアプリを作り直さなくてよい。ファイルの末尾で PostgREST にスキーマの再読み込みを知らせる。

```sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261010213000_ai_data_consent_auth_user.sql
```

戻すときは `supabase/rollback/20261010213000_ai_data_consent_auth_user_down.sql`。参照先を `public.users` に戻す。`public.users` が無い同意行は消える。食事の行は消えない。戻すと、新規アカウントは再び同意を保存できない。
