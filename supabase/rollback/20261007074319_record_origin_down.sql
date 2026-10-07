-- 記録した場所の列だけを外す。行は残す。

begin;

alter table public.food_entries drop column if exists record_origin;
alter table public.exercise_entries drop column if exists record_origin;

commit;
