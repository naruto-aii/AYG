import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/open_food_facts_config.dart';
import 'config/supabase_config.dart';
import 'database/isar_service.dart';
import 'repositories/authentication_repository.dart';
import 'repositories/data_sync_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/food_master_repositories.dart';
import 'repositories/food_repository.dart';
import 'repositories/health_repository.dart';
import 'repositories/isar_saved_food_repository.dart';
import 'repositories/local_session_store.dart';
import 'repositories/meal_template_repository.dart';
import 'repositories/platform_health_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/supabase/supabase_blocked_food_creator_repository.dart';
import 'repositories/supabase/supabase_food_rating_repository.dart';
import 'repositories/supabase/supabase_food_report_repository.dart';
import 'repositories/supabase/supabase_meal_template_repository.dart';
import 'repositories/supabase/supabase_saved_food_repository.dart';
import 'repositories/supabase_authentication_repository.dart';
import 'repositories/unsupported_health_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/weight_repository.dart';
import 'services/local_user_data_clearer.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  final isar = await IsarService.open();
  final weightRepository = WeightRepository(isar);
  final userRepository = UserRepository(isar);
  final settingsRepository = SettingsRepository(isar);
  final foodRepository = FoodRepository(isar);
  final exerciseRepository = ExerciseRepository(isar);
  final savedFoodRepository = IsarSavedFoodRepository(isar);
  final mealTemplateRepository = MealTemplateRepository(isar);

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

  final HealthRepository healthRepository = kIsWeb
      ? UnsupportedHealthRepository(
          weightRepository: weightRepository,
          isar: isar,
        )
      : PlatformHealthRepository(
          weightRepository: weightRepository,
          isar: isar,
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
    isar: isar,
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
  );
  await controller.initialize();

  runApp(
    AygApp(
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      healthRepository: healthRepository,
      authenticationRepository: authenticationRepository,
    ),
  );
}
