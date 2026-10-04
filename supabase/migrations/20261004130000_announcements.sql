-- 運営のお知らせ。
-- タイトル、本文、公開日時を1行 insert すればアプリに出る。アプリの更新は不要。
-- ログインした利用者は、公開日時を過ぎた行だけ読める。
-- 書き込みは service role だけ。anon と authenticated には書かせない。

begin;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  published_at timestamptz not null
);

comment on table public.announcements is
  '運営のお知らせ。title、body、published_at を1行入れると、公開日時以降にアプリへ出る。';
comment on column public.announcements.title is
  'お知らせの見出し。';
comment on column public.announcements.body is
  'お知らせの本文。';
comment on column public.announcements.published_at is
  'この時刻以降を公開済みとする。未来の行はログイン利用者からも読めない。';

create index if not exists announcements_published_at_idx
  on public.announcements (published_at desc);

alter table public.announcements enable row level security;

drop policy if exists announcements_select_published on public.announcements;
create policy announcements_select_published
  on public.announcements
  for select
  to authenticated
  using (published_at <= now());

revoke all on table public.announcements from public, anon, authenticated;
grant select on table public.announcements to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select, insert, update, delete on table public.announcements
      to service_role;
  end if;
end
$$;

commit;
