import 'dart:io';

import 'package:ayg/app.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/onboarding/basic_info_screen.dart';
import 'package:ayg/screens/settings/settings_health_activity_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> usePhoneSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'onboarding asks HealthKit without a primer and stays usable if denied',
    (tester) async {
      await usePhoneSurface(tester);
      final health = MockHealthRepository(
        isAvailable: true,
        permissionsGranted: false,
      );
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final controller = AppController(
        healthRepository: health,
        authenticationRepository: auth,
        dataSyncRepository: MockDataSyncRepository(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await tester.pumpWidget(
        AygApp(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'permission-test',
          ),
          healthRepository: health,
          authenticationRepository: auth,
        ),
      );
      await tester.pump();

      expect(find.byType(BasicInfoScreen), findsOneWidget);
      expect(find.text('基本情報を入力'), findsOneWidget);
      expect(find.text('初回設定  1/2'), findsOneWidget);
      expect(find.text('次へ'), findsOneWidget);
      expect(health.requestPermissionsCalled, isTrue);
      expect(controller.useHealthIntegration, isFalse);
      expect(
        find.text('Healthデータを取得できませんでした。取得できない項目は手入力してください。'),
        findsOneWidget,
      );
      expect(find.text('Healthと連携しますか？'), findsNothing);
      expect(find.text('連携しない'), findsNothing);
      expect(find.text('連携する（推奨）'), findsNothing);
      expect(
        File('lib/screens/onboarding/health_setup_screen.dart').existsSync(),
        isFalse,
      );
    },
  );

  testWidgets('granted HealthKit prefills empty basic-info fields', (
    tester,
  ) async {
    await usePhoneSurface(tester);
    final health = MockHealthRepository(
      isAvailable: true,
      permissionsGranted: true,
      profileData: sampleHealthProfileData(),
    );
    final auth = MockAuthenticationRepository();
    addTearDown(auth.dispose);
    final controller = AppController(healthRepository: health);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BasicInfoScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'permission-test',
          ),
          healthPrefill: HealthProfileData.empty,
          authenticationRepository: auth,
          healthRepository: health,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(health.requestPermissionsCalled, isTrue);
    expect(health.fetchProfileDataCalled, isTrue);
    expect(controller.useHealthIntegration, isTrue);
    expect(find.text('1990年 3月 10日'), findsOneWidget);
    expect(find.text('165'), findsOneWidget);
    expect(find.text('58.0'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
    expect(find.text('Healthと連携しますか？'), findsNothing);
  });

  testWidgets('partial HealthKit grant leaves the missing fields editable', (
    tester,
  ) async {
    await usePhoneSurface(tester);
    final health = MockHealthRepository(
      isAvailable: true,
      permissionsGranted: true,
      profileData: const HealthProfileData(heightCm: 172),
    );
    final auth = MockAuthenticationRepository();
    addTearDown(auth.dispose);
    final controller = AppController(healthRepository: health);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BasicInfoScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'permission-test',
          ),
          healthPrefill: HealthProfileData.empty,
          authenticationRepository: auth,
          healthRepository: health,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.useHealthIntegration, isTrue);
    expect(find.text('172'), findsOneWidget);
    expect(find.text('選択してください'), findsOneWidget);
    expect(find.text('58.0'), findsNothing);
    expect(find.text('次へ'), findsOneWidget);
  });

  testWidgets(
    'settings health toggle requests permission only when turning it on',
    (tester) async {
      await usePhoneSurface(tester);
      final health = MockHealthRepository(
        isAvailable: true,
        permissionsGranted: false,
      );
      final controller = AppController(healthRepository: health);
      addTearDown(controller.dispose);
      controller.setNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsHealthActivityScreen(
            controller: controller,
            healthRepository: health,
          ),
        ),
      );
      expect(health.requestPermissionsCalled, isFalse);

      await tester.tap(find.text('連携しない'));
      await tester.pumpAndSettle();
      expect(health.requestPermissionsCalled, isFalse);
      expect(find.text(AppStrings.activityLevel), findsOneWidget);

      await tester.tap(find.text('連携する'));
      await tester.pumpAndSettle();
      expect(health.requestPermissionsCalled, isTrue);
      expect(controller.useHealthIntegration, isFalse);
      expect(find.text(AppStrings.activityLevel), findsOneWidget);
      expect(find.text('Healthと連携しますか？'), findsNothing);
    },
  );

  test('denied health permission does not turn integration on', () async {
    final health = MockHealthRepository(
      isAvailable: true,
      permissionsGranted: false,
    );
    final controller = AppController(healthRepository: health);
    addTearDown(controller.dispose);
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );

    final granted = await controller.enableHealthIntegration();

    expect(granted, isFalse);
    expect(health.requestPermissionsCalled, isTrue);
    expect(controller.useHealthIntegration, isFalse);
  });

  test('os permission inventory matches the request sites', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final healthRepo = File(
      'lib/repositories/platform_health_repository.dart',
    ).readAsStringSync();
    final basicInfo = File(
      'lib/screens/onboarding/basic_info_screen.dart',
    ).readAsStringSync();
    final barcode = File(
      'lib/screens/food/barcode_scanner_screen.dart',
    ).readAsStringSync();
    final photo = File(
      'lib/screens/food/photo_meal_screen.dart',
    ).readAsStringSync();
    final terms = File(
      'lib/screens/legal/terms_agreement_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final goal = File(
      'lib/screens/onboarding/goal_setup_screen.dart',
    ).readAsStringSync();

    expect(healthRepo, contains('_health.requestAuthorization(_readTypes)'));
    expect(basicInfo, contains('health.requestPermissions()'));
    expect(basicInfo, contains('StepIndicator(current: 1, total: 2)'));
    expect(goal, contains('StepIndicator(current: 2, total: 2)'));
    expect(barcode, contains('MobileScanner('));
    expect(barcode, contains('手入力に切り替える'));
    expect(photo, contains('requestFullMetadata: false'));
    expect(photo, contains('ImageSource.camera'));
    expect(photo, contains('ImageSource.gallery'));

    expect(plist, contains('<key>NSHealthShareUsageDescription</key>'));
    expect(plist, contains('<key>NSHealthUpdateUsageDescription</key>'));
    expect(
      plist,
      contains(
        'カロナビはヘルスケアへデータを書き込みません。読み取りに使うヘルスケア連携ライブラリが更新の許可説明を必要とするため、この説明を表示しています。',
      ),
    );
    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
    expect(plist, contains('<key>NSSiriUsageDescription</key>'));
    expect(plist, contains('生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト'));
    expect(healthRepo, contains('requestAuthorization(_readTypes)'));
    expect(healthRepo, isNot(contains('HealthDataAccess.WRITE')));
    expect(healthRepo, isNot(contains('HealthDataAccess.READ_WRITE')));
    final healthSettings = File(
      'lib/screens/settings/settings_health_activity_screen.dart',
    ).readAsStringSync();
    expect(healthSettings, isNot(contains('歩数')));
    expect(healthSettings, contains('アクティブエネルギー'));
    expect(healthSettings, contains('ワークアウト'));
    expect(plist, isNot(contains('診断')));
    expect(plist, isNot(contains('治療')));
    expect(entitlements, contains('com.apple.developer.healthkit'));

    for (final absent in [
      'NSPhotoLibraryUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
      'NSUserTrackingUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
      'NSLocationWhenInUseUsageDescription',
      'NSLocationAlwaysAndWhenInUseUsageDescription',
      'NSContactsUsageDescription',
      'NSCalendarsUsageDescription',
      'NSBluetoothAlwaysUsageDescription',
      'NSMotionUsageDescription',
      'NSFaceIDUsageDescription',
    ]) {
      expect(plist, isNot(contains(absent)), reason: absent);
    }

    expect(AppStrings.termsConsentAi, contains('Anthropic'));
    expect(terms, contains('terms-agreement-agree'));
    expect(terms, contains('AppStrings.termsConsentAi'));

    for (final absent in [
      'app_tracking_transparency',
      'flutter_local_notifications',
      'firebase_messaging',
      'permission_handler',
      'geolocator',
      'speech_to_text',
    ]) {
      expect(pubspec, isNot(contains(absent)), reason: absent);
    }
    expect(pubspec, contains('health:'));
    expect(pubspec, contains('mobile_scanner:'));
    expect(pubspec, contains('image_picker:'));

    const banned = [
      'UNUserNotificationCenter',
      'ATTrackingManager',
      'CLLocationManager',
      'SFSpeechRecognizer',
      'AVAudioSession',
      'PHPhotoLibrary',
      'requestSiriAuthorization',
    ];
    final sources = <String>[
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync()),
      ...Directory('ios/Runner')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.swift'))
          .map((file) => file.readAsStringSync()),
    ];
    for (final token in banned) {
      expect(
        sources.where((source) => source.contains(token)),
        isEmpty,
        reason: token,
      );
    }
  });
}
