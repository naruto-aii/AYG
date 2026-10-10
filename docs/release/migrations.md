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
