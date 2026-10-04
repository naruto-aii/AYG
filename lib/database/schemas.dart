import 'package:isar/isar.dart';

part 'schemas.g.dart';

@collection
class UserProfileEntity {
  Id id = 1;

  late DateTime birthDate;
  late int genderIndex;
  late double heightCm;
  late double weightKg;

  /// 未入力、またはこの列を追加する前の行は null。
  String? displayName;
}

@collection
class GoalEntity {
  Id id = 1;

  late int goalTypeIndex;
  late double targetWeightKg;
  late DateTime targetDate;
  int? goalPaceIndex;
}

@collection
class NutritionSettingsEntity {
  Id id = 1;

  late bool useHealthIntegration;
  int? activityLevelIndex;
  int? calorieTargetModeIndex;
  double? manualTargetKcal;
  double? manualProteinG;
  double? manualFatG;
  double? manualCarbG;
  double? autoFoodTargetKcal;
  DateTime? autoFoodTargetOn;
  double? autoFoodTargetPriorKcal;
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
  int? sourceSavedFoodVersion;
  String? mealGroupId;
  String? mealGroupName;
  int? sortOrder;
  String? officialFoodCode;
  String? officialFoodName;

  /// その食事へのメモ。未入力の古い行は null。
  ///
  /// Isar は offset 表をプロパティ名のアルファベット順で作る。
  /// `schemas.g.dart` の id をその順からずらすと、保存時に文字列長を誤読して
  /// isarworker が落ちる。列を足すときは id を名前順に差し込む。
  String? memo;
}

/// 1件の読み取りが失敗しても、食事コレクション全体は落とさない。
FoodEntryEntity readStoredFoodEntry(Id id, FoodEntryEntity Function() read) {
  try {
    final entity = read();
    if (!isReadableStoredFoodEntry(entity)) {
      return unreadableStoredFoodEntry(id);
    }
    return entity;
  } on RangeError {
    return unreadableStoredFoodEntry(id);
  } on FormatException {
    return unreadableStoredFoodEntry(id);
  }
}

/// 壊れた行は entryId を空にしておき、読み込み側で1件だけ飛ばす。
bool isReadableStoredFoodEntry(FoodEntryEntity entity) {
  return entity.entryId.isNotEmpty;
}

FoodEntryEntity unreadableStoredFoodEntry(Id id) {
  return FoodEntryEntity()
    ..id = id
    ..entryId = ''
    ..name = ''
    ..quantity = 0
    ..loggedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
  String? servingUnitLabel;

  double? kcalPerBase;
  double? proteinPerBase;
  double? fatPerBase;
  double? carbPerBase;

  late int sourceTypeIndex;
  String? barcode;
  String? brand;
  String? supplementaryWeight;
  String? officialFoodCode;
  String? officialFoodName;
  String? sourceAttribution;

  String? copiedFromFoodId;
  String? copiedFromOwnerUserId;

  late int useCount;
  DateTime? lastUsedAt;
  late int reportCount;

  int version = 1;

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

  String? categoryKey;
  String? activityId;
  String? intensity;
  int? sets;
  int? reps;
  double? liftWeightKg;

  /// 距離（km）。生成スキーマの番号は名前順の 5。
  /// 戻すときはこのフィールドを消す。Isar は列の実体を末尾に残したまま名前だけ外すので、以前の番号に戻る。
  double? distanceKm;
  double? metValue;
  double? grossKcal;
  double? netKcal;
  double? weightKgSnapshot;
  String? calculationSource;
  String? calculationVersion;
  String? sourceKey;
  String? notes;
}

@collection
class AlcoholEntryEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String entryId;

  late String beverageName;
  late double amount;
  late String unit;
  late double alcoholPercentage;
  late double totalCalories;
  late double pureAlcoholGrams;
  late double alcoholCalories;
  late DateTime consumedAt;
}

@collection
class WorkoutTemplateEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String templateId;

  @Index()
  late String ownerUserId;

  @Index()
  late String normalizedName;

  late int statusIndex;

  late String name;
  late int useCount;
  DateTime? lastUsedAt;

  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;
}

@collection
class WorkoutTemplateItemEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String itemId;

  @Index()
  late String templateId;

  @Index()
  late String ownerUserId;

  @Index()
  late int sortOrder;

  late String name;
  String? activityId;
  String? categoryKey;
  String? intensity;
  late int durationMin;
  int? sets;
  int? reps;
  double? liftWeightKg;
  String? notes;
  double? metValue;
  String? sourceKey;
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
  DateTime? weightMeasuredAt;
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
