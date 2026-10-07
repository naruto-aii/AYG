-- rollback for 20261007112725_kpi_excluded_users
-- maintain_app_events / delete_own_account を 20261007103757 時点の本文へ戻してから、表・スキーマを消す。
-- 本文: db-backup-20261007/maintain_app_events_prod_before_kpi_excluded_users.sql,
--       db-backup-20261007/delete_own_account_prod_before_kpi_excluded_users.sql を先に流す。
drop schema kpi cascade;
drop table public.kpi_excluded_users;
