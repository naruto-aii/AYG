import 'package:isar/isar.dart';

part 'schemas.g.dart';

@collection
class UserProfileEntity {
  Id id = 1;

  late DateTime birthDate;
  late int genderIndex;
  late double heightCm;
  late double weightKg;
}

@collection
class GoalEntity {
  Id id = 1;

  late int goalTypeIndex;
  late double targetWeightKg;
  late DateTime targetDate;
}

@collection
class NutritionSettingsEntity {
  Id id = 1;

  late bool useHealthIntegration;
  int? activityLevelIndex;
}

@collection
class FoodEntryEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String entryId;

  late String name;
  double? kcalPerUnit;
  double? proteinPerUnit;
  double? fatPerUnit;
  double? carbPerUnit;

  /// 旧スキーマ互換。常に multiplier (= consumedAmount / baseAmount) を保存。
  late double quantity;

  late DateTime loggedAt;

  // --- Phase 3 拡張（nullable = 旧行は未設定） ---
  double? baseAmount;
  int? unitTypeIndex;
  double? consumedAmount;
  int? sourceTypeIndex;
  String? savedFoodId;
  String? sourceFoodOwnerUserId;
  String? mealGroupId;
  String? mealGroupName;
  int? sortOrder;
}

@collection
class SavedFoodEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String foodId;

  @Index()
  late String ownerUserId;

  @Index()
  late String normalizedName;

  late int visibilityIndex;
  late int statusIndex;
  late int moderationStatusIndex;

  late String name;
  late double baseAmount;
  late int unitTypeIndex;

  double? kcalPerBase;
  double? proteinPerBase;
  double? fatPerBase;
  double? carbPerBase;

  late int sourceTypeIndex;
  String? barcode;
  String? brand;
  String? supplementaryWeight;

  String? copiedFromFoodId;
  String? copiedFromOwnerUserId;

  late int useCount;
  DateTime? lastUsedAt;
  late int reportCount;

  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;
}

@collection
class MealTemplateEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String templateId;

  @Index()
  late String ownerUserId;

  @Index()
  late String normalizedName;

  late int visibilityIndex;
  late int statusIndex;

  late String name;
  late double totalKcal;
  late double totalProteinG;
  late double totalFatG;
  late double totalCarbG;

  late int dependencyStatusIndex;
  DateTime? lastValidatedAt;

  late int useCount;
  DateTime? lastUsedAt;

  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;
}

@collection
class MealTemplateItemEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String itemId;

  @Index()
  late String templateId;

  @Index()
  late String ownerUserId;

  @Index()
  late int sortOrder;

  String? savedFoodId;
  String? sourceOwnerUserId;

  late String name;
  late double baseAmount;
  late int unitTypeIndex;

  double? kcalPerBase;
  double? proteinPerBase;
  double? fatPerBase;
  double? carbPerBase;

  late double consumedAmount;

  late int itemDependencyStatusIndex;
  late DateTime snapshotSavedAt;
}

@collection
class ExerciseEntryEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String entryId;

  late String name;
  late int durationMin;
  late double burnedKcal;
  late DateTime loggedAt;
}

@collection
class WeightEntryEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String entryId;

  late double weightKg;
  late DateTime recordedAt;
  late int sourceIndex;
}

@collection
class HealthSnapshotEntity {
  Id id = 1;

  double? activeEnergyBurnedKcal;
  double? weightKg;
  late DateTime updatedAt;
}

@collection
class AppSettingsEntity {
  Id id = 1;

  late bool onboardingComplete;
}

@collection
class HealthWorkoutEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String workoutId;

  late String activityType;
  late DateTime startTime;
  late DateTime endTime;
  double? caloriesBurned;
}
