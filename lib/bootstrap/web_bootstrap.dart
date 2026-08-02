import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/open_food_facts_config.dart';
import '../config/supabase_config.dart';
import '../platform/web/repositories/web_alcohol_repository.dart';
import '../platform/web/repositories/web_exercise_repository.dart';
import '../platform/web/repositories/web_food_repository.dart';
import '../platform/web/repositories/web_meal_template_repository.dart';
import '../platform/web/repositories/web_workout_template_repository.dart';
import '../platform/web/repositories/web_saved_food_repository.dart';
import '../platform/web/repositories/web_settings_repository.dart';
import '../platform/web/repositories/web_user_repository.dart';
import '../platform/web/repositories/web_weight_repository.dart';
import '../repositories/supabase/supabase_meal_template_repository.dart';
import '../repositories/supabase/supabase_workout_template_repository.dart';
import '../repositories/supabase/supabase_saved_food_repository.dart';
import '../platform/web/resilient_gotrue_async_storage.dart';
import '../platform/web/web_local_user_data_clearer.dart';
import '../platform/web/web_storage_availability.dart';
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
import '../platform/web/resilient_auth_local_storage.dart';
import '../services/open_food_facts_service.dart';
import '../state/app_controller.dart';
import '../widgets/startup/startup_error_app.dart';
import 'web_init_error.dart';

/// Web起動用 DI（Isar非依存）。
Future<void> bootstrapApp() => bootstrapWebApp();

Future<void> bootstrapWebApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = WebInitDiagnostics();

  if (kDebugMode) {
    debugPrint('[AYG Web] bootstrap start');
  }

  try {
    diagnostics.supabaseUrlConfigured = SupabaseConfig.url.isNotEmpty;
    diagnostics.supabaseAnonKeyConfigured = SupabaseConfig.anonKey.isNotEmpty;
    diagnostics.authStorageAvailable =
        WebStorageAvailability.isLocalStorageAvailable;

    _logDiagnostics(diagnostics, 'config');

    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[AYG Web] Supabase not configured; login-only mode');
      }
    } else {
      try {
        final sessionKey =
            'sb-${Uri.parse(SupabaseConfig.url).host.split('.').first}-auth-token';
        final baseStorage = SharedPreferencesLocalStorage(
          persistSessionKey: sessionKey,
        );
        final resilientStorage = ResilientAuthLocalStorage(baseStorage);

        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            localStorage: resilientStorage,
            pkceAsyncStorage: ResilientGotrueAsyncStorage(
              SharedPreferencesGotrueAsyncStorage(),
            ),
          ),
        );
        diagnostics.supabaseInitializeSuccess = true;
        if (!resilientStorage.isPersistent) {
          diagnostics.authStorageAvailable = false;
        }
      } catch (error, stackTrace) {
        diagnostics.lastErrorCode = WebInitErrorCode.initSupabaseFailed.code;
        if (kDebugMode) {
          debugPrint('[AYG Web] Supabase.initialize failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        throw WebInitException(
          WebInitErrorCode.initSupabaseFailed,
          cause: error,
        );
      }
    }

    _logDiagnostics(diagnostics, 'supabase');

    late final UserRepository userRepository;
    late final SettingsRepository settingsRepository;
    late final FoodRepository foodRepository;
    late final ExerciseRepository exerciseRepository;
    late final AlcoholRepository alcoholRepository;
    late final WeightRepository weightRepository;
    late final IsarSavedFoodRepository savedFoodRepository;
    late final MealTemplateRepository mealTemplateRepository;
    late final WorkoutTemplateRepository workoutTemplateRepository;

    try {
      userRepository = UserRepository();
      settingsRepository = SettingsRepository();
      foodRepository = FoodRepository();
      exerciseRepository = ExerciseRepository();
      alcoholRepository = AlcoholRepository();
      weightRepository = WeightRepository();
      savedFoodRepository = IsarSavedFoodRepository();
      mealTemplateRepository = MealTemplateRepository();
      workoutTemplateRepository = WorkoutTemplateRepository();
    } catch (error, stackTrace) {
      diagnostics.lastErrorCode = WebInitErrorCode.initRepositoryFailed.code;
      if (kDebugMode) {
        debugPrint('[AYG Web] repository init failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw WebInitException(
        WebInitErrorCode.initRepositoryFailed,
        cause: error,
      );
    }

    final foodMasterRepositories = SupabaseConfig.isConfigured
        ? FoodMasterRepositories.synced(
            localSavedFoods: savedFoodRepository,
            mealTemplates: mealTemplateRepository,
            workoutTemplates: workoutTemplateRepository,
            remoteSavedFoods: SupabaseSavedFoodRepository(),
            remoteMealTemplates: SupabaseMealTemplateRepository(),
            remoteWorkoutTemplates: SupabaseWorkoutTemplateRepository(),
            foodRatings: SupabaseFoodRatingRepository(),
            foodReports: SupabaseFoodReportRepository(),
            blockedCreators: SupabaseBlockedFoodCreatorRepository(),
          )
        : FoodMasterRepositories.localOnly(
            localSavedFoods: savedFoodRepository,
            mealTemplates: mealTemplateRepository,
            workoutTemplates: workoutTemplateRepository,
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
            alcoholRepository: alcoholRepository,
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
      alcoholRepository: alcoholRepository,
      weightRepository: weightRepository,
      savedFoodRepository: savedFoodRepository,
      mealTemplateRepository: mealTemplateRepository,
      workoutTemplateRepository: workoutTemplateRepository,
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
      alcoholRepository: alcoholRepository,
      weightRepository: weightRepository,
      savedFoodRepository: foodMasterRepositories.savedFoods,
      foodRatingRepository: foodMasterRepositories.foodRatings,
      foodReportRepository: foodMasterRepositories.foodReports,
      blockedCreatorRepository: foodMasterRepositories.blockedCreators,
      mealTemplateRepository: mealTemplateRepository,
      workoutTemplateRepository: workoutTemplateRepository,
    );

    if (kDebugMode) {
      debugPrint('[AYG Web] controller.initialize');
    }

    try {
      await controller.initialize();
      diagnostics.authRestore = authenticationRepository.isAuthenticated
          ? 'success'
          : 'no session';
      diagnostics.initialSync = controller.hasInitialSyncCompleted
          ? 'success'
          : controller.lastSyncFailed
          ? 'failed'
          : 'skipped';
    } catch (error, stackTrace) {
      diagnostics.lastErrorCode = WebInitErrorCode.initControllerFailed.code;
      diagnostics.authRestore = 'failed';
      if (kDebugMode) {
        debugPrint('[AYG Web] controller.initialize failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      // コントローラ初期化失敗でもログイン画面へ進める。
    }

    _logDiagnostics(diagnostics, 'controller');

    if (kDebugMode) {
      debugPrint('[AYG Web] runApp');
    }

    runApp(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authenticationRepository,
        authStorageAvailable: diagnostics.authStorageAvailable,
      ),
    );
  } on WebInitException catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[AYG Web] bootstrap failed: ${error.code.code}');
      debugPrintStack(stackTrace: stackTrace);
    }
    runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[AYG Web] bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    runApp(
      StartupErrorApp(
        error: WebInitException(WebInitErrorCode.initUnknown, cause: error),
        stackTrace: stackTrace,
      ),
    );
  }
}

void _logDiagnostics(WebInitDiagnostics diagnostics, String stage) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    '[AYG Web][$stage] '
    'SUPABASE_URL configured: ${diagnostics.supabaseUrlConfigured}; '
    'SUPABASE_ANON_KEY configured: ${diagnostics.supabaseAnonKeyConfigured}; '
    'Supabase initialize: ${diagnostics.supabaseInitializeSuccess ? 'success' : 'failed'}; '
    'Auth storage available: ${diagnostics.authStorageAvailable}; '
    'Auth restore: ${diagnostics.authRestore}; '
    'Initial sync: ${diagnostics.initialSync}',
  );
}
