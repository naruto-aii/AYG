-- 利用者が登録するユーザー名。
-- サインイン連携が名前を返さなかった、または未入力のときは NULL。
-- gender はこの列とは別で、消費カロリー計算に使い続ける。

alter table public.profiles
  add column if not exists display_name text;

comment on column public.profiles.display_name is
  '利用者が登録したユーザー名。連携から名前が取れない、または未入力のときは NULL。';
