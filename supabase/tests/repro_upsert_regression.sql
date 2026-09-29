-- #31 08dca4e 回帰の最小再現（PG17, #31 適用済み DB, ayg_test.set_auth あり）。a4d8a7e では全て成功。
-- A が公開→B がコピー→A が非公開化→B がアプリと同じ upsert で編集すると失敗。
\set A '''aaaaaaaa-0000-4000-8000-0000000000f1'''
\set B '''bbbbbbbb-0000-4000-8000-0000000000f2'''
insert into auth.users(id,email) values (:A,'ra@t.local'),(:B,'rb@t.local');
insert into public.users(id,email) values (:A,'ra@t.local'),(:B,'rb@t.local');
begin; select ayg_test.set_auth(:A);
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,source_type) values (:A,'src','おにぎり甲','おにぎり甲',100,'g','manual');
select public.publish_saved_food('src'); commit;
begin; select ayg_test.set_auth(:B);
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,source_type,copied_from_food_id,copied_from_owner_user_id) values (:B,'cp','おにぎり乙','おにぎり乙',100,'g','copied','src',:A); commit;
update public.saved_foods set visibility='private' where food_id='src';
begin; select ayg_test.set_auth(:B);
-- UPDATE は成功
update public.saved_foods set name='x' where user_id=:B and food_id='cp';
-- upsert（PostgREST .upsert(onConflict: user_id,food_id)）は失敗: copied_from must reference your own saved food or a public saved food
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,source_type,copied_from_food_id,copied_from_owner_user_id)
values (:B,'cp','y','y',100,'g','copied','src',:A)
on conflict (user_id,food_id) do update set name=excluded.name, copied_from_food_id=excluded.copied_from_food_id, copied_from_owner_user_id=excluded.copied_from_owner_user_id;
rollback;
