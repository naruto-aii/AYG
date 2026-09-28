# 公式食品の受け入れ確認

機能 PR とは別の、適用後にどの環境でも走らせるブラックボックス確認です。本番へは適用しません。マイグレーションもデータを入れません。

| ファイル | いつ |
| --- | --- |
| `snapshot_user_tables.sql` | マイグレーションの前。既存の public オブジェクトの件数と署名 |
| `accept_official_foods.sql` | データ投入の後。件数、エネルギー、検索、RLS、既存テーブルが変わっていないこと |

手順、所要時間、ロールバックは `docs/ops/official-foods-apply.md` です。

識別子は PR #31（`a5199d4`）の実名に合わせています。スナップショットのあと `20260928120000_official_foods.sql`、そのあと `20260928140000_official_food_provenance.sql` です。後続で名前が違えば `accept_official_foods.sql` 先頭の CONFIG だけを直します。`v_exclude_tables` と `v_exclude_routines` は、マイグレーションが新しく作ったオブジェクトだけを比較から外します。`enforce_mext_saved_food_attribution` と `enforce_mext_food_entry_code` は `v_exclude_routines` に入っています。スナップショット時点で既にあったテーブルをそこに書いても、変更は隠せません。

`v_ignore_signature_for` は `saved_foods` と `food_entries` が必須です。件数の一致は免除しません。検索入力の上限は 64 文字です。正規化関数は 256 文字で切り、`anon` と `authenticated` は実行できません。検索関数は security definer です。公開した `mext_sfct` のマイ食品には全文出典が付き、`authenticated` は `set_config` のあとでも外せません。公開された成分表食品を直接コピーすると出典が引き継がれ、出典の無いコピーは公開できません。`copied_from` を普通の食品へ向け、食品番号だけを載せた行も、出典なしでは公開できません。コピー元が非公開になったあとも、その写しの持ち主は自分の行を編集できます。`copied_from_owner_user_id` が NULL の参照は拒否されます。参照できるのは自分の行か公開行だけです。列名は CONFIG の `official_food_code` / `official_food_name` / `source_type` / `source_attribution` です。データベースに書く出典は全文 `出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成` です。画面が1行に収まらないときの短い文は SQL では見ません。

CI は `.github/workflows/official-foods-acceptance.yml` です。Postgres 17 で、`a5199d44aaeb53a7aa8fcd70a986ed4a25707daf` のマイグレーションを、公式食品の2ファイルより前でスナップショットしてから、その2ファイルと全 2,538 件を入れて受け入れを流します。そのあと 120000 の down を先に流して止まること、provenance down を2回、official foods down を2回を、ファイル自身の `begin` / `commit` のまま実行し、2回目も通り、成分表由来の公開行が残らないことを見ます。別ジョブ `accept-with-pr29` は、同じコミットの公式食品マイグレーションのあと #29 の `fca01f1` を流し、`authenticated` のマイ食品書き込みを見ます。本番の投入は `tool/official_foods/export_sql.py` のバッチです。そのファイルが機能ブランチに無いあいだ、CI のローカルデータベースだけ `import.py` を使います。

エネルギーと食品名は、2026-09-28 に公式 Excel（表全体、成分識別子 `ENERC_KCAL`、可食部 100 g 当たり）を読んで入れています。

- ワークブック sha256 `0d5a77077dd6cd91cbc2e6e317b8b218a38728c409eed452f1c10635a0d3099c`
- 食品番号 5 桁は 2,538 件
- `01088` こめ［水稲めし］精白米は 156 kcal。`01083` は穀粒で 342 kcal
- `11183` ばらベーコンは 241 kcal（2026-03-27 の正誤で 244 から直った後の値。この xlsx には反映済み）

検索 `ご飯` / `ゴハン` / 半角 `ｺﾞﾊﾝ`（U+FF7A U+FF9E U+FF8A U+FF9D）/ `白米` / `ライス` の先頭は `01088`。`牛丼` は複数件で、`18031`（牛飯の具）と `01088`（精白米めし）を含みます。`v_search_limit` は 30 のままにします。

成功は `status = PASS` の 1 行です。失敗は `ACCEPTANCE FAIL:` で始まります。本番のスナップショットをこのファイルにコミットしません。
