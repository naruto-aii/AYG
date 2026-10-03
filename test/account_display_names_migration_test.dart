import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String up;
  late String down;

  setUpAll(() {
    up = File(
      'supabase/migrations/20261003180000_account_display_names.sql',
    ).readAsStringSync();
    down = File(
      'supabase/rollback/20261003180000_account_display_names_down.sql',
    ).readAsStringSync();
  });

  test('copies only a registered name and refuses advertising', () {
    expect(up, contains('create table if not exists public.account_display_names'));
    expect(up, contains('char_length(display_name) between 1 and 40'));
    expect(up, contains('check (advertising_use = false)'));
    expect(up, contains('enable row level security'));
    expect(up, contains('grant select on table public.account_display_names'));
    expect(up, isNot(contains('grant insert')));
    expect(up, isNot(contains('grant update')));
    expect(up, isNot(contains('grant delete')));
    expect(up, contains('security definer'));
    expect(up, contains('set search_path = public'));
    expect(up, contains('create schema if not exists internal'));
    for (final absent in [
      'gender',
      'birth_date',
      'height_cm',
      'weight_kg',
      'receipt',
      'token',
      'transaction',
    ]) {
      expect(
        _createTableStatement(up, 'account_display_names'),
        isNot(contains(absent)),
        reason: absent,
      );
    }
  });

  test('does not delete existing profile, health, or usage rows', () {
    final lowered = up.toLowerCase();
    for (final table in [
      'profiles',
      'users',
      'health_snapshots',
      'food_entries',
      'exercise_entries',
      'weight_entries',
      'goals',
      'calonavi_plus_entitlements',
      'food_search_queries',
      'exercise_search_queries',
      'app_screen_actions',
    ]) {
      expect(lowered, isNot(contains('delete from public.$table')));
      expect(lowered, isNot(contains('drop table if exists public.$table')));
    }
    expect(_sqlStatements(up), isNot(contains('truncate')));
    expect(up, contains('where display_name is not null'));
  });

  test('rollback drops the copy and leaves the profile name column', () {
    expect(down, contains('drop table if exists public.account_display_names'));
    expect(down, contains('drop function if exists internal.sync_account_display_name()'));
    expect(down, isNot(contains('drop table if exists public.profiles')));
    expect(down, isNot(contains('drop column')));
    expect(down, isNot(contains('delete from public.profiles')));
    expect(down, isNot(contains('drop table if exists public.calonavi_plus_entitlements')));
    expect(down, isNot(contains('drop table if exists public.food_search_queries')));
    expect(_sqlStatements(down), isNot(contains('truncate')));
  });
}

String _sqlStatements(String sql) {
  return sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
}

String _createTableStatement(String sql, String table) {
  final start = sql.indexOf('create table if not exists public.$table');
  expect(start, greaterThanOrEqualTo(0));
  final end = sql.indexOf(');', start);
  expect(end, greaterThan(start));
  return sql.substring(start, end + 2);
}
