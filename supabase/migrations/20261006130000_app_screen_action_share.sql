-- 共有した事実だけを、既存の画面操作に足す。
-- カロリー、体重、体脂肪の数値は列にしない。新しい表は作らない。
-- 行レベルセキュリティは有効のまま。本人の行だけを読み書きできる既存の方針を維持する。
-- 2回実行しても失敗しない。

begin;

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'app_screen_actions'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%meal_button%'
  loop
    execute format(
      'alter table public.app_screen_actions drop constraint %I',
      constraint_name
    );
  end loop;
end $$;

alter table public.app_screen_actions
  drop constraint if exists app_screen_actions_action_check;
alter table public.app_screen_actions
  drop constraint if exists app_screen_actions_pair_check;

alter table public.app_screen_actions
  add constraint app_screen_actions_action_check
  check (action in (
    'open',
    'select',
    'meal_button',
    'share_meal',
    'share_streak',
    'share_weight'
  ));

alter table public.app_screen_actions
  add constraint app_screen_actions_pair_check
  check (
    (
      screen in ('home_widget', 'lock_screen')
      and action = 'meal_button'
    )
    or (
      screen in ('food', 'workout', 'settings')
      and action in ('open', 'select')
    )
    or (
      screen = 'home'
      and action in ('open', 'select', 'share_meal', 'share_streak')
    )
    or (
      screen = 'weight'
      and action in ('open', 'select', 'share_weight')
    )
    or (screen = 'first_meal_guide' and action = 'open')
  );

alter table public.app_screen_actions enable row level security;

comment on table public.app_screen_actions is
  '画面の操作。タブの表示と選択、初回の食事案内、ホームウィジェットとロック画面のボタン、共有（今日の食事、連続記録、体重の変化）。画面名と操作だけ。体重、カロリー、体脂肪の数値は入れない。広告には使わない。';
comment on column public.app_screen_actions.action is
  'open は表示、select はタブ選択、meal_button はウィジェットのボタン、share_meal / share_streak / share_weight は共有シートで送った種類。数値は持たない。';

commit;
