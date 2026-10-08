import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clients cannot insert or update plus entitlements', () {
    final sql = File(
      'supabase/migrations/20261008200000_entitlements_server_only.sql',
    ).readAsStringSync();
    final down = File(
      'supabase/rollback/20261008200000_entitlements_server_only_down.sql',
    ).readAsStringSync();

    expect(sql, contains('drop policy if exists calonavi_plus_entitlements_insert_own'));
    expect(sql, contains('drop policy if exists calonavi_plus_entitlements_update_own'));
    expect(
      sql,
      contains(
        'revoke all on table public.calonavi_plus_entitlements from anon, authenticated',
      ),
    );
    expect(
      sql,
      contains('grant select on table public.calonavi_plus_entitlements to authenticated'),
    );
    expect(sql, isNot(contains('grant select, insert, update')));
    expect(sql, isNot(contains('grant insert')));
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
    expect(sql, isNot(contains('create policy calonavi_plus_entitlements_insert_own')));
    expect(sql, isNot(contains('create policy calonavi_plus_entitlements_update_own')));
    expect(sql, isNot(contains('drop policy if exists calonavi_plus_entitlements_select_own')));
    expect(down, contains('grant select, insert, update on table public.calonavi_plus_entitlements'));
    expect(down, contains('create policy calonavi_plus_entitlements_insert_own'));
    expect(down, contains('create policy calonavi_plus_entitlements_update_own'));
  });

  test('the app asks the server to verify a transaction instead of writing the table', () {
    final source = File(
      'lib/repositories/usage_record_repository.dart',
    ).readAsStringSync();
    expect(source, contains("'verify-store-transaction'"));
    expect(source, isNot(contains("from('calonavi_plus_entitlements')")));
    expect(source, isNot(contains("table: 'calonavi_plus_entitlements'")));
  });
}