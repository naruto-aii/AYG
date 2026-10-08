import '../models/food_unit_type.dart';
import '../models/official_food.dart';
import '../models/saved_food.dart';
import '../repositories/contracts/saved_food_local_store.dart';
import '../repositories/official_food_repository.dart';
import '../utils/food_name_normalizer.dart';
import 'demo_authentication_repository.dart';

/// デモ用の保存済み食品。チェーンの一括取り込みではない。
Future<void> seedDemoSavedFoods(SavedFoodLocalStore store) async {
  final now = DateTime(2026, 10, 8, 8);
  final foods = [
    _saved(
      id: 'demo-onigiri',
      name: '自家製おにぎり',
      unit: FoodUnitType.piece,
      label: '個',
      base: 1,
      kcal: 180,
      protein: 4,
      fat: 1,
      carb: 38,
      now: now,
    ),
    _saved(
      id: 'demo-salad-chicken',
      name: 'サラダチキン',
      unit: FoodUnitType.g,
      label: 'g',
      base: 100,
      kcal: 114,
      protein: 24,
      fat: 1,
      carb: 1,
      now: now,
    ),
  ];
  await store.saveAllPrivate(foods);
}

SavedFood _saved({
  required String id,
  required String name,
  required FoodUnitType unit,
  required String label,
  required double base,
  required double kcal,
  required double protein,
  required double fat,
  required double carb,
  required DateTime now,
}) {
  return SavedFood(
    foodId: id,
    ownerUserId: DemoAuthenticationRepository.userId,
    name: name,
    normalizedName: FoodNameNormalizer.normalize(name),
    baseAmount: base,
    unitType: unit,
    servingUnitLabel: label,
    kcalPerBase: kcal,
    proteinPerBase: protein,
    fatPerBase: fat,
    carbPerBase: carb,
    createdAt: now,
    updatedAt: now,
  );
}

/// 定番の食品だけ。吉野家などの店名では空を返す。
class DemoOfficialFoodRepository implements OfficialFoodRepository {
  static const staples = <OfficialFoodMatch>[
    OfficialFoodMatch(
      foodCode: '01083',
      name: '白米',
      kcal: 168,
      proteinG: 2.5,
      fatG: 0.3,
      carbG: 37.1,
    ),
    OfficialFoodMatch(
      foodCode: '11234',
      name: '鶏むね 皮なし 生',
      kcal: 108,
      proteinG: 23.3,
      fatG: 1.5,
      carbG: 0,
    ),
    OfficialFoodMatch(
      foodCode: '12004',
      name: '鶏卵 全卵 生',
      kcal: 151,
      proteinG: 12.3,
      fatG: 10.3,
      carbG: 0.3,
    ),
  ];

  @override
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return [
      for (final food in staples)
        if (food.name.contains(trimmed) || trimmed.contains(food.name)) food,
    ].take(limit).toList();
  }
}
