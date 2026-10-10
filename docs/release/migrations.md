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
11. `supabase/migrations/20261010092056_revoked_store_transactions.sql`（返金・取り消しされた transactionId。利用者には見せない。加入の行とは別）
12. `supabase/migrations/20261010143000_order_banned_public_food_trigger.sql`（10 のあと。読みを作ったあとで禁止語を見、公式の食品名と出典も見る）

禁止語だけ戻すときは、先に `supabase/rollback/20261010143000_order_banned_public_food_trigger_down.sql`、そのあと `supabase/rollback/20261010045607_reject_banned_public_food_text_down.sql`。既存の公開行はどちらも書き換えない。返金の記録は、下の関数を戻してから外す。

## カロナビ+の取引IDと返金の記録（20261010190000）

この変更では本番に適用しない。適用するときは、上の 10〜12 のあと。関数より先に、取引IDと返金記録の両方のマイグレーションを流す。`20261008090100` と `20261008090300`（pg_cron）は要らない。取引IDの埋め戻しはしない。

13. `supabase/migrations/20261010190000_entitlement_source_transaction.sql`
14. Edge Function `verify-store-transaction`（返金記録を読む版）
15. Edge Function `app-store-notifications`（返金記録を読む版）
16. App Store Connect の Server Notifications V2（本番とサンドボックス）を `https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications` にする
17. そのあと、今有効な取引だけを送るアプリ

戻すときは、出荷済みなら前のアプリ、次に 15 の関数、14 の関数の順で、返金記録を呼ばない版に戻す。それから `supabase/rollback/20261010092056_revoked_store_transactions_down.sql`。取引IDも戻すなら `supabase/rollback/20261010190000_entitlement_source_transaction_down.sql`。通知 URL は、前の関数に戻したあとも同じ URL のままでよい。関数を止めるときだけ外す。禁止語も戻すなら 12 の戻し、10 の戻し。加入の行自体は残る。新しい関数を載せたまま、返金記録の表は消さない。
