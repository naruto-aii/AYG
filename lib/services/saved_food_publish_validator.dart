import '../constants/app_strings.dart';
import '../models/food_source_type.dart';
import '../models/food_status.dart';
import '../models/moderation_status.dart';
import '../models/saved_food.dart';
import '../models/saved_food_publish_validation.dart';
import '../services/macro_nutrition_consistency_policy.dart';
import '../services/nutrition_value_calculator.dart';
import '../utils/food_name_normalizer.dart';

/// 公開前のクライアント側バリデーション。
class SavedFoodPublishValidator {
  const SavedFoodPublishValidator();

  SavedFoodPublishValidationResult validate({
    required SavedFood food,
    required String ownerUserId,
  }) {
    final errors = <String>[];

    if (food.ownerUserId != ownerUserId) {
      errors.add('自分の食品のみ公開できます');
    }
    if (food.visibility.name == 'public') {
      errors.add('すでに公開されています');
    }
    if (food.status != FoodStatus.active || food.deletedAt != null) {
      errors.add('削除済みまたは非アクティブな食品は公開できません');
    }
    if (!_isModerationPublishable(food.moderationStatus)) {
      errors.add('モデレーション状態により公開できません');
    }
    if (food.name.trim().isEmpty) {
      errors.add('食品名を入力してください');
    }
    final normalized = FoodNameNormalizer.normalize(food.name);
    if (normalized.isEmpty) {
      errors.add('食品名が無効です');
    }
    if (food.baseAmount <= 0) {
      errors.add('基準量は0より大きい値を入力してください');
    }
    if (!food.baseServingDefined) {
      errors.add('基準数量と基準単位を入力してください');
    }

    final kcal = food.kcalPerBase;
    final protein = food.proteinPerBase;
    final fat = food.fatPerBase;
    final carb = food.carbPerBase;
    if (kcal == null || protein == null || fat == null || carb == null) {
      errors.add(AppStrings.macroNutrientsRequired);
    } else {
      if (kcal < 0 || protein < 0 || fat < 0 || carb < 0) {
        errors.add('栄養素に負の値は設定できません');
      }
    }

    bool? manualMacroConsistent;
    if (food.sourceType == FoodSourceType.manual &&
        kcal != null &&
        protein != null &&
        fat != null &&
        carb != null) {
      manualMacroConsistent = NutritionValueCalculator.isConsistent(
        kcal: kcal,
        protein: protein,
        fat: fat,
        carb: carb,
      );
      if (!manualMacroConsistent) {
        errors.add(AppStrings.macroManualConsistencyRequired);
      }
    }

    return SavedFoodPublishValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      manualMacroConsistent: manualMacroConsistent,
    );
  }

  bool _isModerationPublishable(ModerationStatus status) {
    return switch (status) {
      ModerationStatus.none ||
      ModerationStatus.reported ||
      ModerationStatus.underReview => true,
      _ => false,
    };
  }

  MacroNutritionConsistencyMode consistencyModeFor(FoodSourceType sourceType) {
    return switch (sourceType) {
      FoodSourceType.manual => MacroNutritionConsistencyMode.manual,
      FoodSourceType.openFoodFacts ||
      FoodSourceType.openFoodFactsDerived ||
      FoodSourceType.copied => MacroNutritionConsistencyMode.preserveExternal,
    };
  }
}
