import 'dart:async';

import 'package:ayg/app.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/settings/calculation_references_screen.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/nutrition/calorie_target_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a stalled consent read fails, and only a matching cache passes',
    (tester) async {
      final stalled = Completer<String?>();
      final pending = readTermsServerVersion(
        stalled.future,
        budget: const Duration(milliseconds: 20),
      );
      await tester.pump(const Duration(milliseconds: 30));
      final read = await pending;
      expect(read.failed, isTrue);
      expect(read.serverVersion, isNull);
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: 'user-1',
          cachedVersion: aiDataConsentVersion,
          serverVersion: read.serverVersion,
          serverReadFailed: read.failed,
        ),
        isTrue,
      );
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: null,
          cachedVersion: null,
          serverVersion: read.serverVersion,
          serverReadFailed: read.failed,
        ),
        isFalse,
      );

      final finished = await readTermsServerVersion(
        Future<String?>.value('other-version'),
      );
      expect(finished.failed, isFalse);
      expect(finished.serverVersion, 'other-version');
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: 'user-1',
          cachedVersion: aiDataConsentVersion,
          serverVersion: finished.serverVersion,
          serverReadFailed: finished.failed,
        ),
        isFalse,
      );
    },
  );

  testWidgets('a stalled first sync opens retry instead of spinning forever', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final sync = _HangingSync();
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      termsAgreedFor: (_) async => true,
      initialSyncBudget: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);
    final health = MockHealthRepository(isAvailable: false);

    final pending = controller.handleAuthenticatedSession();
    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        healthRepository: health,
        authenticationRepository: auth,
      ),
    );
    await tester.pump();
    expect(find.text('読み込み中…'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);

    await tester.pump(const Duration(milliseconds: 40));
    await pending;
    await tester.pump();

    expect(controller.isSyncInProgress, isFalse);
    expect(controller.requiresSyncRetry, isTrue);
    expect(controller.syncFailure?.userMessage, '通信に失敗しました');
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('ログアウト'), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);

    sync.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.requiresSyncRetry, isTrue);
    expect(controller.hasInitialSyncCompleted, isFalse);
  });

  testWidgets(
    'a stalled analytics flush does not hold the first loading screen',
    (tester) async {
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final usage = _HangUsage();
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: MockDataSyncRepository(),
        usageRecordRepository: usage,
        termsAgreedFor: (_) async => true,
        initialSyncBudget: const Duration(milliseconds: 30),
      );
      addTearDown(controller.dispose);
      final health = MockHealthRepository(isAvailable: false);

      final pending = controller.initialize();
      await tester.pumpWidget(
        AygApp(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
          healthRepository: health,
          authenticationRepository: auth,
        ),
      );
      await pending.timeout(const Duration(seconds: 2));
      await tester.pump();

      expect(controller.isInitializing, isFalse);
      expect(controller.isSyncInProgress, isFalse);
      expect(find.text('読み込み中…'), findsNothing);
      expect(usage.gate.isCompleted, isFalse);
      usage.gate.complete();
    },
  );

  testWidgets('a profile loaded after the sync deadline is dropped', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final profiles = Completer<UserProfile?>();
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: MockDataSyncRepository(),
      userRepository: _Users(profiles),
      settingsRepository: _Settings(),
      termsAgreedFor: (_) async => true,
      initialSyncBudget: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);

    final pending = controller.handleAuthenticatedSession();
    await tester.pump(const Duration(milliseconds: 40));
    await pending;

    expect(controller.requiresSyncRetry, isTrue);
    expect(controller.profile, isNull);

    profiles.complete(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 60,
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(controller.profile, isNull);
    expect(controller.hasInitialSyncCompleted, isFalse);
    expect(controller.requiresSyncRetry, isTrue);
  });

  testWidgets('calorie screens say the numbers are not medical care', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const CalculationReferencesScreen(),
      ),
    );
    expect(find.text(AppStrings.healthEstimateDisclaimer), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CookCoachScreen()),
    );
    await tester.pump();
    expect(find.text(AppStrings.healthEstimateDisclaimer), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);

    final kcal = TextEditingController(text: '1800');
    final protein = TextEditingController(text: '120');
    final fat = TextEditingController(text: '50');
    final carb = TextEditingController(text: '200');
    addTearDown(kcal.dispose);
    addTearDown(protein.dispose);
    addTearDown(fat.dispose);
    addTearDown(carb.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalorieTargetEditor(
              mode: CalorieTargetMode.automatic,
              onModeChanged: (_) {},
              kcalController: kcal,
              proteinController: protein,
              fatController: fat,
              carbController: carb,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('health-estimate-disclaimer')), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);
  });

  testWidgets('home shows the medical disclaimer under today remaining', (
    tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    addTearDown(controller.dispose);
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 60,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 60,
        targetDate: DateTime(2026, 12, 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日あと'), findsOneWidget);
    expect(find.text(AppStrings.healthEstimateDisclaimer), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);
  });
}

class _HangUsage extends NoOpUsageRecordRepository {
  final gate = Completer<void>();

  @override
  Future<void> flushPending() => gate.future;
}

class _Users implements UserRepositoryBase {
  _Users(this.profiles);

  final Completer<UserProfile?> profiles;

  @override
  Future<UserProfile?> loadProfile() => profiles.future;

  @override
  Future<void> saveProfile(UserProfile profile) async {}

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<void> saveGoal(Goal goal) async {}

  @override
  Future<void> clearAll() async {}
}

class _Settings implements SettingsRepositoryBase {
  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {}

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {}

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<AppSettings> loadAppSettings() async => const AppSettings();

  @override
  Future<void> clearAll() async {}
}

class _HangingSync extends MockDataSyncRepository {
  final gate = Completer<void>();

  @override
  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
  }) async {
    pullRemoteToLocalCalled = true;
    lastUserId = userId;
    await gate.future;
  }
}
