import '../models/meal_template.dart';
import '../models/official_food.dart';
import '../models/public_food_search_match.dart';
import '../models/saved_food.dart';
import '../repositories/official_food_repository.dart';

/// 食事追加の検索案。保存済み、テンプレート、公開食品、成分表を一つの結果にする。
///
/// 本番の「食品を探す」にはまだ繋がない。レイアウト案の結果と同じ種類を返す。
class UnifiedMealSearch {
  const UnifiedMealSearch({
    required this.searchSaved,
    required this.searchTemplates,
    required this.searchPublic,
    required this.searchCompositionTable,
  });

  final Future<List<SavedFood>> Function(String query) searchSaved;
  final Future<List<MealTemplate>> Function(String query) searchTemplates;
  final Future<List<PublicFoodSearchMatch>> Function(String query) searchPublic;
  final Future<OfficialFoodSearchResult> Function(String query)
  searchCompositionTable;

  static const legacyPublicOnlyLabels = ['公開食品を選ぶ', '公開食品から追加'];

  Future<List<UnifiedMealHit>> search(String query) async {
    final saved = await searchSaved(query);
    final templates = await searchTemplates(query);
    final publicFoods = await searchPublic(query);
    final composition = await searchCompositionTable(query);
    return [
      for (final food in saved)
        UnifiedMealHit(
          kind: UnifiedMealKind.saved,
          id: food.foodId,
          title: food.name,
        ),
      for (final template in templates)
        UnifiedMealHit(
          kind: UnifiedMealKind.template,
          id: template.templateId,
          title: template.name,
        ),
      for (final match in publicFoods)
        UnifiedMealHit(
          kind: UnifiedMealKind.publicFood,
          id: match.food.foodId,
          title: match.food.name,
        ),
      for (final food in composition.matches)
        UnifiedMealHit(
          kind: UnifiedMealKind.compositionTable,
          id: food.foodCode,
          title: food.name,
        ),
    ];
  }
}

enum UnifiedMealKind { saved, template, publicFood, compositionTable }

class UnifiedMealHit {
  const UnifiedMealHit({
    required this.kind,
    required this.id,
    required this.title,
  });

  final UnifiedMealKind kind;
  final String id;
  final String title;

  String get badge => switch (kind) {
    UnifiedMealKind.saved => '保存済み',
    UnifiedMealKind.template => 'テンプレート',
    UnifiedMealKind.publicFood => '公開食品',
    UnifiedMealKind.compositionTable => '成分表',
  };
}
