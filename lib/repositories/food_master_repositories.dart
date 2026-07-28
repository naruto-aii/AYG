import 'contracts/blocked_food_creator_repository_base.dart';
import 'contracts/food_rating_repository_base.dart';
import 'contracts/food_report_repository_base.dart';
import 'contracts/saved_food_remote_store.dart';
import 'contracts/meal_template_repository_base.dart';
import 'contracts/saved_food_local_store.dart';
import 'contracts/saved_food_repository_base.dart';
import 'meal_template_repository.dart';
import 'supabase/supabase_blocked_food_creator_repository.dart';
import 'supabase/supabase_food_rating_repository.dart';
import 'supabase/supabase_food_report_repository.dart';
import 'supabase/supabase_meal_template_repository.dart';
import 'supabase/supabase_saved_food_repository.dart';
import 'synced_saved_food_repository.dart';

/// Phase 5: Supabase-backed food master repositories bundle.
class FoodMasterRepositories {
  FoodMasterRepositories._({
    required this.savedFoods,
    required this.localSavedFoods,
    required this.mealTemplates,
    this.foodRatings,
    this.foodReports,
    this.blockedCreators,
    this.remoteMealTemplates,
    this.remoteSavedFoods,
  });

  final SavedFoodRepositoryBase savedFoods;
  final SavedFoodLocalStore localSavedFoods;
  final MealTemplateRepositoryBase mealTemplates;
  final FoodRatingRepositoryBase? foodRatings;
  final FoodReportRepositoryBase? foodReports;
  final BlockedFoodCreatorRepositoryBase? blockedCreators;
  final SupabaseMealTemplateRepository? remoteMealTemplates;
  final SavedFoodRemoteStore? remoteSavedFoods;

  factory FoodMasterRepositories.localOnly({
    required SavedFoodLocalStore localSavedFoods,
    required MealTemplateRepositoryBase mealTemplates,
  }) {
    return FoodMasterRepositories._(
      savedFoods: SyncedSavedFoodRepository(local: localSavedFoods),
      localSavedFoods: localSavedFoods,
      mealTemplates: mealTemplates,
    );
  }

  factory FoodMasterRepositories.synced({
    required SavedFoodLocalStore localSavedFoods,
    required MealTemplateRepositoryBase mealTemplates,
    required SupabaseSavedFoodRepository remoteSavedFoods,
    required SupabaseMealTemplateRepository remoteMealTemplates,
    required SupabaseFoodRatingRepository foodRatings,
    required SupabaseFoodReportRepository foodReports,
    required SupabaseBlockedFoodCreatorRepository blockedCreators,
  }) {
    return FoodMasterRepositories._(
      savedFoods: SyncedSavedFoodRepository(
        local: localSavedFoods,
        remote: remoteSavedFoods,
      ),
      localSavedFoods: localSavedFoods,
      mealTemplates: mealTemplates,
      foodRatings: foodRatings,
      foodReports: foodReports,
      blockedCreators: blockedCreators,
      remoteMealTemplates: remoteMealTemplates,
      remoteSavedFoods: remoteSavedFoods,
    );
  }
}
