import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String up;
  late String down;

  setUpAll(() {
    up = File(
      'supabase/migrations/20261003200000_apple_token_revoke_on_delete.sql',
    ).readAsStringSync();
    down = File(
      'supabase/rollback/20261003200000_apple_token_revoke_on_delete_down.sql',
    ).readAsStringSync();
  });

  test('stores the apple refresh token outside the client api', () {
    expect(up, contains('internal.apple_refresh_tokens'));
    expect(up, contains('revoke all on table internal.apple_refresh_tokens'));
    expect(up, contains('grant execute on function public.read_apple_refresh_token(uuid) to service_role'));
    expect(
      up,
      isNot(contains('grant select on table internal.apple_refresh_tokens')),
    );
    expect(up, contains('drop function if exists public.delete_own_account()'));
    expect(
      up,
      contains(
        'create or replace function public.delete_own_account(p_user_id uuid)',
      ),
    );
    expect(up, contains("auth.role() is distinct from 'service_role'"));
    for (final table in [
      'health_workouts',
      'calonavi_plus_entitlements',
      'food_search_queries',
      'exercise_search_queries',
      'app_screen_actions',
    ]) {
      expect(up, contains('delete from public.$table where user_id'));
    }
  });

  test('does not drop existing meals or purchase rows when applied', () {
    final statements = _sqlStatements(up);
    expect(statements, isNot(contains('truncate')));
    expect(statements, isNot(contains('drop table if exists public.food_entries')));
    expect(statements, isNot(contains('drop table if exists public.profiles')));
    expect(statements, isNot(contains('drop table if exists public.health_workouts')));
    expect(statements, isNot(contains('receipt')));
  });

  test('rollback restores client deletion and drops only the token table', () {
    expect(down, contains('drop table if exists internal.apple_refresh_tokens'));
    expect(down, contains('drop function if exists public.delete_own_account(uuid)'));
    expect(down, contains('grant execute on function public.delete_own_account() to authenticated'));
    expect(down, contains('delete from public.health_workouts where user_id'));
    final statements = _sqlStatements(down);
    expect(statements, isNot(contains('truncate')));
    expect(statements, isNot(contains('drop table if exists public.food_entries')));
    expect(statements, isNot(contains('drop table if exists public.health_workouts')));
    expect(statements, isNot(contains('drop table if exists public.profiles')));
  });
}

String _sqlStatements(String sql) {
  return sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
}
