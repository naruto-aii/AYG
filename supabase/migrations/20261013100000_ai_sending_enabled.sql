-- AIへの送信スイッチ。利用規約の同意行は残し、送るかどうかだけを変える。
-- 既存の行はオン（true）。オフの行は Edge Function が拒否する。
-- 同意時刻は、版が変わったときだけ付け直す。スイッチでは付け直さない。
-- 本番には適用しない。20261010213000 のあと。関数より先。

begin;

alter table public.ai_data_consents
  add column if not exists ai_sending_enabled boolean not null default true;

comment on column public.ai_data_consents.ai_sending_enabled is
  'AI機能の入力を外部へ送るか。false のとき Edge Function は拒否する。利用規約の同意行は残す。';

create or replace function public.ai_data_consents_stamp()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if TG_OP = 'INSERT' then
    new.consented_at = timezone('utc', now());
  elsif new.policy_version is distinct from old.policy_version then
    new.consented_at = timezone('utc', now());
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';

commit;
