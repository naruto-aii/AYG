# ロールバック

新しいものほど上に書く。本番への適用は手動。このエージェントは本番 DB に接続しない。

## 20261006130000 app screen action share

共有の操作（share_meal / share_streak / share_weight）だけを戻す。画面操作の表は残す。食事、運動、体重の行は消さない。2回実行しても失敗しない。

`supabase/rollback/20261006130000_app_screen_action_share_down.sql`

消えるもの:

- `app_screen_actions` のうち、共有の操作の行だけ

## 20261004150000 coach proposal logs

今日のコーチが出した提案の記録だけを戻す。食事、運動、公式食品、お知らせ、候補食品は消さない。2回実行しても失敗しない。

`supabase/rollback/20261004150000_coach_proposal_logs_down.sql`

消えるもの:

- `coach_proposal_logs`（提案内容、登録したか、日時）

## 20261004140000 food entry memo

食事メモの列だけを戻す。食事、運動、公式食品の行は消さない。2回実行しても失敗しない。

`supabase/rollback/20261004140000_food_entry_memo_down.sql`

消えるもの:

- `food_entries.memo`（その食事へのメモ）

## 20261004130000 announcements

お知らせ表だけを戻す。食事、運動、公式食品、コーチの候補は消さない。2回実行しても失敗しない。

`supabase/rollback/20261004130000_announcements_down.sql`

消えるもの:

- `announcements`（タイトル、本文、公開日時）

## 20261004120000 coach food candidates

今日のコーチの候補表だけを戻す。official_foods の数値、食事、運動、体重は消さない。2回実行しても失敗しない。

`supabase/rollback/20261004120000_coach_food_candidates_down.sql`

消えるもの:

- `coach_food_candidates`（画面の名前と提案単位）

## 20261003210000 lifestyle calculation source

運動の `calculation_source` に足した `lifestyle_included` だけを、元の3値へ戻す。列は消さない。食事、体重、運動、目標、ヘルスケアの行は消さない。`lifestyle_included` の行が残っているときは、その行を消さずに失敗する。行が無ければ2回実行しても失敗しない。先にアプリを、生活活動をこの値で書かない版へ戻してから流す。

`supabase/rollback/20261003210000_allow_lifestyle_included_calculation_source_down.sql`

消えるもの:

- なし（許可値の縮小だけ。列も行も残る）

## 20261003200000 apple token revoke on delete

Apple の失効用トークン表と、service_role 専用の `delete_own_account(uuid)` だけを戻す。食事、体重、運動、目標、ヘルスケア、プロフィール、購入状態、検索語、画面操作、公開食品の行は消さない。トークン行だけが失われる。`delete_own_account()` は、ログイン中の本人が引数なしで呼べる本体へ戻る。2回実行しても失敗しない。先にアプリを、削除 Function を呼ばない版へ戻してから流す。

`supabase/rollback/20261003200000_apple_token_revoke_on_delete_down.sql`

消えるもの:

- `internal.apple_refresh_tokens`（Sign in with Apple のリフレッシュトークン）
- `store_apple_refresh_token` / `read_apple_refresh_token` / `delete_apple_refresh_token`

## 20261003190000 app numeric records

Health ワークアウトの表と、食事の保存食品バージョン列だけを戻す。食事の行、体重、自分で記録した運動、目標、ヘルスケアのスナップショット、プロフィール、購入状態、検索語、画面操作は消さない。2回実行しても失敗しない。先にアプリを、この表と列を書かない版へ戻してから流す。

`supabase/rollback/20261003190000_app_numeric_records_down.sql`

消えるもの:

- `health_workouts`（種目、開始、終了、消費カロリー）
- `food_entries.source_saved_food_version`（保存食品の版番号）

`delete_own_account` は、ワークアウト表を消す前の本体へ戻る。

## 20261003180000 account display names

ユーザー名の写しだけを消す。`profiles.display_name` の列と、そこに入っている名前は残す。食事、体重、運動、目標、ヘルスケア、購入状態、検索語、画面操作の行は消さない。2回実行しても失敗しない。

`supabase/rollback/20261003180000_account_display_names_down.sql`

消えるもの:

- `account_display_names`（登録済みユーザー名の写し）
- `internal.sync_account_display_name`（プロフィールから名前だけを写す関数）

`profiles` の名前、性別、生年月日、身長、体重は残る。性別は健康情報であり機微な情報でもあるが、この写しには入っていない。

## 20261003160000 device usage tables

新しい4表だけを消す。食事、体重、運動、目標、ヘルスケアの行は消さない。2回実行しても失敗しない。先にアプリを、この表へ書かない版へ戻してから流す。

`supabase/rollback/20261003160000_device_usage_tables_down.sql`

消える表:

- `calonavi_plus_entitlements`（カロナビ+の商品ID、期限、状態）
- `food_search_queries`（食品の検索語）
- `exercise_search_queries`（運動種目の検索語）
- `app_screen_actions`（画面の操作）

適用後にこれらの表へ書いた行は、このダウンで失われる。それ以外の表は残る。`delete_own_account` は、この4表を消す前の本体へ戻る。

## 20260930120000 daily calorie target

列を足しただけです。行は消しません。2回実行しても失敗しません。先にアプリを、この列を読まない版へ戻してから流します。

`supabase/rollback/20260930120000_daily_calorie_target_down.sql`

消える列:

- `nutrition_settings.calorie_target_mode`
- `nutrition_settings.manual_target_kcal`
- `nutrition_settings.manual_protein_g`
- `nutrition_settings.manual_fat_g`
- `nutrition_settings.manual_carb_g`
- `nutrition_settings.auto_food_target_kcal`
- `nutrition_settings.auto_food_target_on`
- `nutrition_settings.auto_food_target_prior_kcal`
- `health_snapshots.weight_measured_at`

手入力のカロリーと PFC、自動計算の前日目標、Health の測定時刻は、このダウンで失われます。食事記録、体重の行、目標体重、目標日は残ります。

成分表の2つのダウンは、それぞれ `begin` から `commit` までの1トランザクションです。文を分けて流しません。途中で失敗すると、そのファイルの変更は全部戻ります。

戻す順は出典ダウンを先に確定し、その次に公式食品ダウンです。公式食品ダウン（`20260928120000`）を先に流すと、公開中の成分表コピーが無い場合は以前は成功していました。`official_foods` だけが消え、`enforce_mext_food_entry_code` が残ります。その関数は食事記録の登録のたびに消えた表を参照するため、手入力を含む `food_entries` の登録がすべて失敗します。今は公式食品ダウンの先頭で、出典ダウンが作ったトリガー、関数、列が残っていれば止まり、先に `supabase/rollback/20260928140000_official_food_provenance_down.sql` を流すよう伝えます。その失敗は1トランザクションなので表は消えません。直し方は、出典ダウンを流してから公式食品ダウンを流し直すことです。

2つを続けて1つのトランザクションにまとめるときは、各ファイルの `begin` と `commit` を外し、外側で1回だけ `begin` / `commit` します。ファイル自身の `commit` を残すと、そこで確定してトランザクションが分かれます。

## 20260928140000 official food provenance

先にこちらを戻す。2回実行しても失敗しません。列やトリガーが既に無いときは、その drop は何もしません。

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

スキーマを戻す。出典ダウンのあとなら、2回実行しても失敗しません。出典ダウンより先に流すと、先頭で止まります。止まっているあいだに食事記録が登録できない状態にはしません。先に `20260928140000_official_food_provenance_down.sql` を流してください。

`supabase/rollback/20260928120000_official_foods_down.sql`

消えるもの: `search_official_foods`、`normalize_food_search_text`、`official_food_aliases`、`official_foods`。`pg_trgm` 拡張は残す。`saved_foods.source_type = 'mext_sfct'` の行は削除せず `copied` に戻してから、元の check 制約を付け直す。この更新は postgres、service_role、または `saved_foods` の所有者で実行する。出典ロックはセッション変数では外れない。

データだけ戻す（テーブルは残す）:

```sql
delete from public.official_foods
where source = 'mext_sfct'
  and edition = '八訂増補2023';
```

別名は `official_foods` への `on delete cascade` で一緒に消える。
