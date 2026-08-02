import '../models/food_form_suggestion.dart';
import '../models/meal_template.dart';
import '../models/saved_food.dart';
import '../models/workout_template.dart';
import '../data/met_activity_catalog.dart';

/// 検索入力前の候補表示用ランキング。
class SearchSuggestionService {
  const SearchSuggestionService();

  int _usageScore({required int useCount, required DateTime lastUsed}) {
    // useCount を優先し、同率時は lastUsed、最終 tie-break は呼び出し側で名前順。
    return useCount * 1_000_000_000 + lastUsed.microsecondsSinceEpoch;
  }

  DateTime _lastUsedAt({DateTime? lastUsedAt, required DateTime updatedAt}) {
    return lastUsedAt ?? updatedAt;
  }

  List<SavedFood> rankSavedFoodSuggestions(List<SavedFood> foods) {
    final copy = List<SavedFood>.from(foods);
    copy.sort((a, b) {
      final useCompare = b.useCount.compareTo(a.useCount);
      if (useCompare != 0) {
        return useCompare;
      }
      final lastUsedA = a.lastUsedAt ?? a.updatedAt;
      final lastUsedB = b.lastUsedAt ?? b.updatedAt;
      final usedCompare = lastUsedB.compareTo(lastUsedA);
      if (usedCompare != 0) {
        return usedCompare;
      }
      return a.normalizedName.compareTo(b.normalizedName);
    });
    return copy;
  }

  List<MealTemplate> rankMealTemplateSuggestions(List<MealTemplate> templates) {
    final copy = List<MealTemplate>.from(templates);
    copy.sort((a, b) {
      final useCompare = b.useCount.compareTo(a.useCount);
      if (useCompare != 0) {
        return useCompare;
      }
      final lastUsedA = a.lastUsedAt ?? a.updatedAt;
      final lastUsedB = b.lastUsedAt ?? b.updatedAt;
      final usedCompare = lastUsedB.compareTo(lastUsedA);
      if (usedCompare != 0) {
        return usedCompare;
      }
      return a.normalizedName.compareTo(b.normalizedName);
    });
    return copy;
  }

  /// 食事フォーム向け: 保存済み食品と食事テンプレートを owner 内でランキング。
  List<FoodFormSuggestion> rankFoodFormSuggestions({
    required List<SavedFood> foods,
    required List<MealTemplate> templates,
    required Map<String, int> templateItemCounts,
  }) {
    final rankedFoods = rankSavedFoodSuggestions(foods);
    final rankedTemplates = rankMealTemplateSuggestions(templates);

    final suggestions = <FoodFormSuggestion>[
      ...rankedFoods.map(SavedFoodFormSuggestion.new),
      ...rankedTemplates.map(
        (template) => MealTemplateFormSuggestion(
          template,
          itemCount: templateItemCounts[template.templateId] ?? 0,
        ),
      ),
    ];

    suggestions.sort((a, b) {
      final scoreA = switch (a) {
        SavedFoodFormSuggestion(:final food) => _usageScore(
          useCount: food.useCount,
          lastUsed: _lastUsedAt(
            lastUsedAt: food.lastUsedAt,
            updatedAt: food.updatedAt,
          ),
        ),
        MealTemplateFormSuggestion(:final template) => _usageScore(
          useCount: template.useCount,
          lastUsed: _lastUsedAt(
            lastUsedAt: template.lastUsedAt,
            updatedAt: template.updatedAt,
          ),
        ),
      };
      final scoreB = switch (b) {
        SavedFoodFormSuggestion(:final food) => _usageScore(
          useCount: food.useCount,
          lastUsed: _lastUsedAt(
            lastUsedAt: food.lastUsedAt,
            updatedAt: food.updatedAt,
          ),
        ),
        MealTemplateFormSuggestion(:final template) => _usageScore(
          useCount: template.useCount,
          lastUsed: _lastUsedAt(
            lastUsedAt: template.lastUsedAt,
            updatedAt: template.updatedAt,
          ),
        ),
      };
      final compare = scoreB.compareTo(scoreA);
      if (compare != 0) {
        return compare;
      }
      final nameA = switch (a) {
        SavedFoodFormSuggestion(:final food) => food.normalizedName,
        MealTemplateFormSuggestion(:final template) => template.normalizedName,
      };
      final nameB = switch (b) {
        SavedFoodFormSuggestion(:final food) => food.normalizedName,
        MealTemplateFormSuggestion(:final template) => template.normalizedName,
      };
      return nameA.compareTo(nameB);
    });

    return suggestions;
  }

  List<WorkoutTemplate> rankWorkoutTemplateSuggestions(
    List<WorkoutTemplate> templates,
  ) {
    final copy = List<WorkoutTemplate>.from(templates);
    copy.sort((a, b) {
      final useCompare = b.useCount.compareTo(a.useCount);
      if (useCompare != 0) {
        return useCompare;
      }
      final lastUsedA = a.lastUsedAt ?? a.updatedAt;
      final lastUsedB = b.lastUsedAt ?? b.updatedAt;
      final usedCompare = lastUsedB.compareTo(lastUsedA);
      if (usedCompare != 0) {
        return usedCompare;
      }
      return a.normalizedName.compareTo(b.normalizedName);
    });
    return copy;
  }

  /// 新規ユーザー向けの安全な既定運動候補。
  List<MetActivityDefinition> defaultExerciseActivities() {
    return MetActivityCatalog.activities
        .where((activity) => activity.id != 'custom')
        .toList();
  }
}
