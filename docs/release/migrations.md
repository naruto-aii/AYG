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
11. `supabase/migrations/20261010143000_order_banned_public_food_trigger.sql`（10 の直後。読みを作ったあとで禁止語を見、公式の食品名と出典も見る）

戻すときは、先に `supabase/rollback/20261010143000_order_banned_public_food_trigger_down.sql`、そのあと `supabase/rollback/20261010045607_reject_banned_public_food_text_down.sql`。既存の公開行はどちらも書き換えない。

## カロナビ+の取引ID（20261010190000）

この変更では本番に適用しない。適用するときは、上の 10 と 11 のあと。関数より先にマイグレーションを流す。`20261008090100` と `20261008090300`（pg_cron）は要らない。取引IDの埋め戻しはしない。

12. `supabase/migrations/20261010190000_entitlement_source_transaction.sql`
13. Edge Function `verify-store-transaction`
14. Edge Function `app-store-notifications`
15. App Store Connect の Server Notifications V2（本番とサンドボックス）を `https://vdzzusqisymtejcjnikb.supabase.co/functions/v1/app-store-notifications` にする

戻すときは、先に通知 URL を外し、14 の関数、13 の関数の順で前の版に戻してから、`supabase/rollback/20261010190000_entitlement_source_transaction_down.sql`。そのあと禁止語は 11 の戻し、10 の戻し。加入の行自体は残る。
