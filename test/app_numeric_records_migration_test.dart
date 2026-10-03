import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String up;
  late String down;

  setUpAll(() {
    up = File(
      'supabase/migrations/20261003190000_app_numeric_records.sql',
    ).readAsStringSync();
    down = File(
      'supabase/rollback/20261003190000_app_numeric_records_down.sql',
    ).readAsStringSync();
  });

  test('stores workout calories and the saved-food version, not receipts', () {
    expect(up, contains('create table if not exists public.health_workouts'));
    expect(up, contains('calories_burned'));
    expect(up, contains('check (advertising_use = false)'));
    expect(up, contains('source_saved_food_version'));
    expect(up, contains('enable row level security'));
    expect(up, contains('grant select, insert, update on table public.health_workouts'));
    expect(up, isNot(contains('grant delete')));
    final table = _createTableStatement(up, 'health_workouts');
    for (final absent in [
      'steps',
      'distance',
      'receipt',
      'token',
      'transaction',
      'price',
    ]) {
      expect(table, isNot(contains(absent)), reason: absent);
    }
  });

  test('does not drop existing meals, health snapshots, or usage tables', () {
    final statements = _sqlStatements(up);
    for (final table in [
      'food_entries',
      'exercise_entries',
      'weight_entries',
      'health_snapshots',
      'profiles',
      'calonavi_plus_entitlements',
      'food_search_queries',
      'app_screen_actions',
    ]) {
      expect(statements, isNot(contains('drop table if exists public.$table')));
      expect(statements, isNot(contains('drop table public.$table')));
    }
    expect(statements, isNot(contains('truncate')));
    expect(up, contains('add column if not exists source_saved_food_version'));
    expect(up, contains('delete from public.health_workouts where user_id'));
  });

  test('rollback removes the new table and column only', () {
    expect(down, contains('drop table if exists public.health_workouts'));
    expect(down, contains('drop column if exists source_saved_food_version'));
    expect(down, isNot(contains('drop table if exists public.food_entries')));
    expect(down, isNot(contains('drop table if exists public.health_snapshots')));
    expect(down, isNot(contains('drop table if exists public.exercise_entries')));
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
  return sql.substring(start, end + 2);
}
