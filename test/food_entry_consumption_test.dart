import 'package:ayg/database/entity_mapper.dart';
import 'package:ayg/database/schemas.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/utils/base_amount_normalizer.dart';
import 'package:ayg/utils/food_entry_legacy_migration.dart';
import 'package:ayg/utils/food_name_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodEntry consumption model', () {
    test('legacy quantity maps to consumedAmount with baseAmount 1', () {
      final entry = FoodEntry(
        id: '1',
        name: 'rice',
        kcalPerUnit: 200,
        quantity: 2,
        loggedAt: DateTime(2026, 1, 1),
      );

      expect(entry.baseAmount, 1);
      expect(entry.unitType, FoodUnitType.serving);
      expect(entry.consumedAmount, 2);
      expect(entry.quantity, 2);
      expect(entry.multiplier, 2);
      expect(entry.totalKcal, 400);
    });

    test('quantity getter equals consumedAmount / baseAmount', () {
      final entry = FoodEntry(
        id: 'fraction',
        name: 'test',
        kcalPerBase: 100,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 37.5,
        loggedAt: DateTime(2026, 1, 1),
      );

      expect(entry.quantity, 0.375);
      expect(entry.totalKcal, 37.5);
    });

    test('explicit baseAmount and consumedAmount', () {
      final entry = FoodEntry(
        id: '2',
        name: 'cabbage',
        kcalPerBase: 50,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 150,
        loggedAt: DateTime(2026, 1, 1),
      );

      expect(entry.multiplier, 1.5);
      expect(entry.totalKcal, 75);
    });

    test('legacy migration preserves totals', () {
      const legacyKcal = 165.0;
      const legacyQty = 2.5;

      final legacy = FoodEntryLegacyMigration.fromLegacyQuantity(
        id: '3',
        name: 'legacy',
        kcalPerUnit: legacyKcal,
        quantity: legacyQty,
        loggedAt: DateTime(2026, 1, 1),
      );

      final beforeTotal = legacyKcal * legacyQty;
      expect(legacy.totalKcal, beforeTotal);
      expect(legacy.quantity, legacyQty);
    });

    test('nullable nutrition totals treat null as zero', () {
      final entry = FoodEntry(
        id: '4',
        name: 'partial',
        kcalPerUnit: 100,
        quantity: 2,
        loggedAt: DateTime(2026, 1, 1),
      );

      expect(entry.totalProteinG, 0);
      expect(entry.totalKcal, 200);
    });

    test('rejects zero consumedAmount at construction', () {
      expect(
        () => FoodEntry(
          id: 'zero',
          name: 'zero',
          quantity: 0,
          loggedAt: DateTime(2026, 1, 1),
        ),
        throwsAssertionError,
      );
    });

    test('copyWith preserves consumption fields for edit flow', () {
      final original = FoodEntry(
        id: 'edit',
        name: 'apple',
        kcalPerUnit: 52,
        quantity: 1.5,
        loggedAt: DateTime(2026, 1, 1),
      );

      final edited = original.copyWith(name: 'apple edited', consumedAmount: 2);

      expect(edited.name, 'apple edited');
      expect(edited.consumedAmount, 2);
      expect(edited.totalKcal, 104);
    });
  });

  group('EntityMapper legacy Isar roundtrip', () {
    test('preserves totals through entity roundtrip', () {
      final original = FoodEntry(
        id: 'isar-1',
        name: 'legacy row',
        kcalPerUnit: 120,
        proteinPerUnit: 5.5,
        quantity: 2.25,
        loggedAt: DateTime(2026, 3, 1, 12),
      );

      final entity = EntityMapper.toFoodEntryEntity(original);
      final restored = EntityMapper.fromFoodEntryEntity(entity);

      expect(restored.baseAmount, 1);
      expect(restored.unitType, FoodUnitType.serving);
      expect(restored.consumedAmount, 2.25);
      expect(restored.totalKcal, original.totalKcal);
      expect(restored.totalProteinG, original.totalProteinG);
      expect(entity.quantity, 2.25);
    });

    test('simulates reading old local DB schema with quantity only', () {
      final entity = FoodEntryEntity()
        ..entryId = 'old'
        ..name = 'stored'
        ..kcalPerUnit = 80
        ..quantity = 3
        ..loggedAt = DateTime(2025, 12, 1);

      final entry = EntityMapper.fromFoodEntryEntity(entity);

      expect(entry.consumedAmount, 3);
      expect(entry.baseAmount, 1);
      expect(entry.totalKcal, 240);
    });
  });

  group('Supabase food_entries sync compatibility', () {
    test('pull row map and push payload keep quantity semantics', () {
      final row = {
        'entry_id': 'remote-1',
        'name': 'remote food',
        'kcal_per_unit': 150,
        'protein_per_unit': null,
        'fat_per_unit': 4.5,
        'carb_per_unit': 20,
        'quantity': 1.75,
        'logged_at': '2026-01-15T08:30:00.000Z',
      };

      final pulled = FoodEntry(
        id: row['entry_id'] as String,
        name: row['name'] as String,
        kcalPerUnit: (row['kcal_per_unit'] as num?)?.toDouble(),
        proteinPerUnit: (row['protein_per_unit'] as num?)?.toDouble(),
        fatPerUnit: (row['fat_per_unit'] as num?)?.toDouble(),
        carbPerUnit: (row['carb_per_unit'] as num?)?.toDouble(),
        quantity: (row['quantity'] as num).toDouble(),
        loggedAt: DateTime.parse(row['logged_at'] as String),
      );

      final pushPayload = {
        'entry_id': pulled.id,
        'name': pulled.name,
        'kcal_per_unit': pulled.kcalPerUnit,
        'protein_per_unit': pulled.proteinPerUnit,
        'fat_per_unit': pulled.fatPerUnit,
        'carb_per_unit': pulled.carbPerUnit,
        'quantity': pulled.quantity,
        'logged_at': pulled.loggedAt.toIso8601String(),
      };

      expect(pulled.consumedAmount, 1.75);
      expect(pulled.totalKcal, 150 * 1.75);
      expect(pushPayload['quantity'], 1.75);
      expect(pushPayload['kcal_per_unit'], 150);
    });
  });

  group('SavedFood', () {
    test('normalizedForSave rounds baseAmount to 4 decimals', () {
      final food = SavedFood(
        foodId: 'f1',
        ownerUserId: 'u1',
        name: '  Cabbage  ',
        normalizedName: 'old',
        baseAmount: 200.00009,
        unitType: FoodUnitType.g,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final normalized = food.normalizedForSave();
      expect(normalized.baseAmount, BaseAmountNormalizer.normalize(200.00009));
      expect(
        normalized.normalizedName,
        FoodNameNormalizer.normalize('  Cabbage  '),
      );
    });
  });

  group('BaseAmountNormalizer', () {
    test('treats 200 and 200.0 as same normalized value', () {
      expect(
        BaseAmountNormalizer.normalize(200),
        BaseAmountNormalizer.normalize(200.0),
      );
      expect(BaseAmountNormalizer.normalize(200), 200);
    });
  });
}
