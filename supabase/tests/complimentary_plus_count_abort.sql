-- 本番には流さない。候補が3件でなければ付与を中止する。
-- 先に曖昧な email の利用者を外してから、社長役の1行を対象外にする。
-- このファイルは失敗して終わる。既存の3件は残る。

delete from auth.identities
where user_id = '00000000-0000-4000-8000-000000000008';

delete from public.users
where id = '00000000-0000-4000-8000-000000000008';

update public.kpi_excluded_users
set reason = 'held_president_apple'
where reason = 'president_apple';

\ir ../manual/complimentary_plus_president_grants.sql
