# 食品検索の表記・別名・表示名（段階1）

段階1は見本と方針だけです。本番の `official_foods` も `official_food_aliases` も `food_entries` も更新していません。マイグレーションファイルも足していません。この文書の SQL は、次の段階で人が確認してから使う控えです。

見本は食品群 01〜18 が全部入る 50 件です。和牛・乳用肥育牛・輸入牛のサーロインとヒレ、豚ロース、豚ヒレ、鶏むね（生・焼き）、ささみを含みます。

| ファイル | 内容 |
| --- | --- |
| `docs/ops/official-food-label-sample-50.csv` | 正式名称、display_name、読み、検索キー、採用した別名 |
| `docs/ops/official-food-label-sample-50.md` | 同じ 50 件と、ルールで落とした別名 |
| `tool/official_foods/label_draft.py` | 見本の生成。データベースには接続しない |
| `tool/official_foods/test_label_draft.py` | 表示名と除外ルールのテスト |

再生成はリポジトリ直下で `python3 tool/official_foods/label_draft.py` です。

## 方針

### 読み

全食品に、人が読むひらがな `reading` を持たせます。検索で比べるのは長音と空白を除いた `search_reading` です。入力側は今の `normalize_food_search_text` で、カタカナをひらがなにし、全角と半角を揃え、長音と空白を落とします。漢字はそのまま残します。漢字をひらがなに変換する辞書は検索のたびに使いません。

このため「ぎゅうどん」と「ギュウドン」は両方 `ぎゅうどん` になります。「牛丼」は `牛丼` のままです。別名の表記 `牛丼` と、その読み `ぎゅうどん` の両方が検索に入っていれば、3つの入力は同じ食品に当たります。見本ではこれを、牛飯の具（候補1）と精白米（候補2）に置いています。和牛サーロインには付けません。

ラーメンのように読みへ長音を残す語は、人が見る `reading` は `らーめん`、検索キーは `らめん` です。今の RPC は `reading` を保存された文字列のまま比べるので、長音付きの列へ `らめん` は当たりません。次の段階で検索用の列を分けます。

### 別名

一般的な呼び方を下書きし、別の食品に当たる語は落とします。見本で使っている規則は次のとおりです。

1. 正規化して 2 文字未満の語は落とす。`鮭` と `卵` はここです。`生卵` のように足します。
2. `肉` `魚` `牛` `豚` `鶏` `野菜` `牛肉` `豚肉` `鶏肉` は落とす。いのしし肉へ `牛肉` は付きません。
3. 別名に部位語（サーロイン、ヒレ、ロース、ばら、かた、もも、むね、ささみ、赤身、脂身）があり、その部位がその食品の正式名称・表示名・読みに無いときは落とす。`ささみ` は鶏むねに付きません。照合に別名自身の読みは使いません。
4. `丼` を含む語と `牛丼の具` は、食品か注記が飯・丼・めし・ご飯・ごはん・具に触れているときだけ残し、注記付きの候補にします。和牛サーロインの `牛丼` は落ちます。
5. 別の食品の表示名の括弧より前、またはその読みと、正規化して完全一致する語は落とす。もち米へ `玄米` は落ち、玄米自身の `玄米` は残ります。`和牛サーロイン` は脂身つきと皮下脂肪なしで表示の先頭が同じになるので、脂身つきだけの一意の別名にはしません。
6. ここまで残った同一の語が複数の食品に付くときは、候補でない行を落とします。`サーロイン` `ヒレ` `鶏むね` `白米` `サーモン` は候補だけが残ります。部位違いを先に落とすので、鶏むねに付いていた `ささみ` はささみ肉の一意の別名を消しません。
7. 1件だけに残った語でも、別の食品の表示名か読みに含まれていれば一意の別名にはしません。

本番に既にある 175 件（`source = karonavi_alias_v1`）は消しません。見本の規則は、これから足す下書き用です。既存データとの差は次の2点です。

- 既存の `鶏むね` は生のむね（11220）だけの確定別名です。規則どおりにすると生と焼きの候補になります。広げるかどうかは次の段階で決め、既存行は自動では書き換えません。
- 既存の `牛丼の具` は牛飯の具（18031）の確定別名です。新しい料理名の下書きは注記付き候補にしますが、この確定行は削除対象にしません。

### 表示名

一覧用の短い `display_name` を作ります。正式名称は詳細と出典に残します。出典の文面は変えません。

`＜畜肉類＞ うし ［和牛肉］ サーロイン 脂身つき 生` は `和牛 サーロイン（脂身つき・生）` です。分類の山括弧と丸括弧、棚の名前（こめ、こむぎ、だいず、塊茎、結球葉、果実）は外します。品種は先頭か括弧に残し、部位と状態が先に分かるようにします。同じ語の繰り返し（角形食パン 食パン）は1回にします。

これは規則による下書きです。全件では、規則がおかしい食品番号だけ手で上書きします。

### アイコン

段階1では画面も画像も変えていません。今は検索結果がすべて `AppIcons.rice` です。次の段階では、既存の SVG で意味が合う群だけ変えます。

| 食品群 | アイコン |
| --- | --- |
| 01 穀類 | `AppIcons.rice` |
| 11 肉類 | `AppIcons.meat` |
| 18 調理済み流通食品類 | `AppIcons.meal` |
| それ以外 | 当面 `AppIcons.rice` |

し好飲料の全体に酒のアイコンを付ける、野菜にアボカドを付ける、といった寄せ方はしません。合う絵が無い群は、絵を足してから切り替えます。

## 全 2,538 件の作り方

1. `official_foods` から `food_code`、`food_group`、`name` を読み取り専用で出します。生成スクリプトは接続しません。
2. 見本と同じ `draft_display_name` と `draft_reading` にかけます。読みはトークンの辞書です。カタカナはひらがなへ畳み、辞書に無い漢字は `KeyError` で止めます。形態素解析で推測しません。止まった語を `TOKEN_READING` に足して、もう一度走らせます。
3. 別名は食品ごとに、日常の呼び方を AI が CSV で下書きします。列は食品番号、別名、読み、候補か、順位、注記です。
4. `review_aliases` を 50 件ではなく 2,538 件全部にかけます。1件の見本では安全でも、表のどこかに同じ語があれば一意の別名にはなりません。
5. 落ちた行と、候補として残った行を人が見ます。表示名は、おかしい食品番号だけ上書き表で直します。
6. 採用分だけを、別ソース名 `label_draft_v1` の INSERT にします。既存 175 件は残します。

## データベースの変更案

列の新設は読みの検索キーだけです。`display_name` と `reading` は既にあります。本番では `reading` は空、`display_name` は正式名称のコピー（末尾空白の差が 4 件）です。値を入れることは UPDATE です。

追加する列:

- `official_foods.normalized_reading text`
- `official_food_aliases.normalized_reading text`

人が見る `reading` には長音と空白を残します。検索の trigram 索引は `normalized_reading` に張り、RPC の読み照合はその列を見ます。列を関数で包むと索引が使えないので、保存時に正規化します。別名の表記照合は今どおり `normalized` です。

正規化そのものは、SQL・Dart（`lib/utils/food_search_normalizer.dart`）・Python（`tool/official_foods/normalize.py`）を同じテストケースで一緒に広げ、`・` `（）` `＜＞` `［］` などの記号も落とします。段階1ではこの関数を変えていません。漢字の読み変換は入れません。

別名の追加は `source = 'label_draft_v1'` だけにします。`food_entries` には触れません。記録済みの食事の食品名も食品番号も変わりません。

RPC `search_official_foods` の戻りにある `display_name` は、短い表示名が入ります。照合の順位付けは今の4本（正式名称の正規化、食品の読み、別名の正規化、別名の読み）のまま、読みの2本だけ列を `normalized_reading` に替えます。

## 本番へ入れる前の控えと戻し方

入れる直前に、更新する列と別名の全行を控え表へコピーします。日付は作業日に置き換えます。

```sql
create table public.official_foods_label_backup_YYYYMMDD as
select food_code, display_name, reading
from public.official_foods;

create table public.official_food_aliases_backup_YYYYMMDD as
select *
from public.official_food_aliases;
```

戻すときは、控えから表示名と読みを返し、この作業で足した別名だけを消します。既存 175 件はソース名が違うので残ります。

```sql
update public.official_foods as food
set display_name = backup.display_name,
    reading = backup.reading
from public.official_foods_label_backup_YYYYMMDD as backup
where food.food_code = backup.food_code;

delete from public.official_food_aliases
where source = 'label_draft_v1';

drop index if exists public.official_foods_normalized_reading_trgm_idx;
drop index if exists public.official_food_aliases_normalized_reading_trgm_idx;
alter table public.official_foods drop column if exists normalized_reading;
alter table public.official_food_aliases drop column if exists normalized_reading;
```

`normalize_food_search_text` と `search_official_foods` を変えた場合は、直前のマイグレーション本体で関数を作り直します。`food_entries` の戻しは要りません。

## 画面の変更案

段階1では Flutter も変えていません。次の段階の向きは次のとおりです。

- 一覧の見出しは、別名で当たったときだけその別名です。それ以外は `display_name` です。今は `recordName` が別名か正式名称です。
- 別名で当たった行の補足に、短い `display_name` を出します。
- 詳細の本文は正式名称のままです。出典は `OfficialFoodCopy` の今の文面（「出典：八訂成分表 増補2023年（文部科学省）を加工して作成」を含む）を維持します。
- 食事へ残す名前は、別名で当たったときは別名、それ以外は `display_name` です。`official_food_code` は今どおりです。公開前の記録は長い正式名称のまま残ります。
- アイコンは上の表のとおり、食品群から既存の SVG を選びます。
