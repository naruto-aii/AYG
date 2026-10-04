import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261004150000_coach_proposal_logs.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/rollback/20261004150000_coach_proposal_logs_down.sql',
  ).readAsStringSync();

  test('the coach log stores proposals and who registered them', () {
    expect(
      sql,
      contains('create table if not exists public.coach_proposal_logs'),
    );
    expect(sql, contains('meals jsonb not null'));
    expect(sql, contains('registered_position smallint'));
    expect(sql, contains('exercise_message text'));
    expect(sql, contains('advertising_use = false'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('for select'));
    expect(sql, contains('for insert'));
    expect(sql, contains('for update'));
    expect(sql, isNot(contains('for delete')));
    expect(
      sql,
      contains(
        'grant select, insert, update on table public.coach_proposal_logs to authenticated',
      ),
    );
    expect(sql, isNot(contains('to anon')));
    expect(
      sql,
      contains('delete from public.coach_proposal_logs where user_id = \$1'),
    );
    expect(sql, isNot(contains('good')));
    expect(sql, isNot(contains('bad')));
  });

  test('rollback drops only the coach proposal log', () {
    expect(
      rollback,
      contains('drop table if exists public.coach_proposal_logs'),
    );
    expect(rollback, isNot(contains('official_foods')));
    expect(rollback, isNot(contains('food_entries')));
    expect(
      rollback,
      isNot(contains('drop table if exists public.announcements')),
    );
  });
}
