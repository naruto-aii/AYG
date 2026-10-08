-- 20261008003832_search_public_foods_voice を戻す。Siri は公開食品を引けなくなる（公式の成分表と自分の食品は引ける）。
drop function if exists public.search_public_foods_voice(text, integer);
