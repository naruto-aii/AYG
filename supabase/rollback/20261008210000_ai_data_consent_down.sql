-- 20261008210000 を戻す。AI機能の同意の表を消す。食事の行は消えない。

begin;

drop trigger if exists delete_ai_data_consent_on_account_close on public.users;
drop function if exists public.delete_ai_data_consent_on_account_close();

drop trigger if exists ai_data_consents_stamp on public.ai_data_consents;
drop function if exists public.ai_data_consents_stamp();

drop table if exists public.ai_data_consents;

commit;
