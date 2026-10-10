import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/demo_mode.dart';
import '../config/development_plus_preview.dart';
import '../config/open_food_facts_config.dart';
import '../config/supabase_config.dart';
import '../database/isar_service.dart';
import '../repositories/alcohol_repository.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/pending_record_store.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/food_master_repositories.dart';
import '../repositories/food_repository.dart';
import '../repositories/health_repository.dart';
import '../repositories/saved_food_repository.dart';
import '../demo/demo_authentication_repository.dart';
import '../demo/demo_catalog.dart';
import '../demo/demo_subscription_repository.dart';
import '../repositories/first_meal_guide_store.dart';
import '../repositories/local_session_store.dart';
import '../repositories/meal_template_repository.dart';
import '../repositories/workout_template_repository.dart';
import '../repositories/platform_health_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/supabase/supabase_food_rating_repository.dart';
import '../repositories/supabase/supabase_food_report_repository.dart';
import '../repositories/supabase/supabase_meal_template_repository.dart';
import '../repositories/supabase/supabase_saved_food_repository.dart';
import '../repositories/supabase/supabase_workout_template_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/supabase/supabase_blocked_food_creator_repository.dart';
import '../repositories/supabase_authentication_repository.dart';
import '../repositories/storekit_subscription_repository.dart';
import '../repositories/coach_proposal_log.dart';
import '../repositories/plus_funnel_repository.dart';
import '../repositories/review_prompt_store.dart';
import '../repositories/usage_record_repository.dart';
import '../repositories/weight_repository.dart';
import '../services/local_user_data_clearer.dart';
import '../services/lock_screen_meal_gateway.dart';
import '../services/siri_voice_gateway.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_service.dart';
import '../services/analytics/analytics_lifecycle.dart';
import '../services/analytics/analytics_queue.dart';
import '../services/analytics/analytics_route_observer.dart';
import '../services/analytics/analytics_runtime.dart';
import '../services/analytics/apple_ads_attribution.dart';
import '../services/analytics/native_analytics_bridge.dart';
import '../services/analytics/supabase_analytics_transport.dart';
import '../services/open_food_facts_service.dart';
import '../state/app_controller.dart';

/// iOS/Android 向け起動（Isar 依存）。
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final remote = !calonaviDemoMode && SupabaseConfig.isConfigured;
  if (remote) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  final isar = await IsarService.open(
    directory: calonaviDemoMode ? await _demoDirectory() : null,
  );
  final weightRepository = WeightRepository(isar);
  final userRepository = UserRepository(isar);
  final settingsRepository = SettingsRepository(isar);
  final foodRepository = FoodRepository(isar);
  final exerciseRepository = ExerciseRepository(isar);
  final alcoholRepository = AlcoholRepository(isar);
  final savedFoodRepository = IsarSavedFoodRepository(isar);
  final mealTemplateRepository = MealTemplateRepository(isar);
  final workoutTemplateRepository = WorkoutTemplateRepository(isar);

  final foodMasterRepositories = remote
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

  final HealthRepository healthRepository = PlatformHealthRepository(
    weightRepository: weightRepository,
    isar: isar,
  );

  final AuthenticationRepository authenticationRepository = calonaviDemoMode
      ? DemoAuthenticationRepository()
      : remote
      ? SupabaseAuthenticationRepository()
      : UnconfiguredAuthenticationRepository();

  final preferences = await SharedPreferences.getInstance();
  final pendingRecords = PendingRecordStore(preferences: preferences);
  final DataSyncRepository dataSyncRepository = remote
      ? SupabaseDataSyncRepository(
          userRepository: userRepository,
          settingsRepository: settingsRepository,
          foodRepository: foodRepository,
          exerciseRepository: exerciseRepository,
          alcoholRepository: alcoholRepository,
          weightRepository: weightRepository,
          foodMaster: foodMasterRepositories,
          healthWorkouts: healthRepository,
          pendingRecords: pendingRecords,
        )
      : NoOpDataSyncRepository();

  final localSessionStore = LocalSessionStore();
  final localUserDataClearer = LocalUserDataClearer(
    isar: isar,
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

  final bridge = MethodChannelNativeAnalyticsBridge();
  var appVersion = '1.0.0';
  var appBuild = '2';
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) {
      appVersion = info.version;
    }
    if (info.buildNumber.isNotEmpty) {
      appBuild = info.buildNumber;
    }
  } catch (error, stackTrace) {
    debugPrint('[AYG] package info unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final analytics = AnalyticsService(
    preferences: preferences,
    queue: AnalyticsQueue(isar: isar),
    transport: SupabaseAnalyticsTransport(),
    bridge: bridge,
    appVersion: appVersion,
    appBuild: appBuild,
    onUnauthorized: () async {
      if (remote) {
        await Supabase.instance.client.auth.refreshSession();
      }
    },
    onConsentRow: uploadAnalyticsConsent,
  );
  try {
    analytics.deviceModel = await bridge.deviceModel();
  } catch (error, stackTrace) {
    debugPrint('[AYG] device model unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  Analytics.service = analytics;
  AnalyticsRuntime.preferences = preferences;
  AnalyticsRuntime.lifecycle = AnalyticsLifecycle(
    service: analytics,
    preferences: preferences,
  );
  AnalyticsRuntime.ads = AppleAdsAttribution(
    service: analytics,
    preferences: preferences,
  );
  AnalyticsRuntime.routes = AnalyticsRouteObserver(service: analytics);
  final subscriptionRepository = calonaviDemoMode
      ? DemoSubscriptionRepository()
      : StoreKitSubscriptionRepository(
          preferences: preferences,
          developmentPlusPreview: developmentPlusPreview,
        );
  if (subscriptionRepository is StoreKitSubscriptionRepository) {
    await subscriptionRepository.initialize();
  }
  if (calonaviDemoMode) {
    await seedDemoSavedFoods(savedFoodRepository);
    await const FirstMealGuideStore().markSeen();
  }

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
    firstMealGuideStore: const FirstMealGuideStore(),
    lockScreenMealGateway: LockScreenMealGatewayImpl(),
    siriVoiceGateway: SiriVoiceGatewayImpl(),
    pendingRecords: pendingRecords,
    subscriptionRepository: subscriptionRepository,
    usageRecordRepository: remote
        ? SupabaseUsageRecordRepository()
        : const NoOpUsageRecordRepository(),
    coachProposalLog: remote
        ? SupabaseCoachProposalLog()
        : const NoOpCoachProposalLog(),
    plusFunnelRepository: remote
        ? SupabasePlusFunnelRepository()
        : const NoOpPlusFunnelRepository(),
    reviewPromptStore: PreferencesReviewPromptStore(preferences: preferences),
  );
  await controller.initialize();

  runApp(
    AygApp(
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      healthRepository: healthRepository,
      authenticationRepository: authenticationRepository,
      showSplash: true,
    ),
  );
}

Future<String> _demoDirectory() async {
  final home = Platform.environment['HOME'];
  final root = (home == null || home.isEmpty) ? '/tmp' : home;
  final directory = Directory('$root/Documents/calonavi-demo');
  await directory.create(recursive: true);
  return directory.path;
}
