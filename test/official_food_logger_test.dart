import 'package:ayg/constants/official_food_copy.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/services/official_food_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const match = OfficialFoodMatch(
    foodCode: '01088',
    name: 'こめ　［水稲めし］　精白米　うるち米',
    kcal: 156,
    proteinG: 2.5,
    fatG: 0.3,
    carbG: 37.1,
    matchedAlias: 'ご飯',
  );
  const logger = OfficialFoodLogger();

  test('scales 100g values by the eaten amount', () {
    final entry = logger.buildEntry(
      match: match,
      entryId: 'entry-1',
      grams: 150,
      loggedAt: DateTime.utc(2026, 9, 28),
    );
    expect(entry.baseAmount, 100);
    expect(entry.consumedAmount, 150);
    expect(entry.unitType, FoodUnitType.g);
    expect(entry.name, 'ご飯');
    expect(entry.totalKcal, 234);
    expect(entry.sourceType, FoodEntrySource.mextSfct);
    expect(entry.officialFoodCode, '01088');
    expect(entry.officialFoodName, 'こめ　［水稲めし］　精白米　うるち米');
  });

  test('private copy keeps the food code and official name', () {
    final draft = logger.buildDraft(match);
    expect(draft.sourceType, FoodSourceType.mextSfct);
    expect(draft.supplementaryWeight, isNull);
    expect(draft.officialFoodCode, '01088');
    expect(draft.officialFoodName, 'こめ　［水稲めし］　精白米　うるち米');
    expect(draft.sourceAttribution, OfficialFoodCopy.fullAttribution);
    expect(draft.brand, 'こめ　［水稲めし］　精白米　うるち米');
    expect(draft.name, 'ご飯');
    expect(draft.baseAmount, 100);
    expect(draft.servingUnitLabel, 'g');
  });
}
