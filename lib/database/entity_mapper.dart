import '../database/schemas.dart';
import '../models/activity_level.dart';
import '../models/alcohol_entry.dart';
import '../models/app_settings.dart';
import '../models/exercise_calculation_source.dart';
import '../models/exercise_category.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_source_type.dart';
import '../models/food_status.dart';
import '../models/food_unit_type.dart';
import '../models/food_visibility.dart';
import '../models/calculation/goal_pace.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/meal_template.dart';
import '../models/moderation_status.dart';
import '../models/nutrition_settings.dart';
import '../models/saved_food.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../models/workout_template.dart';
import 'entity_enum_codec.dart';

class EntityMapper {
  const EntityMapper._();

  static UserProfileEntity toUserProfileEntity(UserProfile profile) {
    return UserProfileEntity()
      ..birthDate = profile.birthDate
      ..genderIndex = profile.gender.index
      ..heightCm = profile.heightCm
      ..weightKg = profile.weightKg;
  }

  static UserProfile fromUserProfileEntity(UserProfileEntity entity) {
    return UserProfile(
      birthDate: entity.birthDate,
      gender: Gender.values[entity.genderIndex],
      heightCm: entity.heightCm,
      weightKg: entity.weightKg,
    );
  }

  static GoalEntity toGoalEntity(Goal goal) {
    return GoalEntity()
      ..goalTypeIndex = goal.type.index
      ..targetWeightKg = goal.targetWeightKg
      ..targetDate = goal.targetDate
      ..goalPaceIndex = goal.goalPace.index;
  }

  static Goal fromGoalEntity(GoalEntity entity) {
    return Goal(
      type: GoalType.values[entity.goalTypeIndex],
      targetWeightKg: entity.targetWeightKg,
      targetDate: entity.targetDate,
      goalPace: entity.goalPaceIndex == null
          ? GoalPace.standard
          : GoalPace.values[entity.goalPaceIndex!],
    );
  }

  static NutritionSettingsEntity toNutritionSettingsEntity(
    NutritionSettings settings,
  ) {
    return NutritionSettingsEntity()
      ..useHealthIntegration = settings.useHealthIntegration
      ..activityLevelIndex = settings.activityLevel?.index;
  }

  static NutritionSettings fromNutritionSettingsEntity(
    NutritionSettingsEntity entity,
  ) {
    return NutritionSettings(
      useHealthIntegration: entity.useHealthIntegration,
      activityLevel: entity.activityLevelIndex == null
          ? null
          : ActivityLevel.values[entity.activityLevelIndex!],
    );
  }

  static FoodEntryEntity toFoodEntryEntity(FoodEntry entry) {
    return FoodEntryEntity()
      ..entryId = entry.id
      ..name = entry.name
      ..kcalPerUnit = entry.kcalPerBase
      ..proteinPerUnit = entry.proteinPerBase
      ..fatPerUnit = entry.fatPerBase
      ..carbPerUnit = entry.carbPerBase
      ..quantity = entry.quantity
      ..loggedAt = entry.loggedAt
      ..baseAmount = entry.baseAmount
      ..unitTypeIndex = EntityEnumCodec.foodUnitTypeIndex(entry.unitType)
      ..consumedAmount = entry.consumedAmount
      ..sourceTypeIndex = EntityEnumCodec.foodEntrySourceIndex(entry.sourceType)
      ..savedFoodId = entry.savedFoodId
      ..sourceFoodOwnerUserId = entry.sourceFoodOwnerUserId
      ..sourceSavedFoodVersion = entry.sourceSavedFoodVersion
      ..mealGroupId = entry.mealGroupId
      ..mealGroupName = entry.mealGroupName
      ..sortOrder = entry.sortOrder;
  }

  static FoodEntry fromFoodEntryEntity(FoodEntryEntity entity) {
    final baseAmount = entity.baseAmount ?? 1;
    final consumedAmount = entity.consumedAmount ?? entity.quantity;
    final unitType = EntityEnumCodec.foodUnitTypeFromIndex(
      entity.unitTypeIndex,
    );

    return FoodEntry(
      id: entity.entryId,
      name: entity.name,
      kcalPerBase: entity.kcalPerUnit,
      proteinPerBase: entity.proteinPerUnit,
      fatPerBase: entity.fatPerUnit,
      carbPerBase: entity.carbPerUnit,
      baseAmount: baseAmount,
      unitType: unitType,
      consumedAmount: consumedAmount,
      sourceType: EntityEnumCodec.foodEntrySourceFromIndex(
        entity.sourceTypeIndex,
      ),
      savedFoodId: entity.savedFoodId,
      sourceFoodOwnerUserId: entity.sourceFoodOwnerUserId,
      sourceSavedFoodVersion: entity.sourceSavedFoodVersion,
      mealGroupId: entity.mealGroupId,
      mealGroupName: entity.mealGroupName,
      sortOrder: entity.sortOrder,
      loggedAt: entity.loggedAt,
    );
  }

  static SavedFoodEntity toSavedFoodEntity(SavedFood food) {
    return SavedFoodEntity()
      ..foodId = food.foodId
      ..ownerUserId = food.ownerUserId
      ..normalizedName = food.normalizedName
      ..visibilityIndex = EntityEnumCodec.foodVisibilityIndex(food.visibility)
      ..statusIndex = EntityEnumCodec.foodStatusIndex(food.status)
      ..moderationStatusIndex = EntityEnumCodec.moderationStatusIndex(
        food.moderationStatus,
      )
      ..name = food.name
      ..baseAmount = food.baseAmount
      ..unitTypeIndex = EntityEnumCodec.foodUnitTypeIndex(food.unitType)
      ..servingUnitLabel = food.servingUnitLabel
      ..kcalPerBase = food.kcalPerBase
      ..proteinPerBase = food.proteinPerBase
      ..fatPerBase = food.fatPerBase
      ..carbPerBase = food.carbPerBase
      ..sourceTypeIndex = EntityEnumCodec.foodSourceTypeIndex(food.sourceType)
      ..barcode = food.barcode
      ..brand = food.brand
      ..supplementaryWeight = food.supplementaryWeight
      ..copiedFromFoodId = food.copiedFromFoodId
      ..copiedFromOwnerUserId = food.copiedFromOwnerUserId
      ..useCount = food.useCount
      ..lastUsedAt = food.lastUsedAt
      ..reportCount = food.reportCount
      ..version = food.version
      ..createdAt = food.createdAt
      ..updatedAt = food.updatedAt
      ..deletedAt = food.deletedAt;
  }

  static SavedFood fromSavedFoodEntity(SavedFoodEntity entity) {
    return SavedFood(
      foodId: entity.foodId,
      ownerUserId: entity.ownerUserId,
      normalizedName: entity.normalizedName,
      visibility: EntityEnumCodec.foodVisibilityFromIndex(
        entity.visibilityIndex,
      ),
      status: EntityEnumCodec.foodStatusFromIndex(entity.statusIndex),
      moderationStatus: EntityEnumCodec.moderationStatusFromIndex(
        entity.moderationStatusIndex,
      ),
      name: entity.name,
      baseAmount: entity.baseAmount,
      unitType: EntityEnumCodec.foodUnitTypeFromIndex(entity.unitTypeIndex),
      servingUnitLabel: entity.servingUnitLabel,
      kcalPerBase: entity.kcalPerBase,
      proteinPerBase: entity.proteinPerBase,
      fatPerBase: entity.fatPerBase,
      carbPerBase: entity.carbPerBase,
      sourceType: EntityEnumCodec.foodSourceTypeFromIndex(
        entity.sourceTypeIndex,
      ),
      barcode: entity.barcode,
      brand: entity.brand,
      supplementaryWeight: entity.supplementaryWeight,
      copiedFromFoodId: entity.copiedFromFoodId,
      copiedFromOwnerUserId: entity.copiedFromOwnerUserId,
      useCount: entity.useCount,
      lastUsedAt: entity.lastUsedAt,
      reportCount: entity.reportCount,
      version: entity.version,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  static MealTemplateEntity toMealTemplateEntity(MealTemplate template) {
    return MealTemplateEntity()
      ..templateId = template.templateId
      ..ownerUserId = template.ownerUserId
      ..normalizedName = template.normalizedName
      ..visibilityIndex = EntityEnumCodec.foodVisibilityIndex(
        template.visibility,
      )
      ..statusIndex = EntityEnumCodec.templateStatusIndex(template.status)
      ..name = template.name
      ..totalKcal = template.totalKcal
      ..totalProteinG = template.totalProteinG
      ..totalFatG = template.totalFatG
      ..totalCarbG = template.totalCarbG
      ..dependencyStatusIndex = EntityEnumCodec.templateDependencyStatusIndex(
        template.dependencyStatus,
      )
      ..lastValidatedAt = template.lastValidatedAt
      ..useCount = template.useCount
      ..lastUsedAt = template.lastUsedAt
      ..createdAt = template.createdAt
      ..updatedAt = template.updatedAt
      ..deletedAt = template.deletedAt;
  }

  static MealTemplate fromMealTemplateEntity(MealTemplateEntity entity) {
    return MealTemplate(
      templateId: entity.templateId,
      ownerUserId: entity.ownerUserId,
      normalizedName: entity.normalizedName,
      visibility: EntityEnumCodec.foodVisibilityFromIndex(
        entity.visibilityIndex,
      ),
      status: EntityEnumCodec.templateStatusFromIndex(entity.statusIndex),
      name: entity.name,
      totalKcal: entity.totalKcal,
      totalProteinG: entity.totalProteinG,
      totalFatG: entity.totalFatG,
      totalCarbG: entity.totalCarbG,
      dependencyStatus: EntityEnumCodec.templateDependencyStatusFromIndex(
        entity.dependencyStatusIndex,
      ),
      lastValidatedAt: entity.lastValidatedAt,
      useCount: entity.useCount,
      lastUsedAt: entity.lastUsedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  static MealTemplateItemEntity toMealTemplateItemEntity({
    required MealTemplateItem item,
    required String templateId,
    required String ownerUserId,
  }) {
    return MealTemplateItemEntity()
      ..itemId = item.itemId
      ..templateId = templateId
      ..ownerUserId = ownerUserId
      ..sortOrder = item.sortOrder
      ..savedFoodId = item.savedFoodId
      ..sourceOwnerUserId = item.sourceOwnerUserId
      ..name = item.name
      ..baseAmount = item.baseAmount
      ..unitTypeIndex = EntityEnumCodec.foodUnitTypeIndex(item.unitType)
      ..kcalPerBase = item.kcalPerBase
      ..proteinPerBase = item.proteinPerBase
      ..fatPerBase = item.fatPerBase
      ..carbPerBase = item.carbPerBase
      ..consumedAmount = item.consumedAmount
      ..itemDependencyStatusIndex = EntityEnumCodec.itemDependencyStatusIndex(
        item.itemDependencyStatus,
      )
      ..snapshotSavedAt = item.snapshotSavedAt;
  }

  static MealTemplateItem fromMealTemplateItemEntity(
    MealTemplateItemEntity entity,
  ) {
    return MealTemplateItem(
      itemId: entity.itemId,
      savedFoodId: entity.savedFoodId,
      sourceOwnerUserId: entity.sourceOwnerUserId,
      name: entity.name,
      baseAmount: entity.baseAmount,
      unitType: EntityEnumCodec.foodUnitTypeFromIndex(entity.unitTypeIndex),
      kcalPerBase: entity.kcalPerBase,
      proteinPerBase: entity.proteinPerBase,
      fatPerBase: entity.fatPerBase,
      carbPerBase: entity.carbPerBase,
      consumedAmount: entity.consumedAmount,
      sortOrder: entity.sortOrder,
      itemDependencyStatus: EntityEnumCodec.itemDependencyStatusFromIndex(
        entity.itemDependencyStatusIndex,
      ),
      snapshotSavedAt: entity.snapshotSavedAt,
    );
  }

  static ExerciseEntryEntity toExerciseEntryEntity(ExerciseEntry entry) {
    return ExerciseEntryEntity()
      ..entryId = entry.id
      ..name = entry.name
      ..durationMin = entry.durationMin
      ..burnedKcal = entry.burnedKcal
      ..loggedAt = entry.loggedAt
      ..categoryKey = entry.category?.id
      ..activityId = entry.activityId
      ..intensity = entry.intensity
      ..sets = entry.sets
      ..reps = entry.reps
      ..liftWeightKg = entry.liftWeightKg
      ..metValue = entry.metValue
      ..grossKcal = entry.grossKcal
      ..netKcal = entry.netKcal
      ..weightKgSnapshot = entry.weightKgSnapshot
      ..calculationSource = entry.calculationSource?.storageValue
      ..calculationVersion = entry.calculationVersion
      ..sourceKey = entry.sourceKey
      ..notes = entry.notes;
  }

  static ExerciseEntry fromExerciseEntryEntity(ExerciseEntryEntity entity) {
    return ExerciseEntry(
      id: entity.entryId,
      name: entity.name,
      durationMin: entity.durationMin,
      burnedKcal: entity.burnedKcal,
      loggedAt: entity.loggedAt,
      category: ExerciseCategoryX.tryParse(entity.categoryKey),
      activityId: entity.activityId,
      intensity: entity.intensity,
      sets: entity.sets,
      reps: entity.reps,
      liftWeightKg: entity.liftWeightKg,
      metValue: entity.metValue,
      grossKcal: entity.grossKcal,
      netKcal: entity.netKcal,
      weightKgSnapshot: entity.weightKgSnapshot,
      calculationSource: ExerciseCalculationSourceX.tryParse(
        entity.calculationSource,
      ),
      calculationVersion: entity.calculationVersion,
      sourceKey: entity.sourceKey,
      notes: entity.notes,
    );
  }

  static WorkoutTemplateEntity toWorkoutTemplateEntity(
    WorkoutTemplate template,
  ) {
    return WorkoutTemplateEntity()
      ..templateId = template.templateId
      ..ownerUserId = template.ownerUserId
      ..normalizedName = template.normalizedName
      ..statusIndex = EntityEnumCodec.workoutTemplateStatusIndex(
        template.status,
      )
      ..name = template.name
      ..useCount = template.useCount
      ..lastUsedAt = template.lastUsedAt
      ..createdAt = template.createdAt
      ..updatedAt = template.updatedAt
      ..deletedAt = template.deletedAt;
  }

  static WorkoutTemplate fromWorkoutTemplateEntity(
    WorkoutTemplateEntity entity,
  ) {
    return WorkoutTemplate(
      templateId: entity.templateId,
      ownerUserId: entity.ownerUserId,
      name: entity.name,
      normalizedName: entity.normalizedName,
      status: EntityEnumCodec.workoutTemplateStatusFromIndex(
        entity.statusIndex,
      ),
      useCount: entity.useCount,
      lastUsedAt: entity.lastUsedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  static WorkoutTemplateItemEntity toWorkoutTemplateItemEntity({
    required WorkoutTemplateItem item,
    required String templateId,
    required String ownerUserId,
  }) {
    return WorkoutTemplateItemEntity()
      ..itemId = item.itemId
      ..templateId = templateId
      ..ownerUserId = ownerUserId
      ..sortOrder = item.sortOrder
      ..name = item.name
      ..activityId = item.activityId
      ..categoryKey = item.categoryKey
      ..intensity = item.intensity
      ..durationMin = item.durationMin
      ..sets = item.sets
      ..reps = item.reps
      ..liftWeightKg = item.liftWeightKg
      ..notes = item.notes
      ..metValue = item.metValue
      ..sourceKey = item.sourceKey;
  }

  static WorkoutTemplateItem fromWorkoutTemplateItemEntity(
    WorkoutTemplateItemEntity entity,
  ) {
    return WorkoutTemplateItem(
      itemId: entity.itemId,
      name: entity.name,
      activityId: entity.activityId,
      categoryKey: entity.categoryKey,
      intensity: entity.intensity,
      durationMin: entity.durationMin,
      sets: entity.sets,
      reps: entity.reps,
      liftWeightKg: entity.liftWeightKg,
      sortOrder: entity.sortOrder,
      notes: entity.notes,
      metValue: entity.metValue,
      sourceKey: entity.sourceKey,
    );
  }

  static AlcoholEntryEntity toAlcoholEntryEntity(AlcoholEntry entry) {
    return AlcoholEntryEntity()
      ..entryId = entry.id
      ..beverageName = entry.beverageName
      ..amount = entry.amount
      ..unit = entry.unit
      ..alcoholPercentage = entry.alcoholPercentage
      ..totalCalories = entry.totalCalories
      ..pureAlcoholGrams = entry.pureAlcoholGrams
      ..alcoholCalories = entry.alcoholCalories
      ..consumedAt = entry.consumedAt;
  }

  static AlcoholEntry fromAlcoholEntryEntity(AlcoholEntryEntity entity) {
    return AlcoholEntry(
      id: entity.entryId,
      beverageName: entity.beverageName,
      amount: entity.amount,
      unit: entity.unit,
      alcoholPercentage: entity.alcoholPercentage,
      totalCalories: entity.totalCalories,
      pureAlcoholGrams: entity.pureAlcoholGrams,
      alcoholCalories: entity.alcoholCalories,
      consumedAt: entity.consumedAt,
    );
  }

  static WeightEntryEntity toWeightEntryEntity(WeightEntry entry) {
    return WeightEntryEntity()
      ..entryId = entry.id
      ..weightKg = entry.weightKg
      ..recordedAt = entry.recordedAt
      ..sourceIndex = entry.source.index;
  }

  static WeightEntry fromWeightEntryEntity(WeightEntryEntity entity) {
    return WeightEntry(
      id: entity.entryId,
      weightKg: entity.weightKg,
      recordedAt: entity.recordedAt,
      source: WeightSource.values[entity.sourceIndex],
    );
  }

  static HealthSnapshotEntity toHealthSnapshotEntity(HealthSnapshot snapshot) {
    return HealthSnapshotEntity()
      ..activeEnergyBurnedKcal = snapshot.activeEnergyBurnedKcal
      ..weightKg = snapshot.weightKg
      ..updatedAt = DateTime.now();
  }

  static HealthSnapshot fromHealthSnapshotEntity(HealthSnapshotEntity entity) {
    return HealthSnapshot(
      activeEnergyBurnedKcal: entity.activeEnergyBurnedKcal,
      weightKg: entity.weightKg,
    );
  }

  static AppSettingsEntity toAppSettingsEntity(AppSettings settings) {
    return AppSettingsEntity()
      ..onboardingComplete = settings.onboardingComplete;
  }

  static AppSettings fromAppSettingsEntity(AppSettingsEntity entity) {
    return AppSettings(onboardingComplete: entity.onboardingComplete);
  }

  static HealthWorkoutEntity toHealthWorkoutEntity(HealthWorkoutRecord record) {
    return HealthWorkoutEntity()
      ..workoutId = record.id
      ..activityType = record.activityType
      ..startTime = record.startTime
      ..endTime = record.endTime
      ..caloriesBurned = record.caloriesBurned;
  }

  static HealthWorkoutRecord fromHealthWorkoutEntity(
    HealthWorkoutEntity entity,
  ) {
    return HealthWorkoutRecord(
      id: entity.workoutId,
      activityType: entity.activityType,
      startTime: entity.startTime,
      endTime: entity.endTime,
      caloriesBurned: entity.caloriesBurned,
    );
  }
}
