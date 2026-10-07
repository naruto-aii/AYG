import 'dart:io';

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261007074302_personal_coach_food_roles.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/rollback/20261007074302_personal_coach_food_roles_down.sql',
  ).readAsStringSync();

  test('personal coach migration only adds columns and the 66 foods', () {
    final lower = sql.toLowerCase();
    expect(lower, isNot(contains('drop ')));
    expect(lower, isNot(contains('delete ')));
    expect(lower, isNot(contains('truncate')));
    expect(sql, contains('add column if not exists coach_role'));
    expect(sql, contains('is_active = false'));
    expect(sql, contains('パーソナルコーチ (β)'));
    expect(CoachFoodCatalog.candidates, hasLength(66));
    final inserted = RegExp(
      r"\('(\d{5})'",
    ).allMatches(sql).map((match) => match.group(1)!).toSet();
    expect(inserted, CoachFoodCatalog.codes.toSet());
    for (final food in CoachFoodCatalog.candidates) {
      expect(sql, contains("'${food.foodCode}', '${food.displayName}'"));
      expect(sql, contains("'${food.role.name}', '${food.subrole.name}'"));
      expect(food.portions, isNotEmpty);
    }
    const green = {
      '06268',
      '06264',
      '06087',
      '06182',
      '06183',
      '06215',
      '06049',
      '06100',
    };
    const starchy = {'06049', '06176', '02018', '02007'};
    const bread = {'01026', '01034', '01039', '01128'};
    for (final food in CoachFoodCatalog.candidates) {
      expect(food.isGreenYellowVegetable, green.contains(food.foodCode));
      expect(food.isStarchySide, starchy.contains(food.foodCode));
      expect(food.isBreadOrNoodle, bread.contains(food.foodCode));
    }
  });

  test('rollback removes the new columns and not the rows', () {
    expect(rollback, contains('drop column if exists coach_role'));
    expect(rollback, contains('drop column if exists is_active'));
    expect(rollback, isNot(contains('drop table')));
    expect(rollback, isNot(contains('delete from')));
    expect(rollback, isNot(contains('truncate')));
  });
}
