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
    expect(sql, contains('create policy app_events_insert_own'));
    expect(sql, contains('user_id = (select auth.uid())'));
    expect(sql, contains('advertising_use = false'));
    expect(
      sql,
      contains('grant insert on table public.app_events to authenticated'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.app_events from anon, authenticated',
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
}
