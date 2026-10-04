import 'dart:io';

import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261004150000_coach_proposal_logs.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/rollback/20261004150000_coach_proposal_logs_down.sql',
  ).readAsStringSync();

  test('the coach log keeps proposal, registered, and time for the sheet', () {
    expect(
      coachDecisionSpreadsheetId,
      '148oUF5Coz17Bk7poFs0xQOdiO3Z_tkNB-PKN5w74H80',
    );
    expect(sql, contains(coachDecisionSpreadsheetId));
    expect(sql, contains('proposal text not null'));
    expect(sql, contains('registered boolean not null default false'));
    expect(sql, contains('recorded_at timestamptz not null'));
    expect(sql, contains('シートへ書き込まない'));
    expect(sql, contains('enable row level security'));
    expect(sql, isNot(contains('meals jsonb')));
    expect(sql, isNot(contains('exercise_message')));
    expect(sql, isNot(contains('registered_position')));
    expect(sql, isNot(contains('advertising_use')));
    expect(sql, isNot(contains('spreadsheets')));
    expect(sql, isNot(contains('for delete')));
    expect(sql, isNot(contains('good')));
    expect(sql, isNot(contains('bad')));
    expect(
      sql,
      contains('delete from public.coach_proposal_logs where user_id = \$1'),
    );
  });

  test('rollback drops only the coach proposal log', () {
    expect(rollback, contains(coachDecisionSpreadsheetId));
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
