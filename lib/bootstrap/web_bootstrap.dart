import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/open_food_facts_config.dart';
import '../config/supabase_config.dart';
import '../platform/web/repositories/web_exercise_repository.dart';
import '../platform/web/repositories/web_food_repository.dart';
import '../platform/web/repositories/web_meal_template_repository.dart';
import '../platform/web/repositories/web_saved_food_repository.dart';
import '../platform/web/repositories/web_settings_repository.dart';
import '../platform/web/repositories/web_user_repository.dart';
import '../platform/web/repositories/web_weight_repository.dart';
import '../platform/web/web_local_user_data_clearer.dart';
import '../platform/web/web_unsupported_health_repository.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/food_master_repositories.dart';
import '../repositories/health_repository.dart';
import '../repositories/local_session_store.dart';
import '../repositories/supabase/supabase_blocked_food_creator_repository.dart';
import '../repositories/supabase/supabase_food_rating_repository.dart';
import '../repositories/supabase/supabase_food_report_repository.dart';
import '../repositories/supabase/supabase_meal_template_repository.dart';
import '../repositories/supabase/supabase_saved_food_repository.dart';
import '../repositories/supabase_authentication_repository.dart';
import '../services/open_food_facts_service.dart';
import '../state/app_controller.dart';
import '../widgets/startup/startup_error_app.dart';

/// Web起動用 DI（Isar非依存）。
Future<void> bootstrapWebApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    debugPrint('[AYG Web] bootstrap start');
  }

  try {
    if (SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[AYG Web] Supabase.initialize');
      }
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }

    final userRepository = UserRepository();
    final settingsRepository = SettingsRepository();
    final foodRepository = FoodRepository();
    final exerciseRepository = ExerciseRepository();
    final weightRepository = WeightRepository();
    final savedFoodRepository = IsarSavedFoodRepository();
    final mealTemplateRepository = MealTemplateRepository();

    final foodMasterRepositories = SupabaseConfig.isConfigured
        ? FoodMasterRepositories.synced(
            localSavedFoods: savedFoodRepository,
            mealTemplates: mealTemplateRepository,
            remoteSavedFoods: SupabaseSavedFoodRepository(),
            remoteMealTemplates: SupabaseMealTemplateRepository(),
            foodRatings: SupabaseFoodRatingRepository(),
            foodReports: SupabaseFoodReportRepository(),
            blockedCreators: SupabaseBlockedFoodCreatorRepository(),
          )
        : FoodMasterRepositories.localOnly(
            localSavedFoods: savedFoodRepository,
            mealTemplates: mealTemplateRepository,
          );

    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    final HealthRepository healthRepository = UnsupportedHealthRepository(
      weightRepository: weightRepository,
    );

    final AuthenticationRepository authenticationRepository =
        SupabaseConfig.isConfigured
        ? SupabaseAuthenticationRepository()
        : UnconfiguredAuthenticationRepository();

    final DataSyncRepository dataSyncRepository = SupabaseConfig.isConfigured
        ? SupabaseDataSyncRepository(
            userRepository: userRepository,
            settingsRepository: settingsRepository,
            foodRepository: foodRepository,
            exerciseRepository: exerciseRepository,
            weightRepository: weightRepository,
            foodMaster: foodMasterRepositories,
          )
        : NoOpDataSyncRepository();

    final localSessionStore = LocalSessionStore();
    final localUserDataClearer = LocalUserDataClearer(
      userRepository: userRepository,
      settingsRepository: settingsRepository,
      foodRepository: foodRepository,
      exerciseRepository: exerciseRepository,
      weightRepository: weightRepository,
      savedFoodRepository: savedFoodRepository,
      mealTemplateRepository: mealTemplateRepository,
    );

    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authenticationRepository,
      dataSyncRepository: dataSyncRepository,
      localSessionStore: localSessionStore,
      localUserDataClearer: localUserDataClearer,
      userRepository: userRepository,
      settingsRepository: settingsRepository,
      foodRepository: foodRepository,
      exerciseRepository: exerciseRepository,
      weightRepository: weightRepository,
      savedFoodRepository: foodMasterRepositories.savedFoods,
      foodRatingRepository: foodMasterRepositories.foodRatings,
      foodReportRepository: foodMasterRepositories.foodReports,
      blockedCreatorRepository: foodMasterRepositories.blockedCreators,
      mealTemplateRepository: mealTemplateRepository,
    );

    if (kDebugMode) {
      debugPrint('[AYG Web] controller.initialize');
    }
    await controller.initialize();

    if (kDebugMode) {
      debugPrint('[AYG Web] runApp');
    }

    runApp(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authenticationRepository,
      ),
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[AYG Web] bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
  }
}
