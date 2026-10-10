-- 同意画面は、public.users を作る初回設定より前に出る。
-- user_id が public.users を向いていると、新規アカウントの
-- POST /rest/v1/ai_data_consents?on_conflict=user_id が
-- ai_data_consents_user_id_fkey で 409 になる。
--
-- public.users の行は先に作らない。
-- 初回設定の完了は app_settings.onboarding_complete であり、users の有無ではない。
-- ただし ensureUserProfile は行が既にあると email を書かない。
-- KPI の除外は public.users.email で結び、退会の経過日数は created_at を使う。
-- 同意の前に空の行を作ると、その両方がずれる。
--
-- 退会は auth.users も public.users も消さない。deleted_at を入れ、
-- delete_ai_data_consent_on_account_close が同意の行を消す。
-- カスケードはこの経路では動かないので、トリガーは残す。
-- auth.users を消したときだけ、ここでの on delete cascade でも消える。
--
-- 列は変えない。アプリの再ビルドは要らない。
-- 本番には適用しない。20261008210000 のあと。20261010200000 よりファイル名は後。
-- 中身は ai_data_consents と auth.users だけを見る。

begin;

do $$
begin
  if to_regclass('public.ai_data_consents') is null then
    raise exception 'public.ai_data_consents が無い。先に 20261008210000 を適用する';
  end if;
  if exists (
    select 1
    from public.ai_data_consents c
    left join auth.users a on a.id = c.user_id
    where a.id is null
  ) then
    raise exception 'ai_data_consents に auth.users に無い user_id がある。参照先は変えない';
  end if;
end
$$;

do $$
declare
  cons name;
begin
  for cons in
    select c.conname
    from pg_constraint c
    join pg_class rel on rel.oid = c.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    join pg_class ref on ref.oid = c.confrelid
    join pg_namespace refn on refn.oid = ref.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'ai_data_consents'
      and c.contype = 'f'
      and refn.nspname = 'public'
      and ref.relname = 'users'
  loop
    execute format(
      'alter table public.ai_data_consents drop constraint %I',
      cons
    );
  end loop;
end
$$;

alter table public.ai_data_consents
  drop constraint if exists ai_data_consents_user_id_fkey;

alter table public.ai_data_consents
  add constraint ai_data_consents_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;

comment on table public.ai_data_consents is
  'AI機能の同意。利用者ID、版、同意した時刻だけ。写真や検索語は入れない。初回設定より前に保存する。user_id は auth.users を向く。退会は public.users.deleted_at のトリガーで消し、auth.users を消したときもカスケードで消える。';

notify pgrst, 'reload schema';

commit;
