import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_events migration is append-only and locks the new tables', () {
    final sql = File(
      'supabase/migrations/20261008090000_app_events.sql',
    ).readAsStringSync();
    final schedule = File(
      'supabase/migrations/20261008090100_store_import_schedule.sql',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.app_events'));
    expect(sql, contains('advertising_use = false'));
    expect(
      sql,
      isNot(contains('grant insert on table public.app_events to authenticated')),
    );
    expect(
      sql,
      isNot(contains('create policy app_events_insert_own')),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.app_events from public, anon, authenticated',
      ),
    );
    expect(sql, isNot(contains('create policy app_events_select')));
    expect(sql, isNot(contains('create policy app_events_update')));
    expect(sql, isNot(contains('create policy app_events_delete')));

    expect(
      sql,
      contains(
        'revoke all on table public.store_server_notifications from anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.store_sales_rows from anon, authenticated',
      ),
    );
    expect(
      sql,
      contains('create or replace view public.app_events_including_legacy'),
    );
    expect(
      sql,
      contains(
        'create or replace function public.delete_own_account(p_user_id uuid)',
      ),
    );
    expect(
      sql,
      contains('delete from public.app_events where user_id = '),
    );
    expect(sql, contains('account_deletion_stats'));
    expect(
      sql,
      contains(
        'do update set deletions = public.account_deletion_stats.deletions + 1',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.delete_own_account(uuid) to service_role',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.delete_own_account(uuid) from public, anon, authenticated',
      ),
    );
    expect(schedule, contains('store-analytics-import'));
    expect(schedule, contains('store-sales-import'));
  });

  test('purchase links and raw-event retention are append-only', () {
    final sql = File(
      'supabase/migrations/20261008090200_app_events_retention.sql',
    ).readAsStringSync();
    final schedule = File(
      'supabase/migrations/20261008090300_app_events_retention_schedule.sql',
    ).readAsStringSync();
    final matcher = File(
      'supabase/functions/_shared/store_live.ts',
    ).readAsStringSync();
    final transport = File(
      'lib/services/analytics/supabase_analytics_transport.dart',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.store_original_transactions'));
    expect(sql, contains('original_transaction_id text primary key'));
    expect(sql, contains('grant select on table public.store_original_transactions to authenticated'));
    expect(
      sql,
      contains('create policy store_original_transactions_select_own'),
    );
    expect(
      sql,
      isNot(contains('grant insert on table public.store_original_transactions')),
    );
    expect(
      sql,
      contains('delete from public.store_original_transactions where user_id = '),
    );
    expect(sql, contains('partition by range (occurred_at)'));
    expect(sql, contains('primary key (event_id, occurred_at)'));
    expect(sql, contains("interval '90 days'"));
    expect(sql, contains('u.deleted_at is not null'));
    expect(sql, contains('revoke all on table public.%I from public, anon, authenticated'));
    expect(sql, contains('drop table public.%I'));
    expect(sql, contains('create table if not exists public.app_event_daily_totals'));
    expect(sql, contains("interval '2 years'"));
    expect(sql, contains('create table if not exists public.app_event_user_days'));
    expect(sql, contains("interval '13 months'"));
    expect(
      sql,
      contains('delete from public.app_event_user_days where user_id = '),
    );
    expect(sql, isNot(contains('delete from public.app_event_daily_totals\n    where user_id')));
    expect(sql, contains('delete from public.app_events where user_id = '));
    expect(sql, contains('revoke all on function public.delete_own_account(uuid) from public, anon, authenticated'));
    expect(sql, contains('create or replace function public.insert_app_events(events jsonb)'));
    expect(sql, contains('on conflict (event_id, occurred_at) do nothing'));
    expect(sql, contains('set search_path = \'\''));
    expect(
      sql,
      contains(
        'revoke all on function public.insert_app_events(jsonb) from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains('grant execute on function public.insert_app_events(jsonb) to authenticated'),
    );
    expect(sql, isNot(contains('grant insert on table public.app_events to authenticated')));
    expect(schedule, contains('app-events-retention-daily'));
    expect(schedule, contains('public.maintain_app_events()'));
    expect(schedule, contains('pg_cron'));
    expect(schedule, isNot(contains('STORE_IMPORT_SECRET')));
    expect(matcher, contains('store_original_transactions'));
    expect(matcher, isNot(contains('entitlement_observed')));
    expect(transport, contains("rpc('insert_app_events'"));
    expect(transport, contains("'PGRST202'"));
    expect(transport, contains("'42883'"));

    final retentionDown = File(
      'supabase/rollback/20261008090200_app_events_retention_down.sql',
    ).readAsStringSync();
    final eventsDown = File(
      'supabase/rollback/20261008090000_app_events_down.sql',
    ).readAsStringSync();
    expect(retentionDown, contains('drop function if exists public.insert_app_events(jsonb)'));
    expect(retentionDown, contains('drop function if exists public.maintain_app_events()'));
    expect(retentionDown, isNot(contains('drop table if exists public.app_events;')));
    expect(retentionDown, isNot(contains('drop table if exists public.app_events cascade')));
    expect(eventsDown, contains('drop table if exists public.app_events cascade'));
    expect(eventsDown, contains('20261008090200 を先に戻してください'));
    expect(
      eventsDown,
      contains('create or replace function public.delete_own_account(p_user_id uuid)'),
    );
    expect(eventsDown, isNot(contains('insert into public.account_deletion_stats')));
  });
}
