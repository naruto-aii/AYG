# 公式食品テーブルの本番適用とロールバック

日本食品標準成分表（八訂）増補2023年を、読み取り専用の `official_foods` / `official_food_aliases` として本番へ載せるときの手順です。実行主体は Supabase MCP コネクタ（`apply_migration` と `execute_sql`）を使う人です。この文書をマージしてもデータベースは変わりません。

機能そのもののマイグレーションと取込スクリプトは別 PR です。ここにあるのは適用順、受け入れ、戻し方です。識別子が機能 PR と違っていたら、先に `supabase/acceptance/official_foods/accept_official_foods.sql` の CONFIG を合わせてから本番で使います。

## やらないこと

- この手順の途中でマイグレーションをマージしない。フラグ `officialFoodsEnabled` を手順の途中でオンにしない。
- `tool/official_foods/import.py` に本番の URL を渡さない。実装は `*.supabase.co` と `SUPABASE_` を含む URL を拒否する想定です。拒否を外すフラグは作りません。
- サービスロールキー、データベース URL、アクセストークンをチケット、このリポジトリ、MCP の引数メモに書かない。`project_id` は変更チケットにだけ控えます。
- `pause_project` をバックアップの代わりにしない。ダッシュボードのリストア API を、この手順の通常経路として呼ばない。
- `COPY ... FROM '/path'`、`pg_read_file`、`lo_import` でサーバ上のファイルを読まない。MCP はそれを拒否します。データはクライアント側で作った `INSERT` を `execute_sql` に渡します。
- 全件をマイグレーション SQL に埋め込まない。

## 所要時間

データベースが忙しい時間は避けます。件数照合を厳密にするなら、スナップショットから受け入れ完了までアプリの書き込みを止めます。止めない場合、既存テーブルの件数差はアプリ利用と区別できません。

| 手順 | 目安 |
| --- | --- |
| プロジェクト確認とバックアップ確認 | 5–15 分（人がダッシュボードを見る時間） |
| 既存テーブルのスナップショット | 1 分未満。`food_entries` が大きいと count で 5 分程度 |
| `pg_trgm` の有無確認と作成 | 10 秒未満。既にあるときは作らない |
| 公式食品の DDL | 30 秒未満（空テーブルと GIN。2,538 行の索引も秒単位） |
| データ投入（食品 2,538 件と別名。冪等のため食品を 2 周する） | 5–20 分（MCP の往復が大半） |
| 受け入れ SQL | スナップショットと同程度。通常 1–2 分 |
| 版だけの削除、または新テーブルの drop | 5–10 秒 |
| プロジェクト全体のバックアップ復元 | 最終手段。プロジェクトは停止する。時間はデータベースの大きさに比例する（Supabase の説明どおり。ここには分数を書かない） |

SQL を流している正味の時間は数分です。確認とレビューを入れると、人が付き合う枠はおおよそ 30–60 分です。

## 0. 機能 PR の SQL を固定する

1. 適用する機能 PR のコミットを変更チケットに書く。
2. そのコミットのマイグレーションファイル（ブリーフ上のパスは `supabase/migrations/20260928120000_official_foods.sql`。ファイル名が違えばチケットに実際のパスを書く）を開く。
3. 次を目で確認する。どれか違えば本番に流す前に CONFIG を直し、差をチケットに残す。
   - 新テーブルは `public.official_foods` と `public.official_food_aliases` だけか。既存テーブル（とくに `saved_foods`）への `ALTER` があるか。
   - `auth.` を触っていないか。触っているならこの手順を止める。
   - 検索関数は security invoker で stable か。正規化関数は immutable で `search_path` を空にしているか。
   - `anon` / `authenticated` への INSERT、UPDATE、DELETE、TRUNCATE が無いこと。SELECT は `authenticated` のみ。
4. `pg_trgm` を `extensions` スキーマに作る文がマイグレーションに含まれるなら、下記「4. `pg_trgm`」の単独作成は、既にあるのでスキップしてよい。
5. ワークブックは次のファイルと一致させる。sha256 が違う版を投入しない。
   - `https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_02.xlsx`
   - sha256 `0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c`
   - シート「表全体」。食品番号 5 桁は 2,538 件。エネルギーは成分識別子 `ENERC_KCAL`（可食部 100 g 当たり）。
   - この xlsx の更新日は 2026-03-27 で、正誤表の kcal 修正を既に含みます。`11183` は 241 です（誤として記録されている 244 ではない）。正誤表をこのファイルの上にもう一度足すと値が二重に動きます。受け入れが kcal で落ちたら、二重適用を先に疑います。

## 1. プロジェクトを特定する

MCP のツール名と引数です。

1. `list_projects`（引数なし）。
2. 変更チケットの本番プロジェクトだけを選ぶ。候補が複数で名前が確定できないときは止める。
3. `get_project` の引数 `id` に、そのプロジェクトの id を渡す。
4. 返ってきた名前と id がチケットと一致し、停止中でないことを確認する。以降の `project_id` はすべてこの id です。本文には書きません。

## 2. バックアップを確認する

MCP にバックアップを取るツールはありません。ダッシュボードの Database → Backups を開きます。

- Pro 以上で日次バックアップがある、または PITR が有効で、いまの時刻が復元可能範囲に入っている。どちらかを満たすこと。最新の復元ポイントの時刻をチケットに書く。
- Free で日次バックアップが無いときは止める。続けるなら、適用前に Supabase CLI の `db dump` をプロジェクト外の保管場所へ取り、保管できたことを確認してから先へ進む。ダンプに Storage オブジェクトは含まれません。
- トークンを使った Management API の例は、この手順では使いません。
- まだ存在しない公式食品テーブルのダンプは取りません。守る対象は既存のユーザデータです。

## 3. 既存オブジェクトのスナップショット

書き込みを止めるなら、ここで止めます。

`execute_sql` の引数は `project_id` と `query` です。`query` には `supabase/acceptance/official_foods/snapshot_user_tables.sql` の全文を貼ります。トランザクションは `read only` です。

返った jsonb を 1 つ、チケットかローカルの作業ファイルに保存します。リポジトリにはコミットしません。`database` の値を控えます。

ツールが `BEGIN` を拒否する（既にトランザクションの中、など）ときは、ファイル先頭の `begin read only;` と末尾の `commit;` だけを外し、`select ... as snapshot` だけを送ります。`set local` が残ってエラーになるときも、その 1 行を外して SELECT だけにします。SELECT 自体は読み取りです。

タイムアウトしたら、両方の SQL ファイルの `statement_timeout`（いまは 120s）を同じ値に上げてやり直します。推定件数には切り替えません。タイムアウトでユーザデータは変わりません。

## 4. `pg_trgm`

1. `list_extensions`（引数 `project_id`）。
2. 併せて `execute_sql`:

```sql
select e.extname, n.nspname
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
where e.extname = 'pg_trgm';
```

- 行が返る: 作らない。スキーマが `extensions` でなくても移動しない。
- 行が無い: `apply_migration` を 1 回だけ使う。
  - `project_id`: 手順 1 の id
  - `name`: `enable_pg_trgm`
  - `query`:

```sql
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
```

`public` に作ると、受け入れが public の新しい関数として失敗します。機能マイグレーション側にも同じ `if not exists` があるなら、そちらに任せてこの単独マイグレーションはスキップして構いません。両方流しても `if not exists` なら 2 回目は何もしません。

## 5. マイグレーションを適用する

1. `list_migrations`（引数 `project_id`）。`official_foods` が既にあれば止めて、下記「7. 受け入れ」に進むか、適用済みとして扱うかをチケットで決める。同じ DDL を重ねない。
2. 機能 PR のマイグレーションファイルの中身を、編集せず `apply_migration` の `query` に貼る。
   - `name`: `official_foods`（snake_case。ファイル名のタイムスタンプではない）
   - `project_id`: 手順 1 の id
3. ツールが確認を求めたら、貼った SQL が手順 0 で読んだファイルと同一であることだけを確認してから承認する。
4. もう一度 `list_migrations` を呼び、`official_foods` が増えていることを見る。

依存する関数（例: 既存の `normalize_public_food_name`）が本番に無くて失敗したら、公式食品用の SQL をその場で書き換えない。依存元の適用を別の変更として止めて判断します。`normalize_public_food_name` 自体はロールバックで drop しません。

## 6. データを入れる

ローカル（本番 URL ではないマシン）で、機能 PR の変換処理から CSV を作ります。`import.py` は使いません。

CSV から、食品を先、別名を後にした `INSERT ... ON CONFLICT DO UPDATE` を作り、`execute_sql` で流します。1 呼び出しあたり 200 行程度に分けます。ツールがペイロードを拒否したら 50 行まで下げます。衝突キーは食品番号です。別名は食品の外部キーがあるので、食品が終わってから入れます。

- 1 周目のあと、先頭バッチだけもう一度流し、エラーにならないことを見る。
- 食品バッチ全体をもう 1 周流してよい。件数が 2,538 のままなら冪等です。2 周目も 5–20 分見ます。必須ではありません。受け入れの件数チェックが本線です。
- 列名は手順 5 のあとに `information_schema.columns` で見たものに合わせます。CONFIG の列名と同じにします。
- 投入後に `01088` の kcal が 156、名前がワークブックの全角スペース区切り（U+3000）のままであることを、受け入れ SQL が検証します。ここで手作業の SELECT を足す必要はありません。

`execute_sql` は DML として確認を求めることがあります。確認するのは、レビュー済みのそのバッチだけです。

## 7. 受け入れ

1. `accept_official_foods.sql` をローカルで複製する。リポジトリのファイルは `v_baseline jsonb := null` のままにする。
2. 複製の CONFIG で、`v_baseline jsonb := null` を手順 3 の jsonb に差し替える。ドル引用符の例はファイル先頭に書いてあります。スナップショットの中に区切り文字 `$of_baseline$` が無いことを見てから貼ります。
3. 機能 PR で名前が違っていれば、同じ CONFIG の識別子だけ直す。`v_search_limit` と `v_search_limit_cap` は 30 のままです。
4. リポジトリの CONFIG は PR #31（`cursor/official-foods-import-0702` @ `7988b2f`、`supabase/migrations/20260928120000_official_foods.sql`）の実名に合わせ済みです。テーブルは `official_foods` / `official_food_aliases`、列は `food_code` `name` `kcal` `source` `edition` `base_amount` `unit_type`、関数は `normalize_food_search_text` と `search_official_foods`（戻り順は関数内の `rank_value` なので `v_rank_column` は null）です。同マイグレーション末尾が `saved_foods_source_type_check` を作り直し `mext_sfct` を足すため、`v_ignore_signature_for` は `saved_foods` だけです。件数の一致はそれでも必須です。`saved_foods` を `v_exclude_tables` に入れてはいけません。後続の機能 PR が別名に変えたときだけ、識別子を CONFIG で直します。
5. 複製の全文を `execute_sql` の `query` に貼る。
6. スクリプトは anon と authenticated で INSERT / UPDATE / DELETE / TRUNCATE を試し、権限エラー（SQLSTATE 42501）でなければ失敗します。試行はサブトランザクションで巻き戻します。ツールが「破壊的な文」として確認を出しても、承認してよいのはこの受け入れを今走らせるときだけです。成功時に公式食品行もユーザテーブルもコミットされません。
7. 結果が 1 行で `status` が `PASS` なら成功です。`detail` をチケットに貼ります（件数、検索の先頭コード、`牛丼` のコード、ユーザテーブルの差分）。差分が空でない PASS は、`v_count_match_required` を false にした再実行だけです。その差分の説明をチケットに書いてからフラグ検討に進みます。
8. `ACCEPTANCE FAIL:` は失敗です。フラグをオンにしません。原因がデータなら手順 9 の版削除、定義の誤りなら手順 9 のオブジェクト削除に進むか、機能 PR を直してからやり直します。ユーザテーブルの署名が変わっていたら、説明が付くまでフラグもロールフォワードも進めません。

`BEGIN` が拒否されたときは、スナップショットと同じくトランザクション行を外し、`do` から最後の `select` までを 1 つの `query` として送ります。`do` だけが実行できた場合、エラーが無く NOTICE に `ACCEPTANCE PASS` が出ていることを成功とみなします。可能なら `select` の PASS 行を取ります。

タイムアウトの扱いは手順 3 と同じです。

## 8. アプリの出し方

データベースが PASS する前にフラグをオンにしません。

1. `officialFoodsEnabled` は dart-define の既定 false のままにする。
2. 手順 7 が PASS してから、出典文言を含むビルドを出す。フラグはまだ false。フラグが off のとき検索は空で失敗し、アプリは落ちないこと。
3. 社長承認のあと、別ビルドでフラグを true にする。マイグレーションと同じ操作でオンにしない。
4. オンにするビルドに、次の文言がそのまま入っていること。SQL では検証しません。
   - 検索結果・食品詳細・課金画面: `出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成`
   - 設定の出典画面には、文部科学省サイトへのリンク（外部ブラウザ。`文部科学省ウェブサイトへ移動します` と分かる表示）と、1 食分・別名・よみは当社の換算であり文部科学省の保証ではないこと、表示値は目安であることを書く。
5. 文部科学省のロゴや「公認」は使わない。
6. 受け入れが失敗したままフラグだけ戻す必要はありません。フラグはまだ false です。データベース側は手順 9 です。

## 9. ロールバック

通常の戻し方は、ユーザテーブルを巻き戻さない方法です。プロジェクト復元は、ユーザテーブルの署名が壊れて外科的に戻せないときだけです。復元はバックアップ以降のユーザ入力を捨てます。

### 9.1 この版のデータだけ消す

別名は食品への外部キーの cascade で消える想定です。機能 PR の down が cascade でなければ、別名を先に消します。

`execute_sql` の `query`:

```sql
delete from public.official_foods
where source = 'mext_sfct'
  and edition = '八訂増補2023';
```

ツールの破壊的操作の確認は、この削除を実行すると決めたときだけ承認します。2,538 行なら 5 秒未満です。

確認:

```sql
select count(*) from public.official_foods
where source = 'mext_sfct' and edition = '八訂増補2023';
```

0 であること。他の版を入れたあとなら、その版の行は残ります。

### 9.2 オブジェクトを drop する

機能 PR の down ファイル（ブリーフ上は `supabase/rollback/20260928120000_official_foods_down.sql`）があるなら、その全文を `apply_migration` に渡します。

- `name`: `rollback_official_foods`
- `query`: down ファイルの全文

down がまだ無いときの順序です。CONFIG で名前を変えていたら、その名前を使います。`pg_trgm` は drop しません。`normalize_public_food_name` のように元からある関数は drop しません。

```sql
drop function if exists public.search_official_foods(text, integer);
drop function if exists public.normalize_food_search_text(text);
drop table if exists public.official_food_aliases;
drop table if exists public.official_foods;
```

`drop function` が依存関係で失敗したら止めます。依存を手で消して広げません。所要は 10 秒未満です。

確認は `to_regclass('public.official_foods')` が null であること、そして手順 3 と同じスナップショットを取り、手順 7 のベースラインとユーザテーブルの署名・件数が一致することです。公式食品テーブルが両方に無い状態で比べます。

### 9.3 プロジェクト復元（最終手段）

ダッシュボードの Backups から、手順 2 で控えた復元ポイントへ戻します。PITR ならその時刻です。プロジェクトは復元中に使えません。所要時間はデータベースサイズに比例します。Realtime 以外のレプリケーションスロットがある場合は、Supabase の説明に従い復元の前後で扱いを確認します。この文書の手順としては、9.1 と 9.2 で足りる限り使いません。

## 10. フラグを戻す

フラグをオンにしたあとに不具合があったときは、先にフラグ false のビルドへ戻します。データベースの削除は、オンのビルドが公式食品を読まなくなってから 9.1 または 9.2 を行います。逆にすると、オンのアプリが空結果やエラーを出します。実装がオフライン時に空で落ちないとしても、オンのままテーブルを消す順序にはしません。
