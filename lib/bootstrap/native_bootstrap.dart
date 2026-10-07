import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/development_plus_preview.dart';
import '../config/test_purchase.dart';
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
  final alcoholRepository = AlcoholRepository(isar);
  final savedFoodRepository = IsarSavedFoodRepository(isar);
  final mealTemplateRepository = MealTemplateRepository(isar);
  final workoutTemplateRepository = WorkoutTemplateRepository(isar);

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

  final HealthRepository healthRepository = PlatformHealthRepository(
    weightRepository: weightRepository,
    isar: isar,
  );

  final AuthenticationRepository authenticationRepository =
      SupabaseConfig.isConfigured
      ? SupabaseAuthenticationRepository()
      : UnconfiguredAuthenticationRepository();

  final preferences = await SharedPreferences.getInstance();
  final pendingRecords = PendingRecordStore(preferences: preferences);
  final DataSyncRepository dataSyncRepository = SupabaseConfig.isConfigured
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
  final analytics = AnalyticsService(
    preferences: preferences,
    queue: AnalyticsQueue(isar: isar),
    transport: SupabaseAnalyticsTransport(),
    bridge: bridge,
    appVersion: '1.0.0',
    appBuild: '1',
    onUnauthorized: () async {
      if (SupabaseConfig.isConfigured) {
        await Supabase.instance.client.auth.refreshSession();
      }
    },
    onConsentRow: uploadAnalyticsConsent,
  );
  analytics.deviceModel = await bridge.deviceModel();
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
  final subscriptionRepository = StoreKitSubscriptionRepository(
    preferences: preferences,
    developmentPlusPreview: developmentPlusPreview,
    testPurchaseEnabled: testPurchaseEnabled,
  );
  await subscriptionRepository.initialize();

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
    usageRecordRepository: SupabaseConfig.isConfigured
        ? SupabaseUsageRecordRepository()
        : const NoOpUsageRecordRepository(),
    coachProposalLog: SupabaseConfig.isConfigured
        ? SupabaseCoachProposalLog()
        : const NoOpCoachProposalLog(),
    plusFunnelRepository: SupabaseConfig.isConfigured
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
