import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/saved_food/public_food_search_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SavedFood food({required bool ownerDeleted}) {
    return SavedFood(
      foodId: 'food-1',
      ownerUserId: 'owner-1',
      name: '公開ごはん',
      normalizedName: '公開ごはん',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      servingUnitLabel: 'g',
      ownerDeleted: ownerDeleted,
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
    );
  }

  test('creatorLabel is anonymous until the owner is deleted', () {
    expect(food(ownerDeleted: false).creatorLabel, 'ユーザー');
    expect(food(ownerDeleted: true).creatorLabel, '削除済みユーザー');
  });

  testWidgets('search tile shows deleted-user creator', (tester) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PublicFoodSearchResultTile(
            controller: controller,
            match: PublicFoodSearchMatch(
              food: food(ownerDeleted: true),
              goodCount: 0,
              badCount: 0,
              matchType: PublicFoodSearchMatchType.exactName,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('作成者: 削除済みユーザー'), findsOneWidget);
  });
}
