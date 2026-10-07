import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/announcement.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/announcement_read_store.dart';
import 'package:ayg/repositories/announcement_repository.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/personal_coach_planner.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    zen.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await zen.load();

  final icons = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  final iconFile = File(_materialSymbolsFontPath());
  icons.addFont(
    Future<ByteData>.value(ByteData.sublistView(iconFile.readAsBytesSync())),
  );
  await icons.load();
}

String _materialSymbolsFontPath() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final pkg = packages.cast<Map<String, dynamic>>().firstWhere(
    (item) => item['name'] == 'material_symbols_icons',
  );
  var root = Uri.parse(pkg['rootUri'] as String);
  if (!root.path.endsWith('/')) {
    root = root.replace(path: '${root.path}/');
  }
  return root.resolve('lib/fonts/MaterialSymbolsRounded.ttf').toFilePath();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('personal coach screens at 390 by 844', (tester) async {
    final preferred = Directory('/opt/cursor/artifacts/screenshots/coach');
    final directory = preferred.parent.existsSync()
        ? preferred
        : Directory.systemTemp.createTempSync('coach-shots');
    directory.createSync(recursive: true);

    final night = _meals(remaining: 800, now: DateTime(2026, 10, 7, 22, 30));
    final light = _meals(remaining: 350, now: DateTime(2026, 10, 7, 12));
    final standard = _meals(remaining: 550, now: DateTime(2026, 10, 7, 12));
    final hearty = _meals(remaining: 900, now: DateTime(2026, 10, 7, 12));
    final low = _meals(remaining: 120, now: DateTime(2026, 10, 7, 18));
    expect(night.first.bandLabel, personalCoachBandLabel(PersonalCoachBand.snack));
    expect(light.first.bandLabel, personalCoachBandLabel(PersonalCoachBand.light));
    expect(
      standard.first.bandLabel,
      personalCoachBandLabel(PersonalCoachBand.standard),
    );
    expect(
      hearty.first.bandLabel,
      personalCoachBandLabel(PersonalCoachBand.hearty),
    );
    expect(low.first.bandLabel, personalCoachBandLabel(PersonalCoachBand.snack));

    final saved = <String, List<int>>{};
    saved['night'] = await _capture(
      tester,
      _coach(night, now: DateTime(2026, 10, 7, 22, 30)),
      File('${directory.path}/night.png'),
    );
    saved['light'] = await _capture(
      tester,
      _coach(light, now: DateTime(2026, 10, 7, 12)),
      File('${directory.path}/light.png'),
    );
    saved['standard'] = await _capture(
      tester,
      _coach(standard, now: DateTime(2026, 10, 7, 12)),
      File('${directory.path}/standard.png'),
    );
    saved['hearty'] = await _capture(
      tester,
      _coach(hearty, now: DateTime(2026, 10, 7, 12)),
      File('${directory.path}/hearty.png'),
    );
    saved['low_remaining'] = await _capture(
      tester,
      _coach(low, now: DateTime(2026, 10, 7, 18)),
      File('${directory.path}/low_remaining.png'),
    );
    saved['free'] = await _capture(
      tester,
      DailyCoachScreen(
        controller: _profiled(plus: false),
        introStore: _SeenIntro(),
      ),
      File('${directory.path}/free.png'),
    );
    saved['home'] = await _capture(
      tester,
      HomeScreen(
        controller: _profiled(plus: true),
        openFoodFactsService: OpenFoodFactsService(userAgent: 'screenshot'),
        announcementRepository: _NoAnnouncements(),
        announcementReadStore: _NoReads(),
      ),
      File('${directory.path}/home.png'),
      checkTitleSize: false,
    );

    final fingerprints = saved.values.map((bytes) => bytes.join(',')).toSet();
    expect(fingerprints, hasLength(saved.length));
    expect(find.textContaining('精度検証中'), findsNothing);
  });
}

List<CoachMealProposal> _meals({
  required double remaining,
  required DateTime now,
}) {
  final meals = planCoachMeals(
    foods: CoachFoodCatalog.stocks,
    excludedFoodCodes: const {},
    remainingKcal: remaining,
    remainingProteinG: 30,
    remainingFatG: 20,
    remainingCarbG: 80,
    now: now,
  );
  expect(meals, isNotEmpty);
  return meals;
}

Widget _coach(List<CoachMealProposal> meals, {required DateTime now}) {
  return DailyCoachScreen(
    introStore: _SeenIntro(),
    now: now,
    load: () async => DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      focus: DailyCoachFocus.meals,
      meals: meals,
    ),
  );
}

Future<List<int>> _capture(
  WidgetTester tester,
  Widget screen,
  File file, {
  bool checkTitleSize = true,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.textContaining('精度検証中'), findsNothing);
  expect(find.textContaining('□'), findsNothing);
  if (checkTitleSize) {
    final title = tester.widget<Text>(find.text('パーソナルコーチ (β)'));
    expect(title.data, 'パーソナルコーチ (β)');
    expect(title.style?.fontSize, AppTypography.headingL.fontSize);
  }
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, 390);
  expect(image.height, 844);
  return bytes;
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _FreePlus extends UnavailableSubscriptionRepository {
  _FreePlus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;
}

AppController _profiled({required bool plus}) {
  final controller = AppController(
    nutritionEngine: NutritionEngine(),
    healthRepository: MockHealthRepository(isAvailable: false),
    subscriptionRepository: _FreePlus(plus),
  );
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
  return controller;
}

class _NoAnnouncements implements AnnouncementRepository {
  @override
  Future<List<Announcement>> published() async => const [];
}

class _NoReads implements AnnouncementReadStore {
  @override
  Future<void> markRead(Iterable<String> ids) async {}

  @override
  Future<Set<String>> readIds() async => const {};
}
