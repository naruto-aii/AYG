-- 食事と運動に、記録した場所を足す。追加だけ。null を許す。
-- app / widget / siri など。値の一覧は締めない。
-- 本番には未適用。このエージェントからは適用しない。

begin;

alter table public.food_entries
  add column if not exists record_origin text;

alter table public.exercise_entries
  add column if not exists record_origin text;

comment on column public.food_entries.record_origin is
  '記録した場所。app / widget / siri など。未設定の行は null。';

comment on column public.exercise_entries.record_origin is
  '記録した場所。app / widget / siri など。未設定の行は null。';

commit;
