-- 20261003180000 で足したユーザー名の写しだけを消す。
-- profiles.display_name の列と、そこに入っている名前は残す。
-- 食事、体重、運動、目標、ヘルスケア、購入状態、検索語、画面操作の行は消さない。
-- 2回実行しても失敗しない。先にアプリを止める必要はない。この表をアプリは直接読まない。
-- このファイルをこのエージェントから本番へは適用しない。

begin;

drop trigger if exists sync_account_display_name on public.profiles;
drop trigger if exists set_account_display_names_updated_at
  on public.account_display_names;

drop table if exists public.account_display_names;

drop function if exists internal.sync_account_display_name();

comment on column public.profiles.display_name is
  '利用者が登録したユーザー名。連携から名前が取れない、または未入力のときは NULL。';

comment on column public.profiles.gender is null;
comment on column public.profiles.birth_date is null;
comment on column public.profiles.height_cm is null;
comment on column public.profiles.weight_kg is null;

comment on table public.health_snapshots is null;

comment on table public.calonavi_plus_entitlements is
  'カロナビ+の購入状態。商品ID、期限、状態だけを残し、後から有効人数を集計する。レシート本文とトークンは置かない。広告には使わない。';

comment on table public.food_search_queries is
  '食品を探すために、今の検索が受け取った語。公式食品、公開食品、マイ食品、食事テンプレート。ヘルスケアの測定値は入れない。広告には使わない。';

comment on table public.exercise_search_queries is
  '運動種目を探すために、今の検索が受け取った語。種目カタログと運動テンプレート。HealthKit の測定値や消費カロリーは入れない。広告には使わない。';

comment on table public.app_screen_actions is
  '今の画面操作。タブの表示と選択、初回の食事案内、ホームウィジェットとロック画面のボタン。画面名と操作だけ。体重、消費カロリー、ヘルスケアの数値は入れない。広告には使わない。';

commit;
