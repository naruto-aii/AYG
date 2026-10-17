-- 本番には流さない。同じ email の退会していない利用者が2人いると、付与を中止する。
-- このファイルは失敗して終わる。呼び出し側が、付与表が3件のままであることを見る。

insert into public.users (id, email, deleted_at) values
  ('00000000-0000-4000-8000-000000000008', 'fixture-google-two@example.test', null);

insert into auth.identities (user_id, provider, provider_id) values
  ('00000000-0000-4000-8000-000000000008', 'google', 'fixture-google-ambiguous');

\ir ../manual/complimentary_plus_president_grants.sql
