-- 20261010220000 の戻し。
-- 外した store_original_transactions の行は戻らない。
-- トリガーは、entitlement_observed の自己申告で対応表を再び書く。

begin;

create or replace function public.app_events_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  tx text;
begin
  if new.event_name = 'entitlement_observed' and new.user_id is not null then
    tx := nullif(btrim(new.props->>'original_transaction_id'), '');
    if tx is not null then
      begin
        perform public.remember_store_original_transaction(
          tx,
          new.user_id,
          nullif(btrim(new.props->>'product_id'), '')
        );
      exception
        when others then
          raise notice 'store original transaction capture skipped: %', sqlerrm;
      end;
    end if;
  end if;
  return new;
end;
$function$;

commit;
