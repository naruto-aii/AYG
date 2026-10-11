import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path =
      'supabase/migrations/20261011063750_kpi_exclusion_by_identity.sql';

  test('identity exclusion stays in one function and out of the repo', () {
    final sql = File(path).readAsStringSync();
    final down = File(
      'supabase/rollback/20261011063750_kpi_exclusion_by_identity_down.sql',
    ).readAsStringSync();
    final executable = sql
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n')
        .toLowerCase();

    expect(sql, contains('kpi.collect_excluded_user_ids'));
    expect(sql, contains('auth.identities'));
    expect(sql, contains('i.provider_id = x.provider_id'));
    expect(sql, contains('u.deleted_at is not null'));
    expect(sql, contains('create or replace view kpi.excluded_user_ids'));
    expect(sql, isNot(contains('invalid.local')));
    expect(executable, isNot(contains('insert into public.kpi_excluded_users')));
    expect(executable, isNot(contains('create policy')));
    expect(executable, isNot(contains('enable row level security')));
    expect(executable, isNot(contains('@')));

    expect(down, contains('drop function if exists kpi.collect_excluded_user_ids'));
    expect(down, contains('drop column if exists provider'));
    expect(down, isNot(contains('drop schema kpi')));
  });
}
