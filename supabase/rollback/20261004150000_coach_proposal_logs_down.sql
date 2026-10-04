-- 今日のコーチの提案記録だけを戻す。
-- 食事、運動、公式食品、お知らせ、コーチの候補食品は消さない。
-- 2回実行しても失敗しない。
-- delete_own_account の中の削除は、表が無いときは何もしない。

begin;

drop table if exists public.coach_proposal_logs;

commit;
