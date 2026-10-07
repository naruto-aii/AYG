-- plus_funnel_events を消す。delete_own_account は表が無いときは何もしない。

begin;

drop table if exists public.plus_funnel_events;

commit;
