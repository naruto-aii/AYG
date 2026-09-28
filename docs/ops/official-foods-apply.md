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
2. そのコミットのマイグレーションを開く。スナップショットは両方の前です。適用順はファイル名の時刻どおり、先に `supabase/migrations/20260928120000_official_foods.sql`、そのあと `supabase/migrations/20260928140000_official_food_provenance.sql` です。ファイル名が違えばチケットに実際のパスを書く。
3. 次を目で確認する。どれか違えば本番に流す前に CONFIG を直し、差をチケットに残す。
   - 新テーブルは `public.official_foods` と `public.official_food_aliases` だけか。既存テーブル（とくに `saved_foods`）への `ALTER` があるか。
   - `auth.` を触っていないか。触っているならこの手順を止める。
   - 検索関数は security definer で stable、`search_path` は空か。正規化関数は immutable で `search_path` を空にし、入力を 256 文字で切るか。`anon` と `authenticated` に正規化関数の EXECUTE は無いか。検索関数だけが正規化関数を呼ぶ。
   - `enforce_mext_saved_food_attribution` と `enforce_mext_food_entry_code` は security invoker で、`public`、`anon`、`authenticated` に EXECUTE は無いか。行の書き込みは表の所有者としてトリガーを起動するので、直接の EXECUTE は要らない。
   - アプリのマイ食品保存は PostgREST の upsert か。`POST` に `Prefer: resolution=merge-duplicates` と `on_conflict=user_id,food_id` を付け、SQL は `INSERT ... ON CONFLICT (user_id, food_id) DO UPDATE` になる。同じ利用者の行が既にあり、`copied_from` とその所有者が変わっていなければ、INSERT 側の参照確認を飛ばす。見る行は `auth.uid()` の行だけか。
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

1. `list_migrations`（引数 `project_id`）。`20260928120000` または `20260928140000` が既にあれば止めて、下記「7. 受け入れ」に進むか、適用済みとして扱うかをチケットで決める。同じ DDL を重ねない。
2. 公式食品はこの2ファイルだけで適用できます。#25〜#29 は前提ではありません。機能 PR は web-preview にこの2ファイルを足しただけで、公式食品 SQL は #25〜#29 のオブジェクトを参照しません。
   - #29 を入れるなら `fca01f1` 以降です。対象ファイルは `20260927150000_protect_owner_deleted_and_revoke_sessions.sql` です。テーブル権限の REVOKE のあと、列が既にあるときは `official_food_code`、`official_food_name`、`source_attribution` を `authenticated` へ付け直します。それより前の #29 は使いません。
   - 順はどちらでもよいです。公式食品（`20260928120000` のあと `20260928140000`）の次に #29 でも、#29 の次に公式食品でも適用できます。#29 が先のとき、付け直しは列がまだ無いのでスキップされ、公式食品側の GRANT が権限を付けます。公式食品が先のとき、#29 の REVOKE が列権限を落としたあと、同じファイルの付け直しが戻します。機能 PR の CI は `sql-with-pr29`（#29 のあと #31）と `sql-pr31-then-pr29`（#31 のあと #29）です。この PR の CI にも `accept-with-pr29` があり、#31 の `5eab90b` の公式食品のあと #29 を `fca01f1` にピンして流し、`authenticated` のマイ食品書き込みを見ます。本番の前に、入れる #29 のコミットが `fca01f1` 以降であることをチケットに書きます。
3. `20260928120000_official_foods.sql` の中身を、編集せず `apply_migration` の `query` に貼る。
   - `name`: `official_foods_20260928120000`（snake_case。どのファイルを入れたか履歴の name から追える文字列。空白は入れない）
   - `project_id`: 手順 1 の id
4. そのあと `20260928140000_official_food_provenance.sql` を、編集せず `apply_migration` に貼る。120000 より前には入れません。
   - `name`: `official_food_provenance_20260928140000`
   - `project_id`: 手順 1 の id
5. MCP の `apply_migration` が履歴に書く version は、適用時刻の採番です。リポジトリのファイル名 `20260928120000` と `20260928140000` とは一致しません。適用後の `list_migrations` の version と name をチケットに書き、同じファイルを Supabase CLI の `db push` で重ねません。CLI はどちらの version も未適用とみなします。
6. ツールが確認を求めたら、貼った SQL が手順 0 で読んだファイルと同一であることだけを確認してから承認する。
7. もう一度 `list_migrations` を呼び、手順 3 と 4 の name が両方増えていることを見る。

依存する関数（例: 既存の `normalize_public_food_name`）が本番に無くて失敗したら、公式食品用の SQL をその場で書き換えない。依存元の適用を別の変更として止めて判断します。`normalize_public_food_name` 自体はロールバックで drop しません。

## 6. データを入れる

INSERT 文を手で組み立てない。食品名の引用符を手でエスケープしない。`import.py` は本番の URL を拒否するローカルと CI 用です。本番の `execute_sql` には使いません。

機能 PR の生成スクリプトは `tool/official_foods/export_sql.py` です。データベースには接続せず、URL も受け取りません。ピンしたコミットにこのファイルが無いときは、ここで止めます。手書きの INSERT には戻しません。

1. ローカル（本番 URL ではないマシン）で、機能 PR の `convert.py` に手順 0 の xlsx と正誤表を渡して CSV を作ります。sha256 が手順 0 と違うファイルは使いません。
2. 同じコミットで次を実行する。

```bash
python3 tool/official_foods/export_sql.py \
  --foods official_foods.csv \
  --aliases supabase/seed/official_food_aliases.csv \
  --out-dir sql-batches \
  --batch-size 200
```

3. 出力は `01_official_foods_0001.sql` のあと `02_official_food_aliases_0001.sql` の順で、ファイル名のソート順に実行できます。各ファイルは `begin` から `commit` までです。中身は `INSERT ... ON CONFLICT DO UPDATE` です。文字列は SQL リテラル（`'` は二重）です。`COPY FROM`、サーバ上のファイル読み取り、動的 SQL の連結は含めません。先頭のコメントは「手で編集しない」です。
4. バッチを開いて、食品が別名より先であること、1 ファイルがおおよそ 200 行であること、引用符が二重化されていることだけを見ます。値は直しません。おかしいファイルは捨て、スクリプト側を直してから作り直します。
5. ソート順に、各ファイルの全文を `execute_sql` の `query` に貼ります。食品が全部終わってから別名です。別名は食品番号への外部キーがあります。各ファイルは `begin` から `commit` までです。`apply_migration` や SQL エディタでこの形のファイルを流すときの、公式ドキュメントで確認できた注意は 9.2 にあります。
6. ツールがペイロードを拒否したら、`--batch-size 50` で作り直して、最初から流します。途中まで入った食品は `ON CONFLICT` で上書きされるので、作り直した食品バッチを重ねて構いません。
7. 先頭の食品バッチだけもう一度流し、エラーにならないことを見ます。食品バッチ全体の 2 周目は任意です。件数が 2,538 のままなら冪等です。受け入れの件数チェックが本線です。
8. 列は生成スクリプトが `import.py` と同じ公式食品の列に書きます。受け入れ CONFIG の `food_code` / `name` / `kcal` / `source` / `edition` と一致していることを、バッチの INSERT 列で見ます。

投入後に `01088` の kcal が 156、名前がワークブックの全角スペース区切り（U+3000）のままであることは、受け入れ SQL が検証します。ここで手作業の SELECT を足す必要はありません。

`execute_sql` は DML として確認を求めることがあります。確認するのは、レビュー済みのそのバッチファイルだけです。

## 7. 受け入れ

1. `accept_official_foods.sql` をローカルで複製する。リポジトリのファイルは `v_baseline jsonb := null` のままにする。
2. 複製の CONFIG で、`v_baseline jsonb := null` を手順 3 の jsonb に差し替える。ドル引用符の例はファイル先頭に書いてあります。スナップショットの中に区切り文字 `$of_baseline$` が無いことを見てから貼ります。
3. 機能 PR で名前が違っていれば、同じ CONFIG の識別子だけ直す。`v_search_limit` と `v_search_limit_cap` は 30 のままです。
4. `v_ignore_signature_for` は空にしない。必須です。外すと受け入れは既存テーブルの署名変化で FAIL します。いまの必須の中身は `saved_foods` と `food_entries` です。`20260928120000` は `saved_foods_source_type_check` を作り直して `mext_sfct` を足します。`20260928140000` は `saved_foods` に `official_food_code`、`official_food_name`、`source_attribution` を足し、`food_entries` に `official_food_code`、`official_food_name` と `source_type` の `mext_sfct` を足します。同じファイルが、その3列の INSERT と UPDATE を `authenticated` に列単位で付与します。件数の一致は免除しません。この2つを `v_exclude_tables` に入れてはいけません。`v_exclude_routines` には `normalize_food_search_text`、`search_official_foods`、`enforce_mext_saved_food_attribution`、`enforce_mext_food_entry_code` を入れます。テーブル名や列名が機能 PR と違うときだけ、CONFIG の識別子を直します。`v_search_input_cap` は 64、`v_norm_input_cap` は 256 のままです。`v_require_search_input_cap` と `v_require_published_attribution` は true のままです。出典の値は全文 `出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成` です。受け入れは、正規化関数を `anon` と `authenticated` が実行できないこと、`enforce_mext_saved_food_attribution` と `enforce_mext_food_entry_code` を `anon` と `authenticated` が直接実行できないこと、`set_config` のあとでも `authenticated` が出典ロックを外せないこと、公開された成分表食品の直接コピーが出典を引き継ぐこと、出典の無いコピーの公開が失敗すること、`copied_from` を普通の食品へ向けて食品番号だけ載せた行は出典なしでは公開できないこと、コピー元が非公開になったあとも自分の行を編集できること、`copied_from_owner_user_id` が NULL の参照は拒否されることを見ます。あわせて `authenticated` の `INSERT ... ON CONFLICT (user_id, food_id) DO UPDATE` で、コピー元が非公開になったコピーと、コピー元が削除されたコピーを編集できること、所有者が NULL の既存行を編集できること、出典を外せないこと、`copied_from` を他人の非公開行へ変えると失敗することを見ます。CI は、そのあと 120000 の down を先に流して止まることと、表とトリガーが残って手入力の食事記録が登録できることも見ます。
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
4. オンにするビルドの画面文言は、機能 PR の `OfficialFoodCopy` に合わせます。検索結果と食品詳細に出す出典は全文 `出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成` です。1行に収まらないときだけ `OfficialFoodAttributionLine` が短い文 `出典：八訂成分表 増補2023年（文部科学省）を加工して作成` を使います。短い文は幅が取れないときの表示で、データベースに書く文ではありません。
   - 設定の出典画面には、文部科学省サイトへのリンク（外部ブラウザ。`文部科学省ウェブサイトへ移動します`）と、1 食分・別名・よみは当社の換算であり文部科学省の保証ではないこと、表示値は目安であることを書く。
   - 課金画面は web-preview にまだありません。画面を足すときは同じ出典を置きます。全文が既定で、1行に収まらないときだけ短い文です。フラグをオンにする条件は、手順 7 の PASS と社長承認です。
   - データベース側は、受け入れ SQL が公開された `mext_sfct` のマイ食品に全文出典を付け、`official_food_code` と `official_food_name` と `source_type` を外せずに残すことを見ます。画面の短い文は SQL では見ません。
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

この DELETE が消すのは `official_foods` の行だけです。別名は cascade で消えます。`saved_foods` と食事記録（`food_entries`）へ写した利用者の行は残ります。`source_type = mext_sfct` の私的コピーも、公開したマイ食品も、成分表の行が無くなったあとも残ります。利用者データの削除ではありません。

行は残りますが、出典トリガーと食事記録の食品番号トリガーは残ったまま、`official_food_code` が `official_foods` にあることを要求します。この DELETE のあと、成分表由来のマイ食品は編集も公開もできなくなります。成分表由来の食事記録（`food_entries.source_type = 'mext_sfct'`）は登録できなくなります。失敗時のメッセージは `mext_sfct official_food_code must exist in official_foods` です。食品行を戻すか、9.2 で出典側を戻すまで、その書き込みは失敗します。`mext_sfct` でない食事記録の登録は、この DELETE だけでは止まりません。

### 9.2 オブジェクトを drop する

機能 PR の `supabase/rollback/README.md` と同じです。各 down ファイルは先頭の `begin` から末尾の `commit` までが1トランザクションです。ファイルの中の文を分けて流しません。途中で失敗すると、そのファイルの変更は全部戻ります。下の代替 DROP は、両方の down ファイルがピンしたコミットにあるあいだ使いません。

実行ロールは postgres、`service_role`、または `saved_foods` の所有者です。出典トリガーが残っているあいだ、`saved_foods.source_type` を書き換えられるのはそのロールだけです。

実行前に、公開中の成分表由来マイ食品の `user_id` と `food_id` をチケットに書きます。対象は `visibility = 'public'` で、自身が `source_type = 'mext_sfct'` か、`official_food_code` または `source_attribution` を持つか、`copied_from` をたどるとそうなる行です。

`dbb075b` 以降、120000 の down は先に流しても止まります。先頭で、140000 が作ったトリガー、関数、列（`saved_foods` の `official_food_code` / `official_food_name` / `source_attribution`、`food_entries` の `official_food_code` / `official_food_name`）が残っていれば、表を drop する前に例外で終わります。メッセージは `20260928140000` の down を先に流すよう伝えます。ファイルは1トランザクションなので、この失敗では `official_foods` は消えません。食事記録の登録も止まりません。止まったあとにすることは、140000 の down を流し、下の確認 SQL が期待どおりになってから、120000 の down を流し直すことです。

ガードが無い古い版で、120000 の down を先に commit して中途半端に戻ってしまった状態は、今のファイルでは新しく作れません。すでにその状態なら、復旧は 140000 の down を1回流すことです。その状態では `official_foods` と別名、検索関数は無く、`enforce_mext_saved_food_attribution` と `enforce_mext_food_entry_code` は残ります。食事記録の登録は、手入力を含めてすべて失敗します。残ったトリガーが消えた表を参照し、`relation "public.official_foods" does not exist` になります。120000 の down をもう一度流しても直りません。表は既に無いので、公式食品を入れ直してから戻す必要もありません。140000 の down が残っているトリガーと関数を drop し、列が残っているあいだは成分表由来の公開行を `private` にします。行は消しません。

本番の down は、必ずファイル単位で流します。`apply_migration` が使う `POST /v1/projects/{ref}/database/migrations` は、失敗すると変更をロールバックすると公式に書いてあります（[Supabase for Platforms](https://supabase.com/docs/guides/integrations/supabase-for-platforms) の “Make database changes”。処理時間は 3 分まで。[Management API](https://supabase.com/docs/reference/api/introduction)）。クエリ自身の `begin` / `commit` が、そのロールバックとどう重なるかは公式に書いてありません。PostgreSQL 17 では、すでにトランザクションの中の `BEGIN` は警告だけで状態は変わらず、`COMMIT` は現在のトランザクションを確定します（[BEGIN](https://www.postgresql.org/docs/17/sql-begin.html)、[COMMIT](https://www.postgresql.org/docs/17/sql-commit.html)）。重なりが公式に無いので、本番では2ファイルを1つの `query` にまとめません。`begin` / `commit` を外して外側で包む手順も使いません。SQL エディタも同じで、1回の実行にファイルを1つです。SQL エディタは 1 分で切れ、Dashboard はセッションを維持しません（[Avoiding timeouts](https://supabase.com/docs/guides/troubleshooting/avoiding-timeouts-in-long-running-queries-6nmbdN)、[PGAudit](https://supabase.com/docs/guides/database/extensions/pgaudit)）。1分を超える実行には使いません。

1つのファイルを流したら、次のファイルの前に、必ずその段の確認 SQL を `execute_sql` で実行します。期待と違う行が返ったら、次のファイルは流しません。

1. `apply_migration` を1回。`query` は `supabase/rollback/20260928140000_official_food_provenance_down.sql` の全文です。`begin` と `commit` は残します。足しません。外しません。
   - `name`: `rollback_official_food_provenance_20260928140000`
   - このファイルは、`source_attribution` 列があるときだけ、列を drop する前に上の公開行を `private` にします。行は消さない。トリガーを drop したあと、関数が残っていれば `public`、`anon`、`authenticated` から EXECUTE を外してから関数を drop します。この REVOKE はファイルの中にあり、別の文としては流しません。そのあと `saved_foods` の `source_attribution`、`official_food_name`、`official_food_code` を `IF EXISTS` で消します。`saved_foods.source_type` はここでは変えません。`food_entries.source_type = 'mext_sfct'` は削除せず `manual` にし、食品番号の列を消し、`source_type` check から `mext_sfct` を外します。非公開化だけを抜いて、列の drop を先に実行してはいけません。
   - この呼び出しが戻ってから、次を実行します。`official_foods` はまだあり、関数2つは null、出典列は 0、公開の `mext_sfct` は 0 です。`ticket-food-id` は、実行前にチケットへ書いた `food_id` に置き換えます。置き換えずに 0 件でも、確認したことにはしません。

```sql
select
  to_regclass('public.official_foods') as official_foods,
  to_regprocedure('public.enforce_mext_saved_food_attribution()') as saved_food_fn,
  to_regprocedure('public.enforce_mext_food_entry_code()') as food_entry_fn;
```

```sql
select count(*) as provenance_columns
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'saved_foods' and column_name in ('official_food_code', 'official_food_name', 'source_attribution'))
    or (table_name = 'food_entries' and column_name in ('official_food_code', 'official_food_name'))
  );
```

```sql
select count(*) as public_mext_sfct
from public.saved_foods
where visibility = 'public'
  and source_type = 'mext_sfct';
```

```sql
select user_id, food_id, visibility, source_type
from public.saved_foods
where food_id = any (array['ticket-food-id']::text[]);
```

2. その確認のあと、別の `apply_migration`。`query` は `supabase/rollback/20260928120000_official_foods_down.sql` の全文です。こちらもファイルの `begin` と `commit` のままです。手順 1 の確認が終わる前には流しません。
   - `name`: `rollback_official_foods_20260928120000`
   - 関数2つとテーブル2つを drop します。`pg_trgm` は残します。`saved_foods.source_type = 'mext_sfct'` の行は削除せず `copied` にします。対象だった公開行は手順 1 で `private` です。`saved_foods_source_type_check` は `mext_sfct` の無い4値（`manual` / `open_food_facts` / `open_food_facts_derived` / `copied`）に戻します。`copied_from` だけが成分表由来だった行の `source_type` は `copied` のままです。
   - この呼び出しが戻ってから、次を実行します。`official_foods` は null、`mext_sfct` は 0、`pg_trgm` は 1 行、チケットの `food_id` は `public` ではありません。

```sql
select
  to_regclass('public.official_foods') as official_foods,
  to_regclass('public.official_food_aliases') as aliases;
```

```sql
select count(*) as mext_sfct_rows
from public.saved_foods
where source_type = 'mext_sfct';
```

```sql
select extname from pg_extension where extname = 'pg_trgm';
```

```sql
select user_id, food_id, visibility, source_type
from public.saved_foods
where food_id = any (array['ticket-food-id']::text[]);
```

120000 の down を先に流してガードで止まったとき（`dbb075b` 以降）は、次が両方とも null でないことを確認してから手順 1 に戻ります。`official_foods` が null で `food_entry_fn` が null でないなら、ガードの無い古い版の中途半端な状態です。そのときは 140000 の down だけを流し、手順 1 の確認で関数が null になることを見ます。`official_foods` は null のままです。

```sql
select
  to_regclass('public.official_foods') as official_foods,
  to_regprocedure('public.enforce_mext_saved_food_attribution()') as saved_food_fn,
  to_regprocedure('public.enforce_mext_food_entry_code()') as food_entry_fn;
```

どちらの down も、成功したあとに同じファイルをもう一度実行できます。受け入れ CI は、公開の成分表由来行を入れてから 120000 の down を先に流し、止まること（`official_foods` とトリガーが残り、手入力の食事記録が登録できること）を見ます。そのあと provenance down を2回、続けて official foods down を2回実行し、2回目も失敗せず、公開の成分表由来行が残らないことを見ています。provenance の2回目は列が無いので非公開化をスキップし、drop は `IF EXISTS` です。利用者の行を消さないのは、非公開化と `source_type` の書き換えが行の削除ではないからです。実行前に、`food_entries` の `mext_sfct` が `manual` になり、公開中の成分表由来マイ食品が `private` になってから `saved_foods` の `mext_sfct` が `copied` になることをチケットに書きます。

両方の down ファイルがピンしたコミットに無いときだけ、次の順序を使います。CONFIG で名前を変えていたら、その名前を使います。`pg_trgm` は drop しません。`normalize_public_food_name` のように元からある関数は drop しません。この DROP は出典トリガーも、`saved_foods` と `food_entries` の CHECK も、出典列も戻しません。利用者の `mext_sfct` 行も `copied` や `manual` に変わりません。down ファイルがあるなら、こちらを使ってはいけません。

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
