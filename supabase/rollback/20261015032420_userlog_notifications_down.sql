-- userlog の通知だけを外す。既存の表・列・pg_net は残す。
drop trigger if exists userlog_app_events_insert on public.app_events;
drop trigger if exists userlog_store_notifications_insert on public.store_server_notifications;
drop trigger if exists userlog_auth_sessions_insert on auth.sessions;

drop function if exists public.userlog_context(uuid, uuid);
drop function if exists public.userlog_claim(uuid, text, text);
drop function if exists public.userlog_finish(uuid, text, text, text, text);
drop table if exists public.userlog_notifications_sent;
drop schema if exists userlog cascade;
