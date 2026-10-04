import 'dart:io';

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261004120000_coach_food_candidates.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/rollback/20261004120000_coach_food_candidates_down.sql',
  ).readAsStringSync();

  test('coach candidates are readable and do not rewrite official foods', () {
    expect(sql, contains('enable row level security'));
    expect(
      sql,
      contains(
        'revoke all on table public.coach_food_candidates from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.coach_food_candidates to authenticated',
      ),
    );
    expect(sql, isNot(contains('grant insert')));
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
    expect(sql.toLowerCase(), isNot(contains('update public.official_foods')));
    expect(sql, isNot(contains('サラダチキン')));
    expect(sql, contains("'01111', '具なしおにぎり', '1個', 100, '中身は米だけ', 3"));
    expect(CoachFoodCatalog.candidates, hasLength(34));
    for (final food in CoachFoodCatalog.candidates) {
      expect(sql, contains("'${food.foodCode}'"));
      expect(sql, contains("'${food.displayName}'"));
      expect(sql, contains("'${food.unitLabel}'"));
    }
  });

  test('rollback drops only the coach table', () {
    expect(
      rollback,
      contains('drop table if exists public.coach_food_candidates'),
    );
    expect(
      rollback,
      isNot(contains('drop table if exists public.official_foods')),
    );
    expect(rollback, isNot(contains('food_entries')));
  });
}
