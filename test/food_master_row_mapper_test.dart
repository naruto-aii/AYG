import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_report.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/moderation_status.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodMasterRowMapper.savedFood', () {
    test('round trip preserves core fields', () {
      final food = SavedFood(
        foodId: 'f1',
        ownerUserId: 'u1',
        name: 'Rice',
        normalizedName: 'rice',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        servingUnitLabel: 'g',
        visibility: FoodVisibility.private,
        status: FoodStatus.active,
        moderationStatus: ModerationStatus.none,
        kcalPerBase: 120,
        sourceType: FoodSourceType.manual,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final row = FoodMasterRowMapper.savedFoodToRow(food, userId: 'u1');
      final parsed = FoodMasterRowMapper.savedFoodFromRow(row);

      expect(parsed.foodId, food.foodId);
      expect(parsed.ownerUserId, 'u1');
      expect(parsed.baseAmount, 100);
      expect(parsed.unitType, FoodUnitType.g);
      expect(parsed.servingUnitLabel, 'g');
      expect(parsed.visibility, FoodVisibility.private);
      expect(parsed.version, 1);
    });

    test('round trip preserves version', () {
      final food = SavedFood(
        foodId: 'f2',
        ownerUserId: 'u1',
        name: 'Public Rice',
        normalizedName: 'public rice',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        visibility: FoodVisibility.public,
        version: 4,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final row = FoodMasterRowMapper.savedFoodToRow(food, userId: 'u1');
      final parsed = FoodMasterRowMapper.savedFoodFromRow(row);

      expect(parsed.version, 4);
    });
  });

  group('FoodMasterRowMapper.foodEntry', () {
    test('legacy row uses quantity fallback', () {
      final entry = FoodMasterRowMapper.foodEntryFromRow({
        'entry_id': 'e1',
        'name': 'legacy rice',
        'kcal_per_unit': 200,
        'quantity': 2,
        'logged_at': '2026-01-01T00:00:00Z',
      });

      expect(entry.quantity, 2);
      expect(entry.baseAmount, 1);
      expect(entry.consumedAmount, 2);
      expect(entry.sourceType, FoodEntrySource.manual);
      expect(entry.savedFoodId, isNull);
    });

    test('new row round trip keeps consumption model and legacy quantity', () {
      final entry = FoodEntry(
        id: 'e2',
        name: 'Chicken',
        kcalPerBase: 150,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 150,
        sourceType: FoodEntrySource.savedFood,
        savedFoodId: 'f1',
        sourceFoodOwnerUserId: 'owner1',
        mealGroupId: 'breakfast',
        mealGroupName: 'Breakfast',
        sortOrder: 1,
        loggedAt: DateTime.utc(2026, 1, 3),
      );

      final row = FoodMasterRowMapper.foodEntryToRow(entry, userId: 'u1');
      final parsed = FoodMasterRowMapper.foodEntryFromRow(row);

      expect(parsed.id, entry.id);
      expect(parsed.quantity, entry.quantity);
      expect(parsed.baseAmount, 100);
      expect(parsed.consumedAmount, 150);
      expect(parsed.savedFoodId, 'f1');
      expect(parsed.mealGroupId, 'breakfast');
      expect(row['quantity'], entry.quantity);
    });
  });

  group('FoodMasterRowMapper.mealTemplate', () {
    test('item round trip preserves snapshot and sort order', () {
      final item = MealTemplateItem(
        itemId: 'i1',
        savedFoodId: 'f1',
        sourceOwnerUserId: 'owner',
        name: 'Snapshot',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 120,
        sortOrder: 2,
        itemDependencyStatus: ItemDependencyStatus.sourceDeleted,
        snapshotSavedAt: DateTime.utc(2026, 2, 1),
      );

      final row = FoodMasterRowMapper.mealTemplateItemToRow(
        item,
        userId: 'u1',
        templateId: 't1',
      );
      final parsed = FoodMasterRowMapper.mealTemplateItemFromRow(row);

      expect(parsed.itemId, 'i1');
      expect(parsed.sortOrder, 2);
      expect(parsed.itemDependencyStatus, ItemDependencyStatus.sourceDeleted);
      expect(parsed.name, 'Snapshot');
    });
  });

  group('FoodMasterRowMapper.ratings and reports', () {
    test('rating summary and report parse', () {
      final summary = FoodMasterRowMapper.ratingSummaryFromRow({
        'food_owner_user_id': 'o1',
        'food_id': 'f1',
        'good_count': 3,
        'bad_count': 1,
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(summary.goodCount, 3);

      final report = FoodMasterRowMapper.foodReportFromRow({
        'report_id': 'r1',
        'reporter_user_id': 'u2',
        'target_food_owner_user_id': 'o1',
        'target_food_id': 'f1',
        'reason_code': 'spam',
        'detail_text': null,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(report.reasonCode, FoodReportReasonCode.spam);
    });
  });
}
