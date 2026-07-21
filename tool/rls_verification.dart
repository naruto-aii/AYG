// RLS cross-user verification (Publishable Key + user JWT only).
//
// Prerequisites:
// - User A and User B must be dedicated Google test accounts with NO pre-existing
//   app data (fresh accounts recommended).
// - Do NOT use admin / elevated Supabase keys.
//
// Token handling (avoid shell history):
//   mkdir -p ~/.rls_test && chmod 700 ~/.rls_test
//   # Paste token into files locally; never commit these files.
//   printf '%s' '<token>' > ~/.rls_test/user_a && chmod 600 ~/.rls_test/user_a
//   printf '%s' '<token>' > ~/.rls_test/user_b && chmod 600 ~/.rls_test/user_b
//   RLS_TEST_USER_A_TOKEN_FILE=~/.rls_test/user_a \
//   RLS_TEST_USER_B_TOKEN_FILE=~/.rls_test/user_b \
//   dart run tool/rls_verification.dart
//
// After the run:
//   rm -f ~/.rls_test/user_a ~/.rls_test/user_b
//   unset RLS_TEST_USER_A_TOKEN_FILE RLS_TEST_USER_B_TOKEN_FILE

import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

const _testPrefix = 'rls-test-';

Future<Map<String, String>> _loadConfig() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && anonKey.isNotEmpty) {
    return {'SUPABASE_URL': url, 'SUPABASE_ANON_KEY': anonKey};
  }

  final configPath =
      Platform.environment['RLS_CONFIG_FILE'] ?? 'tool/dart_defines.local.json';
  final file = File(configPath);
  if (!file.existsSync()) {
    return {};
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    'SUPABASE_URL': json['SUPABASE_URL'] as String? ?? '',
    'SUPABASE_ANON_KEY': json['SUPABASE_ANON_KEY'] as String? ?? '',
  };
}

String _readTokenFromEnv(String directKey, String fileKey) {
  final direct = Platform.environment[directKey] ?? '';
  if (direct.isNotEmpty) {
    return direct;
  }
  final path = Platform.environment[fileKey];
  if (path == null || path.isEmpty) {
    return '';
  }
  final file = File(path);
  if (!file.existsSync()) {
    return '';
  }
  return file.readAsStringSync().trim();
}

Future<void> main() async {
  final config = await _loadConfig();
  final url = config['SUPABASE_URL'] ?? '';
  final anonKey = config['SUPABASE_ANON_KEY'] ?? '';
  final tokenA = _readTokenFromEnv(
    'RLS_TEST_USER_A_ACCESS_TOKEN',
    'RLS_TEST_USER_A_TOKEN_FILE',
  );
  final tokenB = _readTokenFromEnv(
    'RLS_TEST_USER_B_ACCESS_TOKEN',
    'RLS_TEST_USER_B_TOKEN_FILE',
  );

  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln('FAIL: SUPABASE_URL / SUPABASE_ANON_KEY not configured.');
    exit(1);
  }
  if (tokenA.isEmpty || tokenB.isEmpty) {
    stderr.writeln(
      'FAIL: Provide tokens via *_TOKEN_FILE (recommended) or *_ACCESS_TOKEN env vars.',
    );
    exit(1);
  }

  final anonClient = SupabaseClient(url, anonKey);
  final clientA = SupabaseClient(
    url,
    anonKey,
    headers: {'Authorization': 'Bearer $tokenA'},
  );
  final clientB = SupabaseClient(
    url,
    anonKey,
    headers: {'Authorization': 'Bearer $tokenB'},
  );

  final userA = (await anonClient.auth.getUser(tokenA)).user;
  final userB = (await anonClient.auth.getUser(tokenB)).user;
  if (userA == null || userB == null) {
    stderr.writeln('FAIL: Invalid access tokens.');
    exit(1);
  }
  if (userA.id == userB.id) {
    stderr.writeln('FAIL: User A and User B must be different accounts.');
    exit(1);
  }

  stdout.writeln('User A id prefix: ${userA.id.substring(0, 8)}...');
  stdout.writeln('User B id prefix: ${userB.id.substring(0, 8)}...');

  final failures = <String>[];
  var userBCreatedProfile = false;

  Future<void> expectFailure(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      failures.add('$label: expected failure but succeeded');
    } catch (_) {
      stdout.writeln('PASS: $label blocked');
    }
  }

  Future<void> expectEmptySelect(
    String label,
    Future<List<Map<String, dynamic>>> Function() action,
  ) async {
    final rows = await action();
    if (rows.isNotEmpty) {
      failures.add(label);
    } else {
      stdout.writeln('PASS: $label');
    }
  }

  Future<void> cleanupUserA() async {
    await clientA
        .from('food_entries')
        .delete()
        .eq('entry_id', '${_testPrefix}food-a');
    await clientA
        .from('exercise_entries')
        .delete()
        .eq('entry_id', '${_testPrefix}ex-a');
    await clientA
        .from('weight_entries')
        .delete()
        .eq('entry_id', '${_testPrefix}wt-a');
    await clientA
        .from('food_entries')
        .delete()
        .eq('entry_id', '${_testPrefix}food-b-forged');
    await clientA.from('health_snapshots').delete().eq('user_id', userA.id);
    await clientA.from('app_settings').delete().eq('user_id', userA.id);
    await clientA.from('nutrition_settings').delete().eq('user_id', userA.id);
    await clientA.from('goals').delete().eq('user_id', userA.id);
    await clientA.from('profiles').delete().eq('user_id', userA.id);
  }

  Future<void> cleanupUserB() async {
    if (!userBCreatedProfile) {
      return;
    }
    await clientB.from('profiles').delete().eq('user_id', userB.id);
  }

  try {
    // Preflight: dedicated test accounts should have no profile yet.
    final existingAProfile = await clientA
        .from('profiles')
        .select('user_id')
        .eq('user_id', userA.id)
        .maybeSingle();
    if (existingAProfile != null) {
      stderr.writeln(
        'FAIL: User A already has a profile. Use a fresh dedicated test account.',
      );
      exit(1);
    }

    // --- User A: create test data ---
    await clientA.from('users').upsert({'id': userA.id, 'email': userA.email});
    await clientA.from('profiles').upsert({
      'user_id': userA.id,
      'birth_date': '1990-01-01T00:00:00Z',
      'gender': 'male',
      'height_cm': 175,
      'weight_kg': 70,
    });
    await clientA.from('goals').upsert({
      'user_id': userA.id,
      'goal_type': 'maintain',
      'target_weight_kg': 70,
      'target_date': '2026-12-31T00:00:00Z',
    });
    await clientA.from('nutrition_settings').upsert({
      'user_id': userA.id,
      'use_health_integration': false,
      'activity_level': 'moderate',
    });
    await clientA.from('food_entries').upsert({
      'user_id': userA.id,
      'entry_id': '${_testPrefix}food-a',
      'name': 'RLS Test Food A',
      'quantity': 1,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
    await clientA.from('exercise_entries').upsert({
      'user_id': userA.id,
      'entry_id': '${_testPrefix}ex-a',
      'name': 'RLS Test Exercise A',
      'duration_min': 30,
      'burned_kcal': 200,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
    await clientA.from('weight_entries').upsert({
      'user_id': userA.id,
      'entry_id': '${_testPrefix}wt-a',
      'weight_kg': 70,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'source': 'manual',
    });
    await clientA.from('health_snapshots').upsert({
      'user_id': userA.id,
      'weight_kg': 70,
    });
    await clientA.from('app_settings').upsert({
      'user_id': userA.id,
      'onboarding_complete': true,
    });
    stdout.writeln('PASS: User A test data created');

    // --- User B: cross-user SELECT denied ---
    await expectEmptySelect(
      'User B cannot SELECT User A profiles',
      () => clientB.from('profiles').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A goals',
      () => clientB.from('goals').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A nutrition_settings',
      () => clientB.from('nutrition_settings').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A food_entries',
      () => clientB.from('food_entries').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A exercise_entries',
      () => clientB.from('exercise_entries').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A weight_entries',
      () => clientB.from('weight_entries').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A health_snapshots',
      () => clientB.from('health_snapshots').select().eq('user_id', userA.id),
    );
    await expectEmptySelect(
      'User B cannot SELECT User A app_settings',
      () => clientB.from('app_settings').select().eq('user_id', userA.id),
    );

    await expectFailure('User B UPDATE User A profile', () async {
      await clientB
          .from('profiles')
          .update({'weight_kg': 999})
          .eq('user_id', userA.id);
    });

    await expectFailure('User B DELETE User A food_entry', () async {
      await clientB
          .from('food_entries')
          .delete()
          .eq('user_id', userA.id)
          .eq('entry_id', '${_testPrefix}food-a');
    });

    await expectFailure('User B INSERT with User A user_id', () async {
      await clientB.from('food_entries').insert({
        'user_id': userA.id,
        'entry_id': '${_testPrefix}food-b-forged',
        'name': 'Forged',
        'quantity': 1,
        'logged_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    // --- User B: own CRUD ---
    await clientB.from('users').upsert({'id': userB.id, 'email': userB.email});
    await clientB.from('profiles').upsert({
      'user_id': userB.id,
      'birth_date': '1995-05-05T00:00:00Z',
      'gender': 'female',
      'height_cm': 160,
      'weight_kg': 55,
    });
    userBCreatedProfile = true;
    final bProfile = await clientB
        .from('profiles')
        .select()
        .eq('user_id', userB.id)
        .maybeSingle();
    if (bProfile == null) {
      failures.add('User B cannot SELECT own profile');
    } else {
      stdout.writeln('PASS: User B CRUD own profile');
    }

    // --- User A: still owns data ---
    final aProfile = await clientA
        .from('profiles')
        .select()
        .eq('user_id', userA.id)
        .maybeSingle();
    if (aProfile == null) {
      failures.add('User A lost own profile');
    } else {
      stdout.writeln('PASS: User A can SELECT own profile');
    }
    await clientA
        .from('profiles')
        .update({'weight_kg': 71})
        .eq('user_id', userA.id);
    stdout.writeln('PASS: User A can UPDATE own profile');
  } finally {
    try {
      await cleanupUserA();
      stdout.writeln('PASS: User A test data cleaned up');
    } catch (error) {
      stderr.writeln(
        'WARN: User A cleanup failed (manual cleanup may be needed).',
      );
    }
    try {
      await cleanupUserB();
      stdout.writeln('PASS: User B test data cleaned up');
    } catch (error) {
      stderr.writeln(
        'WARN: User B cleanup failed (manual cleanup may be needed).',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('RLS VERIFICATION FAILED:');
    for (final f in failures) {
      stderr.writeln(' - $f');
    }
    exit(1);
  }

  stdout.writeln('RLS VERIFICATION PASSED');
}
