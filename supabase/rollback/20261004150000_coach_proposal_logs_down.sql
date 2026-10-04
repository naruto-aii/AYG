-- 今日のコーチの提案記録だけを戻す。
-- シート 148oUF5Coz17Bk7poFs0xQOdiO3Z_tkNB-PKN5w74H80 は触らない。
-- 食事、運動、公式食品、お知らせ、コーチの候補食品は消さない。
-- 2回実行しても失敗しない。
-- delete_own_account の中の削除は、表が無いときは何もしない。

begin;

drop table if exists public.coach_proposal_logs;

commit;
