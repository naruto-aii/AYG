import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_web.dart';
import '../config/open_food_facts_config.dart';
import '../config/supabase_config.dart';
import '../platform/web/repositories/web_exercise_repository.dart';
import '../platform/web/repositories/web_food_repository.dart';
import '../platform/web/repositories/web_settings_repository.dart';
import '../platform/web/repositories/web_supabase_authentication_repository.dart';
import '../platform/web/repositories/web_user_repository.dart';
import '../platform/web/repositories/web_weight_repository.dart';
import '../platform/web/web_health_workout_store.dart';
import '../platform/web/web_local_user_data_clearer.dart';
import '../platform/web/web_unsupported_health_repository.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/local_session_store.dart';
import '../repositories/supabase_authentication_repository.dart';
import '../services/open_food_facts_service.dart';
import '../state/app_controller.dart';

Future<Widget> buildWebApp() async {
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(Uri.base);
    } on AuthException {
      // OAuth コールバック以外の通常起動。
    }
  }

  final userRepository = WebUserRepository();
  final settingsRepository = WebSettingsRepository();
  final foodRepository = WebFoodRepository();
  final exerciseRepository = WebExerciseRepository();
  final weightRepository = WebWeightRepository();
  final workoutStore = WebHealthWorkoutStore();

  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );

  final healthRepository = WebUnsupportedHealthRepository(
    weightRepository: weightRepository,
    workoutStore: workoutStore,
  );

  final AuthenticationRepository authenticationRepository =
      SupabaseConfig.isConfigured
      ? WebSupabaseAuthenticationRepository()
      : UnconfiguredAuthenticationRepository();

  final DataSyncRepository dataSyncRepository = SupabaseConfig.isConfigured
      ? SupabaseDataSyncRepository(
          userRepository: userRepository,
          settingsRepository: settingsRepository,
          foodRepository: foodRepository,
          exerciseRepository: exerciseRepository,
          weightRepository: weightRepository,
        )
      : NoOpDataSyncRepository();

  final localSessionStore = LocalSessionStore();
  final localUserDataClearer = WebLocalUserDataClearer(
    userRepository: userRepository,
    settingsRepository: settingsRepository,
    foodRepository: foodRepository,
    exerciseRepository: exerciseRepository,
    weightRepository: weightRepository,
    workoutStore: workoutStore,
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
  );
  await controller.initialize();

  return AygWebApp(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    authenticationRepository: authenticationRepository,
  );
}
