import '../database/schemas.dart';
import '../models/activity_level.dart';
import '../models/app_settings.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';

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
      ..targetDate = goal.targetDate;
  }

  static Goal fromGoalEntity(GoalEntity entity) {
    return Goal(
      type: GoalType.values[entity.goalTypeIndex],
      targetWeightKg: entity.targetWeightKg,
      targetDate: entity.targetDate,
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
      ..kcalPerUnit = entry.kcalPerUnit
      ..proteinPerUnit = entry.proteinPerUnit
      ..fatPerUnit = entry.fatPerUnit
      ..carbPerUnit = entry.carbPerUnit
      ..quantity = entry.quantity
      ..loggedAt = entry.loggedAt;
  }

  static FoodEntry fromFoodEntryEntity(FoodEntryEntity entity) {
    return FoodEntry(
      id: entity.entryId,
      name: entity.name,
      kcalPerUnit: entity.kcalPerUnit,
      proteinPerUnit: entity.proteinPerUnit,
      fatPerUnit: entity.fatPerUnit,
      carbPerUnit: entity.carbPerUnit,
      quantity: entity.quantity,
      loggedAt: entity.loggedAt,
    );
  }

  static ExerciseEntryEntity toExerciseEntryEntity(ExerciseEntry entry) {
    return ExerciseEntryEntity()
      ..entryId = entry.id
      ..name = entry.name
      ..durationMin = entry.durationMin
      ..burnedKcal = entry.burnedKcal
      ..loggedAt = entry.loggedAt;
  }

  static ExerciseEntry fromExerciseEntryEntity(ExerciseEntryEntity entity) {
    return ExerciseEntry(
      id: entity.entryId,
      name: entity.name,
      durationMin: entity.durationMin,
      burnedKcal: entity.burnedKcal,
      loggedAt: entity.loggedAt,
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
