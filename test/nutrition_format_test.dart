import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/food_entry.dart';
import 'package:ayg/utils/nutrition_format.dart';

void main() {
  group('normalizeEan13Barcode', () {
    test('returns 13-digit code when input is valid EAN-13', () {
      expect(normalizeEan13Barcode('3017620422003'), '3017620422003');
    });

    test('strips non-digit characters', () {
      expect(normalizeEan13Barcode('301-7620-42200-3'), '3017620422003');
    });

    test('returns null for non-13-digit input', () {
      expect(normalizeEan13Barcode('1234567'), isNull);
      expect(normalizeEan13Barcode(''), isNull);
      expect(normalizeEan13Barcode(null), isNull);
    });
  });

  group('formatNullableNutrient', () {
    test('returns -- for null', () {
      expect(formatNullableNutrient(null), '--');
    });

    test('formats numeric values', () {
      expect(formatNullableNutrient(500), '500');
      expect(formatNullableNutrient(12.5, fractionDigits: 1), '12.5');
    });
  });

  group('FoodEntry nullable nutrition', () {
    test('totals treat null per-unit values as zero', () {
      final entry = FoodEntry(
        id: 'food-null',
        name: '名前のみ',
        quantity: 2,
        loggedAt: _fixedTime,
      );

      expect(entry.totalKcal, 0);
      expect(entry.totalProteinG, 0);
      expect(entry.totalFatG, 0);
      expect(entry.totalCarbG, 0);
    });

    test('totals multiply non-null per-unit values by quantity', () {
      final entry = FoodEntry(
        id: 'food-partial',
        name: '部分入力',
        kcalPerUnit: 100,
        quantity: 2,
        loggedAt: _fixedTime,
      );

      expect(entry.totalKcal, 200);
      expect(entry.totalProteinG, 0);
    });
  });
}

final _fixedTime = DateTime(2026, 1, 1);
