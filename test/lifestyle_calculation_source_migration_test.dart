import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String up;
  late String down;

  setUpAll(() {
    up = File(
      'supabase/migrations/20261003210000_allow_lifestyle_included_calculation_source.sql',
    ).readAsStringSync();
    down = File(
      'supabase/rollback/20261003210000_allow_lifestyle_included_calculation_source_down.sql',
    ).readAsStringSync();
  });

  test('allows the lifestyle source the app already writes', () {
    expect(up, contains("'lifestyle_included'"));
    expect(up, contains("'met_estimate'"));
    expect(up, contains("'manual_override'"));
    expect(up, contains("'template'"));
    expect(up, isNot(contains('add column')));
    expect(up, isNot(contains('drop column')));
  });

  test('does not delete existing exercise or meal rows', () {
    final statements = _sqlStatements(up);
    expect(statements, isNot(contains('truncate')));
    expect(statements, isNot(contains('delete from')));
    expect(statements, isNot(contains('drop table')));
  });

  test('rollback refuses to narrow the check while lifestyle rows exist', () {
    expect(down, contains("calculation_source = 'lifestyle_included'"));
    expect(down, contains('refusing to narrow the check or delete them'));
    expect(down, contains("'met_estimate'"));
    final allowed = down.split('add constraint').last;
    expect(allowed, isNot(contains('lifestyle_included')));
    final statements = _sqlStatements(down);
    expect(statements, isNot(contains('truncate')));
    expect(statements, isNot(contains('delete from')));
    expect(statements, isNot(contains('drop column')));
    expect(statements, isNot(contains('drop table')));
  });
}

String _sqlStatements(String sql) {
  return sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
}
