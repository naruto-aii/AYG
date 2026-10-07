import 'package:ayg/config/official_foods_flag.dart';
import 'package:ayg/constants/official_food_copy.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/screens/official_food/official_food_detail_screen.dart';
import 'package:ayg/screens/settings/data_source_screen.dart';
import 'package:ayg/screens/settings/settings_reference_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/services/official_food_link.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/official_food/official_food_attribution.dart';
import 'package:ayg/widgets/official_food/official_food_attribution_line.dart';
import 'package:ayg/widgets/saved_food/public_food_detail_sheet.dart';
import 'package:ayg/widgets/official_food/official_food_search_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

class _FixedOfficialFoods implements OfficialFoodRepository {
  _FixedOfficialFoods(this.rows);

  final List<OfficialFoodMatch> rows;
  int calls = 0;

  @override
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30}) async {
    calls++;
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    OfficialFoodsFlag.debugOverride = null;
  });

  test('official food search stays on when the define is absent', () {
    OfficialFoodsFlag.debugOverride = null;
    expect(OfficialFoodsFlag.enabled, isTrue);
  });

  test('MEXT link uses an external browser', () async {
    Uri? opened;
    LaunchMode? mode;
    final ok = await openMextFoodCompositionPage(
      launch: (uri, launchMode) async {
        opened = uri;
        mode = launchMode;
        return true;
      },
    );
    expect(ok, isTrue);
    expect(opened, OfficialFoodCopy.sourcePage);
    expect(mode, LaunchMode.externalApplication);
  });

  testWidgets('attribution expands to the full source line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfficialFoodAttribution())),
    );
    expect(find.text(OfficialFoodCopy.shortAttribution), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('official_food_attribution')));
    await tester.pump();
    expect(find.text(OfficialFoodCopy.fullAttribution), findsOneWidget);
    expect(find.text(OfficialFoodCopy.externalLinkLabel), findsOneWidget);
  });

  testWidgets('flag off hides the official section', (tester) async {
    OfficialFoodsFlag.debugOverride = false;
    final query = TextEditingController(text: 'ご飯');
    addTearDown(query.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficialFoodSearchSection(
            query: query,
            debounce: Duration.zero,
            repository: _FixedOfficialFoods(const [
              OfficialFoodMatch(foodCode: '01088', name: '精白米', kcal: 156),
            ]),
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('定番の食品'), findsNothing);
    expect(find.text('精白米'), findsNothing);
  });

  testWidgets('flag on shows a result and the short attribution', (
    tester,
  ) async {
    OfficialFoodsFlag.debugOverride = true;
    final query = TextEditingController(text: 'ご飯');
    addTearDown(query.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OfficialFoodSearchSection(
            query: query,
            debounce: Duration.zero,
            repository: _FixedOfficialFoods(const [
              OfficialFoodMatch(
                foodCode: '01088',
                name: 'こめ　［水稲めし］　精白米　うるち米',
                displayName: '精白米（うるち米・水稲めし）',
                kcal: 156,
                matchedAlias: 'ご飯',
              ),
            ]),
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('定番の食品'), findsOneWidget);
    expect(find.text('精白米（うるち米・水稲めし）'), findsOneWidget);
    expect(find.text('156 kcal / 100g'), findsOneWidget);
    expect(find.text('こめ　［水稲めし］　精白米　うるち米'), findsNothing);
    expect(
      find.textContaining(OfficialFoodCopy.shortAttribution),
      findsOneWidget,
    );
  });

  testWidgets(
    'akami list starts with the cut and puts class on the kcal line',
    (tester) async {
      OfficialFoodsFlag.debugOverride = true;
      final query = TextEditingController(text: 'あかみ');
      addTearDown(query.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OfficialFoodSearchSection(
              query: query,
              debounce: Duration.zero,
              repository: _FixedOfficialFoods(const [
                OfficialFoodMatch(
                  foodCode: '10253',
                  name: '＜魚類＞　（まぐろ類）　くろまぐろ　天然　赤身　生',
                  displayName: 'くろまぐろ（天然・赤身・生）',
                  kcal: 115,
                ),
              ]),
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('定番の食品'), findsOneWidget);
      expect(find.text('くろまぐろ（天然・赤身・生）'), findsOneWidget);
      expect(find.text('魚・まぐろ · 115 kcal / 100g'), findsOneWidget);
      expect(find.textContaining('＜魚類＞'), findsNothing);
      expect(find.textContaining('まぐろ類'), findsNothing);
    },
  );

  testWidgets('moving the cursor does not search the same word again', (
    tester,
  ) async {
    OfficialFoodsFlag.debugOverride = true;
    final query = TextEditingController(text: 'ご飯');
    addTearDown(query.dispose);
    final repository = _FixedOfficialFoods(const [
      OfficialFoodMatch(foodCode: '01088', name: '精白米', kcal: 156),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficialFoodSearchSection(
            query: query,
            debounce: Duration.zero,
            repository: repository,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.calls, 1);

    query.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repository.calls, 1);
  });

  testWidgets('data source screen shows how the numbers are stored', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const DataSourceScreen()),
    );
    expect(find.text(OfficialFoodCopy.nutritionPer100g), findsOneWidget);
    expect(find.text(OfficialFoodCopy.traceAndEstimate), findsOneWidget);
    expect(find.text(OfficialFoodCopy.scaledToGrams), findsOneWidget);
    expect(find.text(OfficialFoodCopy.nameProcessing), findsOneWidget);
    expect(find.text(OfficialFoodCopy.externalLinkLabel), findsOneWidget);
  });

  testWidgets('settings hides データの出典 until the flag is on', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    addTearDown(authRepository.dispose);
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: authRepository,
    );
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
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
        targetWeightKg: 75,
        targetDate: DateTime(2026, 10, 1),
      ),
    );

    Future<void> pump() {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            controller: controller,
            authenticationRepository: authRepository,
            hideHealthSettings: true,
          ),
        ),
      );
    }

    OfficialFoodsFlag.debugOverride = false;
    await pump();
    expect(find.text('データの出典'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-references')),
      200,
    );
    await tester.tap(find.byKey(const Key('settings-references')));
    await tester.pumpAndSettle();
    expect(find.text('データの出典'), findsNothing);
    expect(find.text('計算根拠'), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsReferenceScreen))).pop();
    await tester.pumpAndSettle();

    OfficialFoodsFlag.debugOverride = true;
    await pump();
    await tester.scrollUntilVisible(find.byKey(const Key('settings-references')), 200);
    await tester.tap(find.byKey(const Key('settings-references')));
    await tester.pumpAndSettle();
    expect(find.text('データの出典'), findsOneWidget);
  });

  testWidgets(
    'attribution uses the short line only when the full line overflows',
    (tester) async {
      Future<void> pump(double width) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: const OfficialFoodAttributionLine(),
                ),
              ),
            ),
          ),
        );
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 全文は1行に収まらない幅では、数値の保存の説明だけを出す。
      await pump(4000);
      expect(find.text(OfficialFoodCopy.fullAttribution), findsOneWidget);
      await pump(1);
      expect(find.text(OfficialFoodCopy.compactAttribution), findsOneWidget);
    },
  );

  testWidgets(
    'attribution stays complete at text scale 2 and a narrow phone width',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(width: 320, child: OfficialFoodAttributionLine()),
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(OfficialFoodAttributionLine),
          matching: find.byType(Text),
        ),
      );
      final shown = paragraph.text.toPlainText();
      expect(
        shown,
        anyOf(
          OfficialFoodCopy.fullAttribution,
          OfficialFoodCopy.compactAttribution,
        ),
      );
      expect(shown.contains('…'), isFalse);
      expect(shown.contains('...'), isFalse);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(shown, OfficialFoodCopy.compactAttribution);
    },
  );

  testWidgets('detail names an alias and always shows the estimate notice', (
    tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OfficialFoodDetailScreen(
          controller: controller,
          match: const OfficialFoodMatch(
            foodCode: '01088',
            name: 'こめ　［水稲めし］　精白米　うるち米',
            displayName: '精白米（うるち米・水稲めし）',
            kcal: 156,
            matchedAlias: 'ご飯',
          ),
        ),
      ),
    );
    expect(
      find.text(
        OfficialFoodCopy.aliasAttribution(
          alias: 'ご飯',
          officialName: 'こめ　［水稲めし］　精白米　うるち米',
          foodCode: '01088',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('精白米（うるち米・水稲めし）'), findsOneWidget);
    expect(find.text('こめ　［水稲めし］　精白米　うるち米'), findsOneWidget);
    expect(find.text(OfficialFoodCopy.explanation), findsOneWidget);
    expect(find.textContaining('1食分の値'), findsNothing);
  });

  testWidgets('public food display keeps the composition-table attribution', (
    tester,
  ) async {
    final food = SavedFood(
      foodId: 'mext-rice',
      ownerUserId: 'user-a',
      name: 'ご飯',
      normalizedName: 'ご飯',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      sourceType: FoodSourceType.mextSfct,
      officialFoodCode: '01088',
      officialFoodName: 'こめ　［水稲めし］　精白米　うるち米',
      sourceAttribution: OfficialFoodCopy.storedAttribution,
      createdAt: DateTime.utc(2026, 9, 28),
      updatedAt: DateTime.utc(2026, 9, 28),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PublicFoodMextNotice(food: food)),
      ),
    );
    expect(find.text(OfficialFoodCopy.explanation), findsOneWidget);
    expect(find.text(OfficialFoodCopy.storedAttribution), findsNothing);
    expect(find.text('成分表の食品名：こめ　［水稲めし］　精白米　うるち米（食品番号 01088）'), findsOneWidget);
  });
}
