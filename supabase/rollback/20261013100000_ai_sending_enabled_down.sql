-- 20261013100000 を戻す。同意の行は残す。送るかどうかの列だけ消す。
-- 同意時刻は、再び更新のたびに付け直す。

begin;

create or replace function public.ai_data_consents_stamp()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.consented_at = timezone('utc', now());
  return new;
end;
$$;

alter table public.ai_data_consents
  drop column if exists ai_sending_enabled;

notify pgrst, 'reload schema';

commit;
