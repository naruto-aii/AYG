@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'supabase_saved_food_repository_integration_test.dart';

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

Future<void> _execAsAuthenticated(String userId, String sql) async {
  final result = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-c',
    "SELECT set_config('request.jwt.claim.sub', '$userId', true); "
        "SELECT set_config('request.jwt.claim.role', 'authenticated', true); "
        'SET ROLE authenticated; '
        '$sql '
        'RESET ROLE;',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'as authenticated $userId: ${result.stderr}\n${result.stdout}',
    );
  }
}

Future<String> _countAsAuthenticated(String userId, String sql) async {
  final result = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-tAc',
    "SELECT set_config('request.jwt.claim.sub', '$userId', true); "
        "SELECT set_config('request.jwt.claim.role', 'authenticated', true); "
        'SET ROLE authenticated; '
        '$sql '
        'RESET ROLE;',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'as authenticated $userId: ${result.stderr}\n${result.stdout}',
    );
  }
  final lines = (result.stdout as String).trim().split('\n');
  for (final line in lines.reversed) {
    final trimmed = line.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed;
    }
  }
  throw StateError(
    'as authenticated $userId: no numeric result in ${result.stdout}',
  );
}

Future<void> _psqlAsRole(String role, String sql) async {
  final result = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-c',
    "SET ROLE $role; $sql RESET ROLE;",
  ]);
  if (result.exitCode != 0) {
    throw StateError('as $role: ${result.stderr}\n${result.stdout}');
  }
}

void main() {
  group('Supabase hardening migration live validation', () {
    late bool available;

    setUpAll(() async {
      available = await isLocalSupabaseAvailable();
    });

    test('grants and policies after full db reset', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
      }

      // anon: no TRUNCATE/REFERENCES/TRIGGER on any public table
      final anonBad = await _psql(
        "SELECT COUNT(*) FROM information_schema.role_table_grants "
        "WHERE grantee = 'anon' AND table_schema = 'public' "
        "AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');",
      );
      expect(anonBad, '0');

      // authenticated: no TRUNCATE/REFERENCES/TRIGGER
      final authBad = await _psql(
        "SELECT COUNT(*) FROM information_schema.role_table_grants "
        "WHERE grantee = 'authenticated' AND table_schema = 'public' "
        "AND privilege_type IN ('TRUNCATE', 'REFERENCES', 'TRIGGER');",
      );
      expect(authBad, '0');

      // personal tables: anon has zero grants
      for (final table in [
        'users',
        'profiles',
        'food_entries',
        'meal_templates',
        'workout_templates',
        'blocked_food_creators',
        'rate_limit_buckets',
      ]) {
        expect(
          await _psql(
            "SELECT COUNT(*) FROM information_schema.role_table_grants "
            "WHERE grantee = 'anon' AND table_schema = 'public' "
            "AND table_name = '$table';",
          ),
          '0',
          reason: '$table should have no anon grants',
        );
      }

      // public-read exceptions: anon SELECT only
      final anonSavedFoods = await _psql(
        "SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) "
        "FROM information_schema.role_table_grants "
        "WHERE grantee = 'anon' AND table_name = 'saved_foods';",
      );
      expect(anonSavedFoods, 'SELECT');

      final anonStats = await _psql(
        "SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) "
        "FROM information_schema.role_table_grants "
        "WHERE grantee = 'anon' AND table_name = 'food_rating_stats';",
      );
      expect(anonStats, 'SELECT');

      // RPC: only publish_saved_food for authenticated
      final anonRpc = await _psql(
        "SELECT COUNT(*) FROM information_schema.routine_privileges "
        "WHERE grantee = 'anon' AND routine_schema = 'public';",
      );
      expect(anonRpc, '2');

      final authRpc = await _psql(
        "SELECT routine_name FROM information_schema.routine_privileges "
        "WHERE grantee = 'authenticated' AND routine_schema = 'public' "
        "ORDER BY routine_name;",
      );
      final authRpcNames = authRpc
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
      expect(authRpcNames, contains('publish_saved_food'));
      expect(authRpcNames, contains('is_saved_food_publicly_visible'));
      expect(authRpcNames, contains('is_saved_food_visible_to_viewer'));
      expect(authRpcNames, contains('is_saved_food_reportable'));
      expect(authRpcNames.length, 4);

      // migration grants survive seed (seed must not re-grant)
      final usersAuth = await _psql(
        "SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) "
        "FROM information_schema.role_table_grants "
        "WHERE grantee = 'authenticated' AND table_name = 'users';",
      );
      expect(usersAuth, 'INSERT,SELECT');

      // RLS enabled on all app tables
      for (final table in [
        'users',
        'profiles',
        'saved_foods',
        'meal_templates',
        'workout_templates',
        'food_entries',
        'rate_limit_buckets',
      ]) {
        expect(
          await _psql(
            "SELECT relrowsecurity FROM pg_class c "
            "JOIN pg_namespace n ON n.oid = c.relnamespace "
            "WHERE n.nspname = 'public' AND c.relname = '$table';",
          ),
          't',
          reason: 'RLS should be enabled on $table',
        );
      }
    });

    test('anon can read public saved_foods; authenticated CRUD own row', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
      }

      const ownerId = '11111111-1111-1111-1111-111111111111';
      const foodId = 'pub-food-1';

      await _psql(
        "INSERT INTO auth.users (id, aud, role, email) "
        "VALUES ('$ownerId', 'authenticated', 'authenticated', 'owner@test.local') "
        "ON CONFLICT (id) DO NOTHING;",
      );
      await _psql(
        "INSERT INTO public.users (id, email) VALUES ('$ownerId', 'owner@test.local') "
        "ON CONFLICT (id) DO NOTHING;",
      );
      await _psql(
        "SET session_replication_role = replica; "
        "INSERT INTO public.saved_foods (user_id, food_id, name, normalized_name, "
        "base_amount, unit_type, visibility, status, moderation_status, source_type, version) "
        "VALUES ('$ownerId', '$foodId', 'Public Rice', 'public rice', 100, 'g', "
        "'public', 'active', 'none', 'manual', 1) "
        "ON CONFLICT (user_id, food_id) DO UPDATE SET visibility = 'public', status = 'active'; "
        "SET session_replication_role = DEFAULT;",
      );

      // anon SELECT public food succeeds
      final anonCount = await _psql(
        "SELECT COUNT(*) FROM public.saved_foods WHERE food_id = '$foodId';",
      );
      // verify as anon role separately
      await _psqlAsRole(
        'anon',
        "SELECT COUNT(*) FROM public.saved_foods WHERE food_id = '$foodId';",
      );
      expect(int.parse(anonCount), greaterThanOrEqualTo(1));

      // anon INSERT fails
      expect(
        () => _psqlAsRole(
          'anon',
          "INSERT INTO public.profiles (user_id, birth_date, gender, height_cm, weight_kg) "
              "VALUES ('$ownerId', now(), 'other', 170, 70);",
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'blocked_food_creators: anon has no table grant; block hides public food',
      () async {
        if (!available) {
          markTestSkipped('Local Supabase not available');
        }

        const ownerId = '22222222-2222-2222-2222-222222222222';
        const blockerId = '33333333-3333-3333-3333-333333333333';
        const foodId = 'blocked-food-1';

        expect(
          await _psql(
            "SELECT COUNT(*) FROM information_schema.role_table_grants "
            "WHERE grantee = 'anon' AND table_name = 'blocked_food_creators';",
          ),
          '0',
        );

        await _psql(
          "INSERT INTO auth.users (id, aud, role, email) VALUES "
          "('$ownerId', 'authenticated', 'authenticated', 'owner2@test.local'), "
          "('$blockerId', 'authenticated', 'authenticated', 'blocker@test.local') "
          "ON CONFLICT (id) DO NOTHING;",
        );
        await _psql(
          "INSERT INTO public.users (id, email) VALUES "
          "('$ownerId', 'owner2@test.local'), "
          "('$blockerId', 'blocker@test.local') "
          "ON CONFLICT (id) DO NOTHING;",
        );
        await _psql(
          "SET session_replication_role = replica; "
          "INSERT INTO public.saved_foods (user_id, food_id, name, normalized_name, "
          "base_amount, unit_type, visibility, status, moderation_status, source_type, version) "
          "VALUES ('$ownerId', '$foodId', 'Blocked Food', 'blocked food', 100, 'g', "
          "'public', 'active', 'none', 'manual', 1) "
          "ON CONFLICT (user_id, food_id) DO UPDATE SET visibility = 'public', status = 'active'; "
          "SET session_replication_role = DEFAULT;",
        );

        // anon can read public food without blocked_food_creators SELECT grant
        await _psqlAsRole(
          'anon',
          "SELECT COUNT(*) FROM public.saved_foods WHERE food_id = '$foodId';",
        );

        await _execAsAuthenticated(
          blockerId,
          "INSERT INTO public.blocked_food_creators (blocker_user_id, blocked_user_id) "
          "VALUES ('$blockerId', '$ownerId') ON CONFLICT DO NOTHING;",
        );

        final hiddenCount = await _countAsAuthenticated(
          blockerId,
          "SELECT COUNT(*) FROM public.saved_foods WHERE food_id = '$foodId';",
        );
        expect(hiddenCount, '0');
      },
    );
  });
}
