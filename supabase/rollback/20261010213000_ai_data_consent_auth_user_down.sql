-- 20261010213000 を戻す。同意の参照先を public.users に戻す。
-- public.users が無い同意行は、旧制約では残らないので消す。
-- 食事の行は消えない。本番には適用しない。

begin;

delete from public.ai_data_consents c
where not exists (
  select 1 from public.users u where u.id = c.user_id
);

do $$
declare
  cons name;
begin
  for cons in
    select c.conname
    from pg_constraint c
    join pg_class rel on rel.oid = c.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'ai_data_consents'
      and c.contype = 'f'
      and c.conkey = array[
        (
          select att.attnum
          from pg_attribute att
          where att.attrelid = rel.oid
            and att.attname = 'user_id'
            and not att.attisdropped
        )
      ]::smallint[]
  loop
    execute format(
      'alter table public.ai_data_consents drop constraint %I',
      cons
    );
  end loop;
end
$$;

alter table public.ai_data_consents
  add constraint ai_data_consents_user_id_fkey
  foreign key (user_id) references public.users (id) on delete cascade;

comment on table public.ai_data_consents is
  'AI機能の同意。利用者ID、版、同意した時刻だけ。写真や検索語は入れない。アカウント削除で消す。';

notify pgrst, 'reload schema';

commit;
