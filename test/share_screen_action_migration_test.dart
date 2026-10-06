import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String up;
  late String down;

  setUpAll(() {
    up = File(
      'supabase/migrations/20261006130000_app_screen_action_share.sql',
    ).readAsStringSync();
    down = File(
      'supabase/rollback/20261006130000_app_screen_action_share_down.sql',
    ).readAsStringSync();
  });

  test('records share kinds on the existing table and keeps RLS', () {
    expect(up, contains('share_meal'));
    expect(up, contains('share_streak'));
    expect(up, contains('share_weight'));
    expect(up, contains('enable row level security'));
    expect(up, isNot(contains('disable row level security')));
    expect(up, isNot(contains('create table')));
    expect(up, isNot(contains('add column')));
    expect(up.toLowerCase(), isNot(contains('grant ')));
    expect(up, isNot(contains('weight_kg')));
    expect(up, isNot(contains('kcal')));
    expect(up, contains('数値は入れない'));
  });

  test('rollback removes only share rows and restores the old actions', () {
    expect(
      down,
      contains("action in ('share_meal', 'share_streak', 'share_weight')"),
    );
    expect(down, contains("action in ('open', 'select', 'meal_button')"));
    expect(down, contains('enable row level security'));
    expect(down, isNot(contains('drop table')));
    expect(down, isNot(contains('truncate')));
    expect(down, isNot(contains('food_entries')));
    expect(down, isNot(contains('weight_entries')));
  });
}
