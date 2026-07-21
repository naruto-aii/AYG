import 'activity_level.dart';

class NutritionSettings {
  const NutritionSettings({
    required this.useHealthIntegration,
    this.activityLevel,
  }) : assert(
         useHealthIntegration || activityLevel != null,
         'Activity level is required when health integration is disabled.',
       );

  final bool useHealthIntegration;
  final ActivityLevel? activityLevel;

  NutritionSettings copyWith({
    bool? useHealthIntegration,
    ActivityLevel? activityLevel,
  }) {
    return NutritionSettings(
      useHealthIntegration: useHealthIntegration ?? this.useHealthIntegration,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}
