@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'supabase_saved_food_repository_integration_test.dart';

Future<void> _applySqlFile(String path) async {
  final sql = File(path).readAsStringSync();
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
    throw StateError('SQL $path failed: ${apply.stderr}\n${apply.stdout}');
  }
}

Future<void> _applyMigration(String filename) {
  return _applySqlFile('supabase/migrations/$filename');
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
        return;
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
          return;
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

    test('banned public food name function is installed', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
        return;
      }

      await _applyMigration(
        '20260927120000_reject_banned_public_food_names.sql',
      );

      expect(
        await _psql("SELECT public.public_food_name_is_banned('キャベツ');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('f u c k');"),
        't',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('shiitake');"),
        'f',
      );
      expect(
        await _psql(r"SELECT public.public_food_name_is_banned(U&'f\00FAck');"),
        't',
      );
      expect(
        await _psql(r"SELECT public.public_food_name_is_banned(U&'fu\0441k');"),
        't',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('5h1t');"),
        't',
      );
      expect(
        await _psql(r"SELECT public.public_food_name_is_banned('$hit');"),
        't',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('カフェラテ');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('ポークソテー');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('ポークソーセージ');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('ミルクソフト');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('スモークソルト');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('サンマンコ');"),
        'f',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('Cock tail');"),
        'f',
      );
      expect(
        await _psql(
          "SELECT public.public_food_name_is_banned('rape seed oil');",
        ),
        'f',
      );
      expect(
        await _psql(
          r"SELECT public.public_food_name_is_banned(U&'\FF81\FF9D\FF8E\FF9F');",
        ),
        't',
      );
      expect(
        await _psql("SELECT public.public_food_name_is_banned('くそ');"),
        't',
      );
      expect(
        await _psql(
          "SELECT proname FROM pg_proc WHERE proname = 'publish_saved_food';",
        ),
        'publish_saved_food',
      );
    });

    test('subscription event counts are insert-only and reversible', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
        return;
      }

      await _applyMigration('20260927140000_subscription_events.sql');

      expect(
        await _psql(
          "SELECT relrowsecurity FROM pg_class WHERE relname = 'subscription_events';",
        ),
        't',
      );
      expect(
        await _psql(
          "SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) "
          "FROM information_schema.role_table_grants "
          "WHERE table_schema = 'public' "
          "AND table_name = 'subscription_events' "
          "AND grantee = 'authenticated';",
        ),
        'INSERT',
      );
      expect(
        await _psql(
          "SELECT has_function_privilege("
          "'authenticated', 'public.subscription_event_counts()', 'EXECUTE');",
        ),
        'f',
      );
      expect(
        await _psql(
          "SELECT has_function_privilege("
          "'service_role', 'public.subscription_event_counts()', 'EXECUTE');",
        ),
        't',
      );
      expect(
        await _psql('SELECT count(*) FROM public.subscription_event_counts();'),
        '0',
      );

      await _applySqlFile(
        'supabase/rollback/20260927140000_subscription_events_down.sql',
      );
      expect(
        await _psql(
          "SELECT to_regclass('public.subscription_events') IS NULL;",
        ),
        't',
      );
    });
  });
}
