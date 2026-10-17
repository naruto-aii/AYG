-- rollback for 20261017030000_app_version_policy
-- 更新案内の表だけを消す。既存の表には列を足していない。

drop table if exists public.app_version_policy;
