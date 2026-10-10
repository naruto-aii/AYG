-- 20261010045607_reject_banned_public_food_text を戻す。
-- 公開食品の禁止語チェックが無くなる。既存の行は変えない。本番では手で流す。

drop trigger if exists reject_banned_public_food_text on public.saved_foods;

drop function if exists moderation.reject_banned_public_food_text();
drop function if exists moderation.text_is_banned(text);
drop function if exists moderation.term_uses_substring(text);
drop function if exists moderation.strip_phrase(text, text);
drop function if exists moderation.contains_term(text, text);
drop function if exists moderation.char_is_word(text);
drop function if exists moderation.normalize_food_text(text);
drop function if exists moderation.compose_halfwidth_voiced(text);

drop schema if exists moderation;
