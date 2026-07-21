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
  late double quantity;
  late DateTime loggedAt;
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
