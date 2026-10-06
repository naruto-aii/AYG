-- 共有の操作だけを戻す。ほかの画面操作、食事、体重の行は消さない。
-- 2回実行しても失敗しない。

begin;

delete from public.app_screen_actions
where action in ('share_meal', 'share_streak', 'share_weight');

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
      and pg_get_constraintdef(con.oid) ilike '%share_meal%'
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
  check (action in ('open', 'select', 'meal_button'));

alter table public.app_screen_actions
  add constraint app_screen_actions_pair_check
  check (
    (
      screen in ('home_widget', 'lock_screen')
      and action = 'meal_button'
    )
    or (
      screen in ('home', 'food', 'workout', 'weight', 'settings')
      and action in ('open', 'select')
    )
    or (screen = 'first_meal_guide' and action = 'open')
  );

alter table public.app_screen_actions enable row level security;

comment on table public.app_screen_actions is
  '今の画面操作。タブの表示と選択、初回の食事案内、ホームウィジェットとロック画面のボタン。画面名と操作だけ。体重、消費カロリー、ヘルスケアの数値は入れない。広告には使わない。';
comment on column public.app_screen_actions.action is
  'open は表示、select はタブ選択、meal_button はウィジェットのボタン。';

commit;
