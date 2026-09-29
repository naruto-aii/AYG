# 食品検索の表示名・読み・別名（段階2）

段階1の見本（PR #38）を全 2,538 件に広げた。正式名称は変えず、一覧用の `display_name` とひらがなの `reading`、検索用の `normalized_reading` を入れる。既存の別名 175 件（`source = karonavi_alias_v1`）は残す。新しい別名は `source = label_draft_v1` で、同じ食品番号と正規化表記が既にある行は入れない。

## 生成

`tool/official_foods/data/official_food_names.tsv` は本番の食品番号・食品群・正式名称の読み取り結果。`python3 tool/official_foods/label_all.py` がマイグレーションと抜き取り表を書き直す。データベースには接続しない。

- 表示名は段階1と同じ規則。分類の山括弧、末尾が「類」の棚、部位の棚語を外し、状態は括弧に入れる。和牛サーロインは `和牛 サーロイン（脂身つき・生）`。
- 読みはトークン辞書を優先する。辞書に無い漢字は、食品名で誤読しやすい語（米、でん粉、粉、生の送り仮名、漬、魚醤油など）を直してから読みにする。漢字が残ったら生成を止める。
- 別名は、正式名称だけでは引けない短い呼び方だけを足す。別の食品の名前そのもの、部位が違う語、1文字、料理と無関係な食品への丼、は落とす。同じ語が複数の食品に付くときは候補にする。
- グループ語は一意の別名にしない。当てはまる食品をすべて候補にする。

| 語 | 読み | 対象 |
| --- | --- | --- |
| 牛肉 / ビーフ / 牛 | ぎゅうにく / びーふ / ぎゅう | 肉類のうち、正式名称に「うし」がある 139 件（和牛・乳用肥育牛・輸入牛の全部位） |
| 豚肉 / ポーク / 豚 | ぶたにく / ぽーく / ぶた | 肉類のうち「ぶた」101 件 |
| 鶏肉 / チキン / 鶏 | とりにく / ちきん / とり | 肉類のうち「にわとり」38 件 |
| 肉 | にく | 肉類 317 件 |
| 魚 | さかな | 魚介類のうち＜魚類＞339 件 |

ぎゅうにくとギュウニクは同じ検索キーになる。牛丼の具は肉類ではないので牛肉には入らない。正式名称に含まれる「うし」「ぶた」の部分一致は、今までどおり名称の検索に残す。

並びは検索のあと、その利用者の `food_entries` の食品番号ごとの回数、同じなら直近、の既存の並べ替えに従う。グループ語は件数が 30 を超えるので、その語そのものを検索したときは RPC が上限を 800 まで広げる。それ以外の検索は今までどおり最大 100、画面は 30 である。

抜き取りは `docs/ops/official-food-label-spotcheck.md`。

## 控え

マイグレーションの先頭で、更新前の値を次の表にコピーする。API からは読めない（RLS を有効にし、anon と authenticated の権限はない）。

- `public.official_foods_label_backup_20260929`（food_code, display_name, reading）
- `public.official_food_aliases_backup_20260929`（別名の全列）

`food_entries` は触らない。

## 戻し方

ラベルだけ戻す。食事記録はそのまま残る。

```sql
update public.official_foods as food
set display_name = backup.display_name,
    reading = backup.reading,
    normalized_reading = null
from public.official_foods_label_backup_20260929 as backup
where food.food_code = backup.food_code;

delete from public.official_food_aliases
where source = 'label_draft_v1';
```

検索用の列とグループ語の動きまで戻すときは、加えて次を実行する。`search_official_foods` は `20260928120000_official_foods.sql` の関数定義で作り直す。

```sql
drop index if exists public.official_foods_normalized_reading_trgm_idx;
drop index if exists public.official_food_aliases_normalized_reading_trgm_idx;
drop index if exists public.official_food_aliases_group_term_idx;
drop trigger if exists official_foods_fill_normalized_reading on public.official_foods;
drop trigger if exists official_food_aliases_fill_normalized_reading on public.official_food_aliases;
drop function if exists public.official_foods_fill_normalized_reading();
alter table public.official_foods drop column if exists normalized_reading;
alter table public.official_food_aliases drop column if exists normalized_reading;
alter table public.official_food_aliases drop column if exists is_group;
```

控えの表を消すのは、戻しが済んでからにする。

```sql
drop table if exists public.official_food_aliases_backup_20260929;
drop table if exists public.official_foods_label_backup_20260929;
```

## 画面

一覧の見出しは `display_name`。候補には「（候補）」を付ける。正式名称は一覧に出さない。詳細の見出しは短い名前、本文は正式名称、出典は「出典：八訂成分表 増補2023年（文部科学省）を加工して作成」を含む今の文面のまま。食事に残す名前も短い名前にし、`official_food_name` は正式名称のまま。
