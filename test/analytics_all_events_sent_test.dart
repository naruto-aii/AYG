import 'dart:convert';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/calculation/landing_guidance.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_report.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/saved_food_draft.dart';
import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/plus_funnel_repository.dart';
import 'package:ayg/repositories/storekit_subscription_repository.dart';
import 'package:ayg/repositories/sync_step_runner.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/analytics/analytics_lifecycle.dart';
import 'package:ayg/services/analytics/analytics_route_observer.dart';
import 'package:ayg/services/analytics/apple_ads_attribution.dart';
import 'package:ayg/services/analytics/catalog_actions.dart';
import 'package:ayg/services/analytics/event_names.dart';
import 'package:ayg/services/analytics/native_analytics_bridge.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/siri_voice_gateway.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/services/usage_record.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uuid/uuid.dart';

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'every catalog event is sent through a real handler',
    (tester) async {
      await tester.runAsync(() async {
        await tester.binding.setSurfaceSize(const Size(900, 2200));
        final isarHarness = await setUpIsarHarness();
        final userId = '11111111-1111-4111-8111-111111111111';
        // 送信待ちの nextAttemptAt は実時刻。flush の時計がそれより前だと
        // 列に残ったまま送られない。
        final clock = _MutableClock(DateTime.utc(2027, 1, 1, 12));
        final analytics = await AnalyticsHarness.open(
          isar: isarHarness.isar,
          clock: () => clock.value,
        );
        addTearDown(() => Analytics.service = null);
        await analytics.service.grantConsent(surface: 'first_launch');
        await analytics.service.setCurrentUser(userId);
        final meals = _Meals(userId);
        final siri = _Siri();
        final auth = MockAuthenticationRepository(
          currentUser: AuthUser(id: userId, email: 'a@example.com'),
        );
        final controller = AppController(
          healthRepository: MockHealthRepository(isAvailable: false),
          authenticationRepository: auth,
          dataSyncRepository: MockDataSyncRepository(),
          userRepository: isarHarness.userRepository,
          settingsRepository: isarHarness.settingsRepository,
          foodRepository: isarHarness.foodRepository,
          exerciseRepository: isarHarness.exerciseRepository,
          alcoholRepository: isarHarness.alcoholRepository,
          weightRepository: isarHarness.weightRepository,
          savedFoodRepository: isarHarness.savedFoodRepository,
          mealTemplateRepository: isarHarness.mealTemplateRepository,
          workoutTemplateRepository: isarHarness.workoutTemplateRepository,
          lockScreenMealGateway: meals,
          siriVoiceGateway: siri,
        );
        addTearDown(controller.dispose);
        controller.profile = UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 170,
          weightKg: 70,
        );
        controller.goal = Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: DateTime(2026, 12, 31),
        );
        controller.nutritionSettings = const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        );
        final lifecycle = AnalyticsLifecycle(
          service: analytics.service,
          preferences: analytics.preferences,
          clock: () => clock.value,
        );
        final observer = AnalyticsRouteObserver(service: analytics.service);
        final ads = AppleAdsAttribution(
          service: analytics.service,
          preferences: analytics.preferences,
          client: MockClient(
            (request) async => http.Response('{"attribution":false}', 200),
          ),
          retryDelay: Duration.zero,
        );
        analytics.bridge.adsToken = 'attribution-token';
        analytics.bridge.transaction = {
          'originalPurchaseDate': '2026-10-07T00:00:00Z',
          'originalAppVersion': '1.0',
          'environment': 'sandbox',
        };

        Future<void> usePaywall() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: CalonaviPlusEntryScreen(repository: _PricedPlus()),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.ensureVisible(
            find.byKey(const Key('plus-plan-monthly')),
          );
          await tester.tap(find.byKey(const Key('plus-plan-monthly')));
          await tester.pump();
          await tester.ensureVisible(find.byKey(const Key('plus-purchase')));
          await tester.tap(find.byKey(const Key('plus-purchase')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.ensureVisible(find.text('購入を復元'));
          await tester.tap(find.text('購入を復元'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }

        final food = FoodEntry(
          id: 'food-1',
          name: 'ご飯',
          quantity: 1,
          loggedAt: DateTime.utc(2026, 10, 7, 12),
        );
        final exercise = ExerciseEntry(
          id: 'ex-1',
          name: '歩行',
          durationMin: 10,
          burnedKcal: 30.0,
          loggedAt: DateTime.utc(2026, 10, 7, 12),
        );
        final alcohol = AlcoholEntry(
          id: 'alc-1',
          beverageName: 'ビール',
          amount: 350.0,
          unit: 'ml',
          alcoholPercentage: 5.0,
          totalCalories: 140.0,
          pureAlcoholGrams: 14.0,
          alcoholCalories: 98.0,
          consumedAt: DateTime.utc(2026, 10, 7, 18),
        );
        final saved = SavedFood(
          foodId: 'saved-1',
          ownerUserId: 'other-user',
          name: '味噌汁',
          normalizedName: '味噌汁',
          baseAmount: 1,
          unitType: FoodUnitType.serving,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );

        final procedures = <String, Future<void> Function()>{
          'app_install_first_open': () => lifecycle.onColdStart(),
          'app_open': () => lifecycle.onColdStart(launchSource: 'icon'),
          'app_foreground': () => lifecycle.onForeground(),
          'app_background': () => lifecycle.onBackground(),
          'session_start': () async {
            clock.value = clock.value.add(const Duration(minutes: 31));
            await lifecycle.onColdStart();
          },
          'session_end': () => lifecycle.onBackground(),
          'app_version_changed': () async {
            await analytics.preferences.setString(
              'analytics_last_app_version',
              '0.9.0',
            );
            await lifecycle.onColdStart();
          },
          'screen_view': () async {
            observer.didPush(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'home'),
                builder: (_) => const SizedBox(),
              ),
              null,
            );
          },
          'tab_select': () async {
            controller.recordScreenAction(
              screen: UsageScreen.home,
              action: UsageScreenAction.select,
            );
          },
          'analytics_consent_shown': () =>
              analytics.service.grantConsent(surface: 'settings'),
          'login_tap': () async => CatalogActions.loginTap('apple'),
          'login_result': () async => CatalogActions.loginResult(
            provider: 'apple',
            result: 'success',
            isNewAccount: false,
          ),
          'logout': () => controller.logout(),
          'onboarding_step_view': () async =>
              CatalogActions.onboardingStepView('goal'),
          'onboarding_step_complete': () async =>
              CatalogActions.onboardingStepComplete(
                step: 'goal',
                durationMs: 10,
                skipped: false,
              ),
          'onboarding_complete': () => controller.completeOnboarding(),
          'first_meal_guide_shown': () async =>
              controller.offerFirstMealGuide(),
          'first_meal_guide_finished': () async =>
              controller.finishFirstMealGuide(),
          'health_permission_result': () =>
              controller.enableHealthIntegration(),
          'health_integration_changed': () =>
              controller.enableHealthIntegration(),
          'health_sync_result': () => controller.resyncHealthData(),
          'food_search': () async {
            controller.recordFoodSearch(
              source: FoodSearchSources.savedFood,
              query: 'ご飯',
            );
          },
          'food_search_result_select': () async {
            CatalogActions.foodSearchResultSelect(
              source: 'saved',
              position: 0,
              resultCount: 1,
              queryLength: 2,
              itemKind: 'saved_food',
            );
          },
          'food_entry_added': () => controller.addFood(food),
          'food_entry_updated': () => controller.updateFood(food),
          'food_entry_deleted': () => controller.deleteFood(food.id),
          'food_entry_restored': () => controller.restoreFoodEntry(food),
          'food_memo_saved': () => controller.updateFoodMemo(food, '昼'),
          'recent_foods_open': () async =>
              CatalogActions.recentFoodsOpen(isPlus: false),
          'barcode_scan_open': () async => CatalogActions.barcodeScanOpen(),
          'barcode_scan_result': () async => CatalogActions.barcodeScanResult(
            method: 'camera',
            result: 'found',
            durationMs: 10,
          ),
          'barcode_lookup_result': () async =>
              CatalogActions.barcodeLookupResult(
                result: 'found',
                latencyMs: 10,
              ),
          'saved_food_created': () => controller.createSavedFood(
            const SavedFoodDraft(
              name: 'おにぎり',
              baseAmount: 1.0,
              servingUnitLabel: '個',
              unitType: FoodUnitType.piece,
              kcalPerBase: 180.0,
              proteinPerBase: 3.0,
              fatPerBase: 1.0,
              carbPerBase: 40.0,
            ),
          ),
          'saved_food_updated': () => controller.updateSavedFood(
            SavedFood(
              foodId: 'saved-local',
              ownerUserId: userId,
              name: 'おにぎり',
              normalizedName: 'おにぎり',
              baseAmount: 1,
              unitType: FoodUnitType.piece,
              createdAt: DateTime.utc(2026, 10, 1),
              updatedAt: DateTime.utc(2026, 10, 1),
            ),
          ),
          'saved_food_deleted': () => controller.deleteSavedFood('saved-local'),
          'public_food_published': () =>
              controller.publishSavedFood('saved-local'),
          'public_food_duplicate_warning': () async {
            CatalogActions.publicFoodDuplicateWarning(
              kind: 'exact',
              choice: 'blocked',
            );
          },
          'public_food_search_quota': () =>
              controller.searchPublicSavedFoods('ご飯'),
          'public_food_rated': () => controller.setPublicFoodGood(saved),
          'public_food_reported': () => controller.submitPublicFoodReport(
            food: saved,
            reasonCode: FoodReportReasonCode.other,
          ),
          'food_creator_blocked': () =>
              controller.blockFoodCreator('other-user'),
          'meal_template_saved': () => controller.saveMealTemplate(
            draft: const MealTemplateDraft(
              name: '朝',
              items: [
                MealTemplateItemDraft(
                  name: 'ご飯',
                  baseAmount: 100.0,
                  unitType: FoodUnitType.g,
                  consumedAmount: 100.0,
                  sortOrder: 1,
                ),
              ],
            ),
          ),
          'meal_template_deleted': () =>
              controller.deleteMealTemplate('missing'),
          'meal_template_applied': () =>
              controller.applyMealTemplate(templateId: 'missing'),
          'official_food_detail_view': () async {
            CatalogActions.officialFoodDetailView('01001');
          },
          'exercise_search': () async {
            controller.recordExerciseSearch(
              source: ExerciseSearchSources.catalog,
              query: '歩行',
            );
          },
          'exercise_search_result_select': () async {
            CatalogActions.exerciseSearchResultSelect(
              source: 'exercise_catalog',
              position: 0,
              resultCount: 1,
            );
          },
          'exercise_entry_added': () => controller.addExercise(exercise),
          'exercise_entry_updated': () => controller.updateExercise(exercise),
          'exercise_entry_deleted': () =>
              controller.deleteExercise(exercise.id),
          'exercise_entry_restored': () =>
              controller.restoreExerciseEntry(exercise),
          'workout_template_saved': () => controller.saveWorkoutTemplate(
            draft: WorkoutTemplateDraft(
              name: '歩き',
              items: [
                WorkoutTemplateItem(
                  itemId: 'item-1',
                  name: '歩行',
                  durationMin: 10,
                  sortOrder: 1,
                ),
              ],
            ),
          ),
          'workout_template_deleted': () =>
              controller.deleteWorkoutTemplate('missing'),
          'custom_activity_saved': () =>
              controller.saveCustomActivityTemplate(exercise),
          'weight_entry_added': () => controller.recordManualWeight(70),
          'weight_entry_updated': () => controller.updateWeightEntry(
            WeightEntry(
              id: 'w-1',
              weightKg: 70,
              recordedAt: DateTime.utc(2026, 10, 7),
              source: WeightSource.manual,
            ),
          ),
          'alcohol_entry_added': () => controller.addAlcohol(alcohol),
          'alcohol_entry_changed': () => controller.deleteAlcohol(alcohol.id),
          'goal_updated': () => controller.saveGoalSettings(
            Goal(
              type: GoalType.maintain,
              targetWeightKg: 70,
              targetDate: DateTime(2026, 12, 31),
            ),
          ),
          'landing_guidance_shown': () => controller.applyLandingSuggestion(
            LandingGuidanceAction.extendDate,
          ),
          'landing_guidance_tap': () => controller.applyLandingSuggestion(
            LandingGuidanceAction.changeWeight,
          ),
          'profile_updated': () => controller.updateBasicProfile(
            birthDate: DateTime(1990, 1, 1),
            gender: Gender.male,
            heightCm: 170,
            displayName: '太郎',
          ),
          'settings_changed': () async {
            CatalogActions.settingsChanged(
              settingKey: 'health',
              newValue: 'on',
            );
          },
          'history_day_selected': () async =>
              CatalogActions.historyDaySelected(1),
          'legal_document_view': () async =>
              CatalogActions.legalDocumentView('privacy'),
          'contact_tap': () async => CatalogActions.contactTap('email'),
          'widget_tap': () async {
            final id = const Uuid().v4();
            final when = DateTime.utc(2026, 10, 7, 8, 0, 0);
            analytics.bridge.pending.add(
              NativePendingFile(
                name: '$id.json',
                json: _native(
                  id: id,
                  name: 'widget_tap',
                  origin: 'home_widget',
                  stream: 'widget',
                  when: when,
                  props: {
                    'surface': 'home',
                    'slot': 0,
                    'kind': 'meal',
                    'result': 'registered',
                  },
                  userId: userId,
                ),
              ),
            );
            await analytics.service.importNativePending();
          },
          'widget_registration_imported': () =>
              controller.syncLockScreenMeals(),
          'widget_config_saved': () => controller.saveLockScreenMealConfig(
            LockScreenMealConfig.defaults(),
          ),
          'widget_presence': () => lifecycle.onColdStart(),
          'siri_request_started': () async => _queueNative(
            analytics,
            name: 'siri_request_started',
            props: {'intent': 'log_food', 'has_parameter': true},
            userId: userId,
          ),
          'siri_prompt': () async => _queueNative(
            analytics,
            name: 'siri_prompt',
            props: {
              'request_id': 'r1',
              'prompt_kind': 'disambiguation',
              'answered': true,
            },
            userId: userId,
          ),
          'siri_request_finished': () async => _queueNative(
            analytics,
            name: 'siri_request_finished',
            props: {
              'request_id': 'r1',
              'status': 'registered',
              'stop_reason': 'done',
              'prompts_count': 0,
              'duration_ms': 10,
              'items_count': 1,
            },
            userId: userId,
          ),
          'siri_registration_imported': () => controller.syncSiriVoiceLogs(),
          'siri_open_search': () async {
            siri.openSearch = '{"kind":"food","query":"みそ"}';
            await controller.syncSiriVoiceLogs();
          },
          'coach_proposal_shown': () async => CatalogActions.coachProposalShown(
            coachProposalLogId: 'local',
            proposalsCount: 1,
          ),
          'coach_proposal_registered': () async =>
              CatalogActions.coachProposalRegistered(
                coachProposalLogId: 'local',
                foodEntryIds: const ['food-1'],
              ),
          'cook_coach_open': () async => CatalogActions.cookCoachOpen('lunch'),
          'cook_coach_generate': () async => CatalogActions.cookCoachGenerate(
            latencyMs: 1,
            inputTokens: 1,
            outputTokens: 1,
            retried: false,
            result: 'ok',
          ),
          'cook_coach_retry': () async => CatalogActions.cookCoachRetry(
            latencyMs: 1,
            inputTokens: 1,
            outputTokens: 1,
          ),
          'cook_coach_register': () async => CatalogActions.cookCoachRegister(
            foodEntryIds: const ['food-1'],
            pattern: 'a',
          ),
          'cook_coach_cap': () async => CatalogActions.cookCoachCap(),
          'share_tap': () async {
            CatalogActions.shareTap(card: 'meal', result: 'completed');
          },
          'announcement_read': () async =>
              CatalogActions.announcementRead('list'),
          'review_prompt_shown': () async =>
              CatalogActions.reviewPromptShown('streak'),
          'review_prompt_answer': () async =>
              CatalogActions.reviewPromptAnswer('decline'),
          'paywall_open': usePaywall,
          'paywall_close': usePaywall,
          'plan_select': usePaywall,
          'purchase_tap': usePaywall,
          'purchase_result': () async {
            emitStoreKitPurchaseResult(
              productId: SubscriptionCatalog.monthlyProductId,
              status: 'purchased',
            );
          },
          'restore_tap': usePaywall,
          'restore_result': usePaywall,
          'gate_shown': () async {
            controller.recordPlusFunnel(
              event: PlusFunnelEvent.gateShown,
              feature: PlusFunnelFeature.mealTemplateLimit,
            );
          },
          'gate_tap': () async {
            controller.recordPlusFunnel(
              event: PlusFunnelEvent.gateTap,
              feature: PlusFunnelFeature.mealTemplateLimit,
            );
          },
          'entitlement_observed': () => controller.refreshPaidEntitlement(),
          'apple_ads_attribution': () => ads.captureOnce(),
          'app_error': () async => CatalogActions.appError(
            errorType: 'StateError',
            where: 'test',
            fatal: false,
          ),
          'sync_failure': () async {
            try {
              await runSyncStep<void>(
                step: SyncStep.fetchFoodEntries,
                repository: 'test',
                tableName: 'food_entries',
                operation: 'pull',
                action: () async => throw Exception('down'),
              );
            } on SyncStepException {
              // 失敗を記録したあとに例外が戻る。
            }
          },
          'local_data_cleared': () => controller.logout(force: true),
          'analytics_queue_health': () =>
              analytics.service.reportHealth(force: true),
          'account_deletion_started': () async =>
              CatalogActions.accountDeletionStarted('confirm'),
        };

        expect(procedures.keys.toSet(), AnalyticsEventNames.all.toSet());

        for (final name in AnalyticsEventNames.all) {
          final before = analytics.count(name);
          if (auth.currentUser == null) {
            auth.setCurrentUser(AuthUser(id: userId, email: 'a@example.com'));
          }
          controller.profile ??= UserProfile(
            birthDate: DateTime(1990, 1, 1),
            gender: Gender.male,
            heightCm: 170,
            weightKg: 70,
            displayName: '太郎',
          );
          controller.goal ??= Goal(
            type: GoalType.maintain,
            targetWeightKg: 70,
            targetDate: DateTime(2026, 12, 31),
          );
          controller.nutritionSettings ??= const NutritionSettings(
            useHealthIntegration: false,
            activityLevel: ActivityLevel.moderate,
          );
          try {
            await procedures[name]!();
          } catch (_) {}
          await analytics.service.settled;
          if (analytics.service.currentUserId == null) {
            await analytics.service.setCurrentUser(userId);
          }
          await analytics.service.flush();
          expect(analytics.count(name), greaterThan(before), reason: name);
          final row = analytics.holding.delivered.lastWhere(
            (item) => item['event_name'] == name,
          );
          expect(row['event_id'], isNotEmpty);
          expect(row['user_id'], userId);
          expect(row['occurred_at'], isNotEmpty);
          expect(row['origin'], isNotEmpty);
          expect(row['install_id'], isNotEmpty);
          expect(row['stream'], isNotEmpty);
          expect(row['sequence_number'], greaterThan(0));
          expect(row['advertising_use'], isFalse);
          expect(row['props'], isA<Map>());
          expect(
            utf8.encode(jsonEncode(row['props'])).length,
            lessThanOrEqualTo(8192),
          );
        }

        final widget = analytics.holding.delivered.lastWhere(
          (row) => row['event_name'] == 'widget_tap',
        );
        expect(widget['origin'], 'home_widget');
        final savedConfig = analytics.holding.delivered.lastWhere(
          (row) => row['event_name'] == 'widget_config_saved',
        );
        final savedProps = savedConfig['props'] as Map;
        expect(savedProps['surface'], 'home');
        expect(savedProps['assigned_meal_slots'], 3);
        expect(savedProps['assigned_exercise_slots'], 2);
        expect(widget['occurred_at'], contains('2026-10-07'));
        final siriRow = analytics.holding.delivered.lastWhere(
          (row) => row['event_name'] == 'siri_request_finished',
        );
        expect(siriRow['origin'], 'siri');
      });
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

Future<void> _queueNative(
  AnalyticsHarness analytics, {
  required String name,
  required Map<String, Object?> props,
  required String userId,
}) async {
  final id = const Uuid().v4();
  analytics.bridge.pending.add(
    NativePendingFile(
      name: '$id.json',
      json: _native(
        id: id,
        name: name,
        origin: 'siri',
        stream: 'siri',
        when: DateTime.utc(2026, 10, 7, 9),
        props: props,
        userId: userId,
      ),
    ),
  );
  await analytics.service.importNativePending();
}

String _native({
  required String id,
  required String name,
  required String origin,
  required String stream,
  required DateTime when,
  required Map<String, Object?> props,
  required String userId,
}) {
  return jsonEncode({
    'event_id': id,
    'event_name': name,
    'occurred_at': when.toIso8601String(),
    'origin': origin,
    'install_id': '',
    'stream': stream,
    'sequence_number': 1,
    'app_version': '1.0.0',
    'app_build': '1',
    'schema_version': 1,
    'props': props,
    'owner_user_id': userId,
  });
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;
}

class _Meals implements LockScreenMealGateway {
  _Meals(this.userId);

  final String userId;

  @override
  Future<void> acknowledge(List<String> registrationIds) async {}

  @override
  Future<bool> isPaid() async => true;

  @override
  Future<LockScreenMealConfig> loadConfig() async =>
      LockScreenMealConfig.defaults();

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async {
    return [
      PendingLockScreenMeal(
        registrationId: 'reg-1',
        ownerUserId: userId,
        slot: 0,
        templateId: 'widget-meal-0',
        mealGroupId: 'group',
        mealGroupName: '朝',
        loggedAt: DateTime.utc(2026, 10, 7, 8),
        entries: [
          FoodEntry(
            id: 'widget-food',
            name: 'ご飯',
            quantity: 1,
            loggedAt: DateTime.utc(2026, 10, 7, 8),
          ),
        ],
        surface: 'lock',
      ),
    ];
  }

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {}

  @override
  Future<void> setPaid(bool isPaid) async {}
}

class _Siri implements SiriVoiceGateway {
  String? openSearch = '{"kind":"food","query":"みそ"}';

  @override
  Future<void> acknowledge(List<String> ids) async {}

  @override
  Future<void> clearOpenSearch() async {
    openSearch = null;
  }

  @override
  Future<void> publishCatalog(String catalogJson) async {}

  @override
  Future<String?> readOpenSearch() async => openSearch;

  @override
  Future<String> readPending() async => '[]';
}

class _PricedPlus extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥4,900',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥8,800',
      ),
      loadFailed: false,
    );
  }
}
