-- 自炊コーチのレシピ型と、手持ち0件の記録。
-- レシピの行は supabase/seed/cook_recipes.sql。成分表が空の環境では入れない。
-- 本番には適用しない。手順は supabase/functions/README.md。

begin;

create table if not exists public.cook_recipes (
  id text primary key
    check (char_length(id) between 1 and 64),
  name_template text not null
    check (char_length(name_template) between 1 and 80),
  genre text not null
    check (genre in ('和', '洋', '中', 'エスニック')),
  category text not null
    check (category in ('主菜', '副菜', '主食', '汁物', '丼麺', '軽い品')),
  method text not null
    check (char_length(method) between 1 and 20),
  minutes integer not null
    check (minutes between 5 and 30),
  steps jsonb not null
);

comment on table public.cook_recipes is
  '確認済みの家庭料理。名前は入れ替え後も成立するテンプレ。選定は毎回この表を読む。';

create table if not exists public.cook_recipe_options (
  recipe_id text not null references public.cook_recipes (id) on delete cascade,
  slot_key text not null
    check (char_length(slot_key) between 1 and 32),
  role text not null
    check (role in ('protein', 'veg', 'staple', 'seasoning', 'oil', 'egg', 'other')),
  label text not null
    check (char_length(label) between 1 and 40),
  food_code text not null references public.official_foods (food_code),
  base_grams numeric(6, 1) not null
    check (base_grams > 0 and base_grams <= 400),
  sort_order integer not null
    check (sort_order >= 0),
  match_names text[] not null,
  staple boolean not null default false,
  primary key (recipe_id, slot_key, label)
);

comment on table public.cook_recipe_options is
  'レシピごとの入れ替え候補。基準gとその食品の成分表で計算し直す。';

create index if not exists cook_recipe_options_food_idx
  on public.cook_recipe_options (food_code);

create table if not exists public.cook_zero_on_hand (
  id bigint generated always as identity primary key,
  ingredients text[] not null
    check (cardinality(ingredients) between 1 and 20),
  at_time time not null
);

comment on table public.cook_zero_on_hand is
  '手持ちだけでは作れなかった入力。正規化した食材名と時刻だけ。利用者の識別子は持たない。';

create index if not exists cook_zero_on_hand_ingredients_idx
  on public.cook_zero_on_hand (ingredients);

alter table public.cook_recipes enable row level security;
alter table public.cook_recipe_options enable row level security;
alter table public.cook_zero_on_hand enable row level security;

revoke all on table public.cook_recipes from anon, authenticated;
revoke all on table public.cook_recipe_options from anon, authenticated;
revoke all on table public.cook_zero_on_hand from anon, authenticated;

commit;
