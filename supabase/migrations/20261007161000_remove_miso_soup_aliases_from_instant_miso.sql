-- 即席みそ 17049 / 17050 から、味噌汁の口語別名を外す。
-- 本番へは適用済み。このファイルはリポジトリを本番に合わせる。
-- 対象は source = spoken_manual_v1 の6行だけ。

begin;

delete from public.official_food_aliases
where source = 'spoken_manual_v1'
  and (
    (
      food_code = '17049'
      and alias in ('味噌汁', 'みそ汁', 'みそしる', 'お味噌汁')
    )
    or (
      food_code = '17050'
      and alias in ('味噌汁', 'みそしる')
    )
  );

commit;
