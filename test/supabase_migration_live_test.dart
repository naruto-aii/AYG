@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'supabase_saved_food_repository_integration_test.dart';

Future<void> _applyMigration(String filename) async {
  final sql = File('supabase/migrations/$filename').readAsStringSync();
  final tempFile = File(
    '${Directory.systemTemp.path}/ayg_migration_${DateTime.now().microsecondsSinceEpoch}.sql',
  );
  await tempFile.writeAsString(sql);
  final copy = await Process.run('docker', [
    'cp',
    tempFile.path,
    'supabase_db_AYG:/tmp/migration.sql',
  ]);
  if (copy.exitCode != 0) {
    throw StateError('docker cp failed: ${copy.stderr}');
  }
  final apply = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-f',
    '/tmp/migration.sql',
  ]);
  if (apply.exitCode != 0) {
    throw StateError(
      'Migration $filename failed: ${apply.stderr}\n${apply.stdout}',
    );
  }
}

Future<String> _psql(String sql) async {
  final result = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-tAc',
    sql,
  ]);
  if (result.exitCode != 0) {
    throw StateError(result.stderr as String);
  }
  return (result.stdout as String).trim();
}

void main() {
  group('Supabase migration live validation', () {
    late bool available;

    setUpAll(() async {
      available = await isLocalSupabaseAvailable();
    });

    test('workout_templates migration applies with RLS and grants', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
      }

      await _applyMigration('20260728120000_add_workout_templates_v1.sql');

      expect(
        await _psql(
          "SELECT to_regclass('public.workout_templates') IS NOT NULL;",
        ),
        't',
      );
      expect(
        await _psql(
          "SELECT relrowsecurity FROM pg_class WHERE relname = 'workout_templates';",
        ),
        't',
      );

      expect(
        await _psql(
          "SELECT COUNT(*) FROM information_schema.role_table_grants "
          "WHERE grantee = 'anon' AND table_name = 'workout_templates';",
        ),
        '0',
      );

      final authPriv = await _psql(
        "SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) "
        "FROM information_schema.role_table_grants "
        "WHERE grantee = 'authenticated' AND table_name = 'workout_templates';",
      );
      expect(authPriv, contains('SELECT'));
      expect(authPriv, contains('INSERT'));
      expect(authPriv, contains('UPDATE'));
      expect(authPriv, contains('DELETE'));

      final policies = await _psql(
        "SELECT COUNT(*) FROM pg_policies WHERE tablename = 'workout_templates';",
      );
      expect(int.parse(policies), greaterThanOrEqualTo(1));

      final policyUsesUid = await _psql(
        "SELECT COUNT(*) FROM pg_policies "
        "WHERE tablename = 'workout_templates' "
        "AND qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%';",
      );
      expect(int.parse(policyUsesUid), greaterThanOrEqualTo(1));
    });

    test(
      'exercise calculation columns migration is idempotent and nullable',
      () async {
        if (!available) {
          markTestSkipped('Local Supabase not available');
        }

        await _applyMigration(
          '20260801180000_add_exercise_entry_calculation_columns.sql',
        );
        await _applyMigration(
          '20260801180000_add_exercise_entry_calculation_columns.sql',
        );

        expect(
          await _psql(
            "SELECT is_nullable FROM information_schema.columns "
            "WHERE table_name = 'exercise_entries' AND column_name = 'net_kcal';",
          ),
          'YES',
        );

        expect(
          await _psql(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_name = 'exercise_entries' AND column_name = 'gross_kcal';",
          ),
          '1',
        );
      },
    );
  });
}
