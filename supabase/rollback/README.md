# ロールバック

新しいものほど上に書く。本番への適用は手動。このエージェントは本番 DB に接続しない。

## 20260928140000 official food provenance

先にこちらを戻す。

`supabase/rollback/20260928140000_official_food_provenance_down.sql`

消えるもの: `saved_foods` の `official_food_code`、`official_food_name`、`source_attribution`、`food_entries` の `official_food_code`、`official_food_name`、出典を固定するトリガー。`food_entries.source_type = 'mext_sfct'` の行は削除せず `manual` に戻す。マイ食品の `source_type` は、その次の official foods のロールバックで `copied` に戻す。

## 20260928120000 official foods

スキーマを戻す:

`supabase/rollback/20260928120000_official_foods_down.sql`

消えるもの: `search_official_foods`、`normalize_food_search_text`、`official_food_aliases`、`official_foods`。`pg_trgm` 拡張は残す。`saved_foods.source_type = 'mext_sfct'` の行は削除せず `copied` に戻してから、元の check 制約を付け直す。

データだけ戻す（テーブルは残す）:

```sql
delete from public.official_foods
where source = 'mext_sfct'
  and edition = '八訂増補2023';
```

別名は `official_foods` への `on delete cascade` で一緒に消える。
