# ロールバック

新しいものほど上に書く。本番への適用は手動。このエージェントは本番 DB に接続しない。

## 20260928140000 official food provenance

先にこちらを戻す。

`supabase/rollback/20260928140000_official_food_provenance_down.sql`

列を消す前に、公開中の成分表由来マイ食品を非公開にする。対象は `visibility = 'public'` で、自身が `source_type = 'mext_sfct'` か `official_food_code` / `source_attribution` を持つか、`copied_from` をたどるとそうなる行。`visibility` は `private` にする。行は消さない。

そのあと消える列:

- `saved_foods.official_food_code`（食品番号）
- `saved_foods.official_food_name`（成分表の食品名）
- `saved_foods.source_attribution`（固定の出典文）
- `food_entries.official_food_code`
- `food_entries.official_food_name`

残る列:

- `saved_foods` の名前、栄養、`visibility`（上の行は `private`）、`copied_from_food_id`、`copied_from_owner_user_id`。`source_type` はこの時点では `mext_sfct` のまま残り、次の official foods のロールバックで `copied` になる。
- `food_entries` の食事の名前と量。`source_type = 'mext_sfct'` は削除せず `manual` に戻してから食品番号の列を消す。この更新は新しい source が `mext_sfct` ではないので、`official_foods` が先に消えていても通る。

出典を固定するトリガーと、食品番号が `official_foods` に実在することを見る関数も消える。

## 20260928120000 official foods

スキーマを戻す:

`supabase/rollback/20260928120000_official_foods_down.sql`

消えるもの: `search_official_foods`、`normalize_food_search_text`、`official_food_aliases`、`official_foods`。`pg_trgm` 拡張は残す。`saved_foods.source_type = 'mext_sfct'` の行は削除せず `copied` に戻してから、元の check 制約を付け直す。この更新は postgres、service_role、または `saved_foods` の所有者で実行する。出典ロックはセッション変数では外れない。

データだけ戻す（テーブルは残す）:

```sql
delete from public.official_foods
where source = 'mext_sfct'
  and edition = '八訂増補2023';
```

別名は `official_foods` への `on delete cascade` で一緒に消える。
