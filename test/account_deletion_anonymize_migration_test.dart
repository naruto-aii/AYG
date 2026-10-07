import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path =
      'supabase/migrations/20261007123300_delete_own_account_auth_must_succeed.sql';

  test('anonymized archive drops identity columns and flags developers', () {
    final sql = File(path).readAsStringSync();
    final lower = sql.toLowerCase();
    final tables = RegExp(
      r'create table public\.(anon_[a-z0-9_]+)\s*\((.*?)\);',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(sql).toList();

    expect(tables, isNotEmpty);
    final names = tables.map((match) => match.group(1)).toSet();
    expect(
      names,
      containsAll(const [
        'anon_subjects',
        'anon_food_entries',
        'anon_exercise_entries',
        'anon_weight_entries',
        'anon_alcohol_entries',
        'anon_health_workouts',
        'anon_meal_template_usage',
        'anon_workout_template_usage',
        'anon_food_search_queries',
        'anon_exercise_search_queries',
        'anon_screen_actions',
        'anon_app_events',
        'anon_coach_proposal_logs',
        'anon_plus_funnel_events',
      ]),
    );

    for (final table in tables) {
      final body = table.group(2)!.toLowerCase();
      expect(body, isNot(contains('user_id')), reason: table.group(1));
      expect(body, isNot(contains('install_id')), reason: table.group(1));
      expect(body, isNot(contains('email')), reason: table.group(1));
      expect(body, isNot(contains('memo')), reason: table.group(1));
      expect(body, isNot(contains('notes')), reason: table.group(1));
      expect(body, isNot(contains('device_model')), reason: table.group(1));
      expect(body, isNot(contains('birth_date')), reason: table.group(1));
      expect(body, contains('anon_subject_id'), reason: table.group(1));
    }

    final foodSearch = tables
        .firstWhere((match) => match.group(1) == 'anon_food_search_queries')
        .group(2)!;
    final exerciseSearch = tables
        .firstWhere(
          (match) => match.group(1) == 'anon_exercise_search_queries',
        )
        .group(2)!;
    expect(foodSearch, contains('query_text'));
    expect(exerciseSearch.toLowerCase(), isNot(contains('query_text')));

    expect(
      'v_anon := pg_catalog.gen_random_uuid()'.allMatches(lower).length,
      1,
      reason: 'anon_subject_id is one fresh uuid per deletion',
    );
    expect(lower, isNot(contains('md5(')));
    expect(lower, isNot(contains('anon_subject_id uuid primary key default')));
    expect(lower, contains('v_anon := pg_catalog.gen_random_uuid()'));
    expect(lower, contains("date_trunc('hour'"));
    expect(lower, contains("date_trunc('month'"));
    expect(lower, contains("|| 's'"));
    expect(lower, contains('v_age_band'));
    expect(
      lower,
      contains(
        'v_kpi_excluded := exists (\n    select 1 from kpi.excluded_user_ids x where x.user_id = uid\n  )',
      ),
    );
    expect(
      lower,
      contains(
        'if not exists (select 1 from kpi.excluded_user_ids x where x.user_id = uid) then',
      ),
    );
    expect(lower, contains('where s.kpi_excluded = false'));
    expect(lower, contains('create view kpi.anon_food_entries'));
    expect(lower, contains('create view kpi.anon_app_events'));
    expect(lower, contains('enable row level security'));
    expect(
      lower,
      contains('revoke all on table public.%i from public, anon, authenticated'),
    );
    expect(
      lower,
      contains("raise exception 'delete_own_account: auth deletion failed: %'"),
    );
    expect(lower, isNot(contains('skipped auth.users update')));
    expect(lower, isNot(contains('f.memo')));
    expect(lower, isNot(contains('e.notes')));
    expect(lower, isNot(contains('ev.install_id')));
    expect(lower, isNot(contains('ev.device_model')));
    expect(lower, isNot(contains('c.proposal')));
  });
}
