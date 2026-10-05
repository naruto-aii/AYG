-- 本番 Supabase（vdzzusqisymtejcjnikb）で適用済みの
-- drop_insecure_backup_user_input_tables と同じ削除。
-- この5表は RLS が無効のまま authenticated に
-- SELECT / INSERT / UPDATE / DELETE があった。中身は 0 件。
-- アプリは表名を参照していない。DROP IF EXISTS なので再実行できる。
--
-- official_foods_label_backup_20260929 と
-- official_food_aliases_backup_20260929 は残す。
-- 20260929180000 がラベル更新の巻き戻し用に作り、RLS は有効、
-- public / anon / authenticated の権限は剥奪済み。
-- それらを落とすのは公式食品の down だけ。

begin;

drop table if exists public.backup_user_input_20260930_meal_template_items cascade;
drop table if exists public.backup_user_input_20260930_meal_templates cascade;
drop table if exists public.backup_user_input_20260930_saved_foods cascade;
drop table if exists public.backup_user_input_20260930_weight_entries cascade;
drop table if exists public.backup_user_input_20260930_food_entries cascade;

commit;
