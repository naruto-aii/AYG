-- 20261010045607_reject_banned_public_food_text を戻す。
-- 公開食品の禁止語チェックが無くなる。既存の行は変えない。本番では手で流す。
-- 必須の順序: 20261010143000 を適用しているときは、先に
-- supabase/rollback/20261010143000_order_banned_public_food_trigger_down.sql
-- を流してから、このファイルを流す。
-- 先にこのファイルを流すと関数が消え、上の down がトリガーを作れずに失敗する。

drop trigger if exists reject_banned_public_food_text on public.saved_foods;
drop trigger if exists saved_foods_reject_banned_public_text on public.saved_foods;

drop function if exists moderation.reject_banned_public_food_text();
drop function if exists moderation.text_is_banned(text);
drop function if exists moderation.term_is_affixed(text, text);
drop function if exists moderation.latin_one_gap(text, text);
drop function if exists moderation.term_uses_substring(text);
drop function if exists moderation.strip_phrase(text, text);
drop function if exists moderation.contains_term(text, text);
drop function if exists moderation.char_is_word(text);
drop function if exists moderation.normalize_food_text(text);
drop function if exists moderation.compose_halfwidth_voiced(text);

drop schema if exists moderation;
