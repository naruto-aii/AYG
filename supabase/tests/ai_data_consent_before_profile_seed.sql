-- 20261010213000 を流す前の既存アカウント。ランナーがマイグレーションの前に流す。
-- 本番には繋がない。

insert into auth.users (id, email)
values ('11111111-1111-4111-8111-111111111111', 'legacy@example.test');

insert into public.users (id, email)
values ('11111111-1111-4111-8111-111111111111', 'legacy@example.test');

insert into public.ai_data_consents (user_id, policy_version)
values ('11111111-1111-4111-8111-111111111111', '2026-10-08');
