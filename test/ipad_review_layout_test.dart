import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/announcement.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/announcement_read_store.dart';
import 'package:ayg/repositories/announcement_repository.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/auth/login_screen.dart';
import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/food/ai_food_lookup_screen.dart';
import 'package:ayg/screens/food/food_memo_dialog.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/onboarding/activity_level_screen.dart';
import 'package:ayg/screens/onboarding/basic_info_screen.dart';
import 'package:ayg/screens/onboarding/goal_setup_screen.dart';
import 'package:ayg/screens/onboarding/health_setup_screen.dart';
import 'package:ayg/screens/settings/account_deletion_screen.dart';
import 'package:ayg/screens/settings/lock_screen_meal_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/settings/siri_voice_setup_screen.dart';
import 'package:ayg/screens/settings/widget_exercise_pattern_screen.dart';
import 'package:ayg/screens/shell/main_shell_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:ayg/widgets/layout/app_frame.dart';
import 'package:ayg/widgets/saved_food/block_food_creator_dialog.dart';
import 'package:ayg/widgets/saved_food/public_food_report_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

/// iPhone は今の配置のまま。iPad は 13/11 インチの縦横と、
/// Split View / Slide Over の狭い幅ではみ出さないこと。
///
/// `IPAD_SHOT_DIR` があるとき、各画面の PNG を書く。
/// `IPAD_ALLOW_OVERFLOW=1` のときは、直す前の画面を残すために失敗させない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  final shotDir = Platform.environment['IPAD_SHOT_DIR'];
  final allowOverflow = Platform.environment['IPAD_ALLOW_OVERFLOW'] == '1';

  testWidgets('every review screen fits iPhone and iPad windows', (
    tester,
  ) async {
    // 不変条件の検査は tearDown より前。ここで戻さないとテストが落ちる。
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final overflows = <String>[];
    try {
      await _audit(tester, overflows, shotDir, allowOverflow);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _audit(
  WidgetTester tester,
  List<String> overflows,
  String? shotDir,
  bool allowOverflow,
) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      overflows.add(text.split('\n').first);
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  final auth = MockAuthenticationRepository(
    currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
  );
  addTearDown(auth.dispose);
  final health = MockHealthRepository(isAvailable: false);
  final controller = AppController(
    healthRepository: health,
    authenticationRepository: auth,
  );
  addTearDown(controller.dispose);
  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 175,
      weightKg: 70,
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
      targetWeightKg: 70,
      targetDate: DateTime(2026, 12, 31),
    ),
  );
  final facts = OpenFoodFactsService(userAgent: 'ipad-layout-test');

  final screens = <String, Widget Function()>{
    'login': () =>
        LoginScreen(controller: controller, authenticationRepository: auth),
    'terms': () => const LegalDocumentScreen(document: LegalDocument.terms),
    'onboarding_health': () => HealthSetupScreen(
      controller: controller,
      openFoodFactsService: facts,
      healthRepository: health,
      authenticationRepository: auth,
    ),
    'onboarding_basic': () => BasicInfoScreen(
      controller: controller,
      openFoodFactsService: facts,
      healthPrefill: HealthProfileData.empty,
      authenticationRepository: auth,
      healthRepository: health,
    ),
    'onboarding_activity': () => ActivityLevelScreen(
      controller: controller,
      openFoodFactsService: facts,
      authenticationRepository: auth,
      healthRepository: health,
    ),
    'onboarding_goal': () => GoalSetupScreen(
      controller: controller,
      openFoodFactsService: facts,
      authenticationRepository: auth,
      healthRepository: health,
    ),
    'home': () => HomeScreen(
      controller: controller,
      openFoodFactsService: facts,
      announcementRepository: _EmptyAnnouncements(),
      announcementReadStore: _EmptyReads(),
    ),
    'shell': () => MainShellScreen(
      controller: controller,
      openFoodFactsService: facts,
      authenticationRepository: auth,
      healthRepository: health,
    ),
    'food_search': () => MealFoodSearchScreen(
      controller: controller,
      searchOverrides: CombinedFoodSearchOverrides(
        searchSaved: (_) async => const [],
        searchOfficial: (_) async => const OfficialFoodSearchResult(),
        searchPublic: (_) async => const [],
        debounce: Duration.zero,
      ),
    ),
    'ai_search': () => AiFoodLookupScreen(
      controller: controller,
      query: '親子丼',
      loggedAt: DateTime(2026, 10, 9, 12),
      client: AiFoodLookupClient(
        invoke: (_) async => {
          'ok': true,
          'usage_id': 'usage-1',
          'cache_hit': true,
          'candidates': [
            {
              'name': '親子丼',
              'amount': '1杯',
              'kcal': 700,
              'protein_g': 30,
              'fat_g': 20,
              'carb_g': 80,
              'known_product': false,
            },
          ],
        },
      ),
    ),
    'photo': () => PhotoMealScreen(
      controller: controller,
      loggedAt: DateTime(2026, 10, 9, 12),
      client: PhotoMealClient(invoke: (_) async => null),
    ),
    'photo_confirm': () => PhotoMealConfirmScreen(
      controller: controller,
      loggedAt: DateTime(2026, 10, 9, 12),
      hadUserDishName: true,
      analysis: const PhotoMealAnalysis(
        usageId: 'usage-photo',
        estimate: PhotoMealEstimate(
          dishName: '親子丼',
          amount: '1杯',
          kcal: 700,
          proteinG: 30,
          fatG: 20,
          carbG: 80,
          confidence: 0.4,
          items: [],
        ),
      ),
    ),
    'coach': () => DailyCoachScreen(
      introStore: _SeenIntro(),
      now: DateTime(2026, 10, 9, 8, 30),
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: planCoachDay(
          foods: CoachFoodCatalog.stocks,
          excludedFoodCodes: const {},
          remainingKcal: 1500,
          now: DateTime(2026, 10, 9, 8, 30),
        ),
      ),
    ),
    'cook_coach': () => CookCoachScreen(
      now: DateTime(2026, 10, 9, 12),
      target: const CookCoachMealTarget(
        slot: MealSlot.lunch,
        kcal: 600,
        proteinG: 30,
        fatG: 15,
        carbG: 70,
        remainingKcal: 1200,
        remainingProteinG: 60,
        remainingFatG: 30,
        remainingCarbG: 140,
      ),
    ),
    'paywall': () => CalonaviPlusEntryScreen(
      repository: UnavailableSubscriptionRepository(),
    ),
    'settings': () => SettingsScreen(
      controller: controller,
      authenticationRepository: auth,
      healthRepository: health,
      openFoodFactsService: facts,
      showLockScreenMeal: true,
      supportEmail: 'support@ayg.life',
    ),
    'account_deletion': () => AccountDeletionScreen(
      controller: controller,
      authenticationRepository: auth,
      supportEmail: 'support@ayg.life',
    ),
    'siri_setup': () => const SiriVoiceSetupScreen(),
    'widget_setup': () => LockScreenMealScreen(controller: controller),
    'widget_exercise': () =>
        const WidgetExercisePatternScreen(initial: <WidgetExercisePattern>[]),
  };

  for (final screen in screens.entries) {
    for (final device in _devices) {
      await _pump(
        tester,
        device: device,
        home: screen.value(),
        overflows: overflows,
        label: '${screen.key}/${device.name}',
        shotDir: shotDir,
      );
    }
  }

  for (final device in _keyboardDevices) {
    await _pump(
      tester,
      device: device,
      keyboard: 340,
      home: PhotoMealScreen(
        controller: controller,
        loggedAt: DateTime(2026, 10, 9, 12),
        client: PhotoMealClient(invoke: (_) async => null),
      ),
      overflows: overflows,
      label: 'photo_keyboard/${device.name}',
      shotDir: shotDir,
    );
    await _pump(
      tester,
      device: device,
      keyboard: 340,
      home: GoalSetupScreen(
        controller: controller,
        openFoodFactsService: facts,
        authenticationRepository: auth,
        healthRepository: health,
      ),
      overflows: overflows,
      label: 'goal_keyboard/${device.name}',
      shotDir: shotDir,
    );
  }

  await _pumpDialog(
    tester,
    name: 'report',
    shotDir: shotDir,
    overflows: overflows,
    visible: '公開食品を通報',
    open: (context) => showPublicFoodReportDialog(
      context: context,
      controller: controller,
      food: _publicFood(),
    ),
  );
  await _pumpDialog(
    tester,
    name: 'block',
    shotDir: shotDir,
    overflows: overflows,
    visible: '作成者をブロック',
    open: (context) => confirmBlockFoodCreator(
      context: context,
      controller: controller,
      creatorUserId: 'creator-1',
    ),
  );
  await _pumpDialog(
    tester,
    name: 'memo',
    shotDir: shotDir,
    overflows: overflows,
    keyboard: 340,
    visible: 'メモ',
    open: (context) => askFoodMemo(context, initial: '油多め'),
  );
  await _pump(
    tester,
    device: _ipad13Portrait,
    home: AccountDeletionScreen(
      controller: controller,
      authenticationRepository: auth,
      supportEmail: 'support@ayg.life',
    ),
    overflows: overflows,
    label: 'account_deletion_dialog/ipad13_portrait',
    shotDir: shotDir,
    afterPump: (tester) async {
      final button = find.text('削除する');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('アカウントを削除しますか'), findsOneWidget);
    },
  );
  await _pump(
    tester,
    device: _ipad13Portrait,
    home: CalonaviPlusEntryScreen(
      repository: UnavailableSubscriptionRepository(),
    ),
    overflows: overflows,
    label: 'paywall_sheet/ipad13_portrait',
    shotDir: shotDir,
    afterPump: (tester) async {
      final link = find.byKey(const Key('plus-more-features'));
      await tester.scrollUntilVisible(link, 200);
      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('plus-more-features-sheet')), findsOneWidget);
    },
  );

  while (tester.takeException() != null) {}
  if (overflows.isNotEmpty) {
    // ignore: avoid_print
    print('OVERFLOWS\n${overflows.join('\n')}');
  }
  if (!allowOverflow) {
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  }
}

class _Device {
  const _Device(this.name, this.size);
  final String name;
  final Size size;
}

const _iphone = _Device('iphone', Size(390, 844));
const _ipad13Portrait = _Device('ipad13_portrait', Size(1032, 1376));

const _devices = <_Device>[
  _iphone,
  _Device('iphone_pro_max', Size(430, 932)),
  _Device('ipad11_portrait', Size(834, 1194)),
  _Device('ipad11_landscape', Size(1194, 834)),
  _ipad13Portrait,
  _Device('ipad13_landscape', Size(1376, 1032)),
  _Device('slide_over', Size(320, 1194)),
  _Device('split_half_13', Size(678, 1032)),
  _Device('split_narrow', Size(375, 834)),
];

const _keyboardDevices = <_Device>[
  _iphone,
  _Device('ipad11_landscape', Size(1194, 834)),
  _ipad13Portrait,
  _Device('slide_over', Size(320, 1194)),
];

const _overlayLabels = {
  'report/ipad13_portrait',
  'block/ipad13_portrait',
  'memo/ipad13_portrait',
  'account_deletion_dialog/ipad13_portrait',
  'paywall_sheet/ipad13_portrait',
};

const _goldenNames = {
  'login/iphone',
  'home/iphone',
  'paywall/iphone',
  'settings/iphone',
  'food_search/iphone',
  'photo/iphone',
  'login/ipad13_portrait',
  'terms/ipad13_portrait',
  'home/ipad13_portrait',
  'paywall/ipad13_portrait',
  'settings/ipad13_portrait',
  'photo/ipad13_portrait',
  'coach/ipad13_portrait',
  'food_search/ipad13_portrait',
  'ai_search/ipad13_portrait',
  'login/ipad11_landscape',
  'home/ipad11_landscape',
  'paywall/ipad11_landscape',
  'shell/ipad13_portrait',
  'shell/slide_over',
  'photo_keyboard/ipad11_landscape',
  'report/ipad13_portrait',
  'block/ipad13_portrait',
  'memo/ipad13_portrait',
  'account_deletion_dialog/ipad13_portrait',
  'paywall_sheet/ipad13_portrait',
  'siri_setup/ipad13_portrait',
  'widget_setup/ipad13_portrait',
  'account_deletion/ipad11_landscape',
  'onboarding_goal/ipad13_portrait',
};

Future<void> _pump(
  WidgetTester tester, {
  required _Device device,
  required Widget home,
  required List<String> overflows,
  required String label,
  required String? shotDir,
  double keyboard = 0,
  Future<void> Function(WidgetTester tester)? afterPump,
}) async {
  final before = overflows.length;
  final tablet = device.size.shortestSide >= 600;
  final captureOverlay = _overlayLabels.contains(label);
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = tablet
      ? const FakeViewPadding(top: 24, bottom: 20)
      : const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  final boundary = GlobalKey();
  final appBoundary = GlobalKey();
  try {
    // 前の画面のダイアログ経路を残さない。同じ型の Navigator は状態を引き継ぐ。
    await tester.pumpWidget(
      RepaintBoundary(
        key: appBoundary,
        child: MaterialApp(
          key: ValueKey(label),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: buildCalonaviFrame,
          home: RepaintBoundary(key: boundary, child: home),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    if (afterPump != null) {
      await afterPump(tester);
    }
  } catch (error) {
    overflows.add('$label: $error');
    return;
  }
  while (tester.takeException() != null) {}
  final shotBoundary = captureOverlay ? appBoundary : boundary;
  if (shotDir != null) {
    await _writePng(tester, shotBoundary, '$shotDir/$label.png');
  }
  if (_goldenNames.contains(label) &&
      Platform.environment['IPAD_ALLOW_OVERFLOW'] != '1') {
    await expectLater(
      find.byKey(shotBoundary),
      matchesGoldenFile('goldens/ipad_review/$label.png'),
    );
  }
  final fresh = overflows.skip(before).toList();
  if (fresh.isNotEmpty) {
    overflows
      ..removeRange(before, overflows.length)
      ..add('$label: ${fresh.first}');
  }
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required String name,
  required String? shotDir,
  required List<String> overflows,
  required String visible,
  required Future<Object?> Function(BuildContext context) open,
  double keyboard = 0,
}) async {
  await _pump(
    tester,
    device: _ipad13Portrait,
    keyboard: keyboard,
    overflows: overflows,
    label: '$name/ipad13_portrait',
    shotDir: shotDir,
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('開く'),
            ),
          ),
        );
      },
    ),
    afterPump: (tester) async {
      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(visible), findsWidgets);
    },
  );
}

Future<void> _writePng(
  WidgetTester tester,
  GlobalKey boundary,
  String path,
) async {
  final bytes = await tester.runAsync(() async {
    final object =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await object.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
}

SavedFood _publicFood() {
  return SavedFood(
    foodId: 'food-1',
    ownerUserId: 'creator-1',
    name: '親子丼',
    normalizedName: '親子丼',
    baseAmount: 1,
    unitType: FoodUnitType.serving,
    servingUnitLabel: '杯',
    kcalPerBase: 700,
    proteinPerBase: 30,
    fatPerBase: 20,
    carbPerBase: 80,
    visibility: FoodVisibility.public,
    status: FoodStatus.active,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );
}

class _EmptyAnnouncements implements AnnouncementRepository {
  @override
  Future<List<Announcement>> published() async => const [];
}

class _EmptyReads implements AnnouncementReadStore {
  @override
  Future<Set<String>> readIds() async => const {};

  @override
  Future<void> markRead(Iterable<String> ids) async {}
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    zen.addFont(
      Future<ByteData>.value(
        ByteData.sublistView(File(path).readAsBytesSync()),
      ),
    );
  }
  await zen.load();
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = (config['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final entry = packages.firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  var root = Uri.parse(entry['rootUri'] as String);
  if (!root.path.endsWith('/')) {
    root = root.replace(path: '${root.path}/');
  }
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final file = File(
    configUri
        .resolveUri(root)
        .resolve('lib/fonts/MaterialSymbolsRounded.ttf')
        .toFilePath(),
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}
