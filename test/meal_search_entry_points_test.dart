import 'dart:convert';
import 'dart:io';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/saved_food_repository_base.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/screens/food/food_form_navigation.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/food_tab_screen.dart';
import 'package:ayg/screens/history/day_history_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/saved_food/saved_food_list_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_colors.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/theme/app_typography.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('ZenMaruGothic');
    for (final path in const [
      'assets/fonts/ZenMaruGothic-Regular.ttf',
      'assets/fonts/ZenMaruGothic-Medium.ttf',
      'assets/fonts/ZenMaruGothic-Bold.ttf',
    ]) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    await _loadMaterialSymbols();
  });

  final now = DateTime(2026, 10, 7);

  SavedFood saved(String name, {int useCount = 0, DateTime? updatedAt}) {
    return SavedFood(
      foodId: name,
      ownerUserId: 'user-1',
      name: name,
      normalizedName: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      servingUnitLabel: 'g',
      kcalPerBase: 50,
      useCount: useCount,
      createdAt: updatedAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  CombinedFoodSearchOverrides overridesFor({
    Future<List<SavedFood>> Function(String query)? searchSaved,
    Future<OfficialFoodSearchResult> Function(String query)? searchOfficial,
    Future<List<PublicFoodSearchMatch>> Function(String query)? searchPublic,
  }) {
    return CombinedFoodSearchOverrides(
      debounce: Duration.zero,
      searchSaved: searchSaved ?? (_) async => [saved('自家製おにぎり')],
      searchOfficial:
          searchOfficial ??
          (_) async => const OfficialFoodSearchResult(
            matches: [
              OfficialFoodMatch(foodCode: '01083', name: '白米', kcal: 168),
            ],
          ),
      searchPublic:
          searchPublic ??
          (_) async => [
            PublicFoodSearchMatch(
              food: saved('公開おにぎり'),
              goodCount: 1,
              badCount: 0,
              matchType: PublicFoodSearchMatchType.exactName,
            ),
          ],
    );
  }

  void expectThreeHeadings() {
    expect(find.text(CombinedFoodSearch.savedHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.publicHeading), findsOneWidget);
    expect(find.text('自家製おにぎり'), findsOneWidget);
    expect(find.text('白米'), findsOneWidget);
    expect(find.text('公開おにぎり'), findsOneWidget);
  }

  void expectNoLegacyPublicScreen() {
    expect(find.text('公開食品を選ぶ'), findsNothing);
    expect(find.text('公開食品から追加'), findsNothing);
  }

  Future<GlobalKey> pumpPhone(WidgetTester tester, Widget home) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _screenshotTheme(),
          home: home,
        ),
      ),
    );
    await tester.pump();
    return key;
  }

  Future<void> saveShot(WidgetTester tester, GlobalKey key, String name) async {
    final directory = Platform.environment['MEAL_SEARCH_SHOTS'];
    if (directory == null || directory.isEmpty) {
      return;
    }
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 1),
    );
    expect(bytes, isNotNull);
    final folder = Directory(directory);
    folder.createSync(recursive: true);
    File('${folder.path}/$name.png').writeAsBytesSync(bytes!);
  }

  Future<void> openCombinedSearch(WidgetTester tester) async {
    final searchTab = find.text('食品を探す');
    await tester.ensureVisible(searchTab);
    await tester.tap(searchTab);
    await tester.pumpAndSettle();
    expectNoLegacyPublicScreen();
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      'おにぎり',
    );
    await tester.pumpAndSettle();
  }

  FoodFormScreenBuilder formBuilder(CombinedFoodSearchOverrides overrides) {
    return ({
      required AppController controller,
      required OpenFoodFactsService openFoodFactsService,
      FoodEntry? entry,
      DateTime? initialLoggedAt,
      bool guideFirstMeal = false,
      String? initialQuery,
    }) {
      return FoodFormScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        entry: entry,
        initialLoggedAt: initialLoggedAt,
        guideFirstMeal: guideFirstMeal,
        initialQuery: initialQuery,
        searchOverrides: overrides,
      );
    };
  }

  OpenFoodFactsService foods() {
    return OpenFoodFactsService(userAgent: 'AYG/test (test@example.com)');
  }

  AppController controller({SavedFoodRepositoryBase? savedFoods}) {
    final created = AppController(savedFoodRepository: savedFoods);
    addTearDown(created.dispose);
    return created;
  }

  AppController homeController() {
    final created = controller();
    created.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 65,
      ),
    );
    created.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    created.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 65,
        targetDate: DateTime(2026, 12, 31),
      ),
    );
    return created;
  }

  testWidgets('meal tab 食品を探す shows saved, staple, and public headings', (
    tester,
  ) async {
    final overrides = overridesFor();
    final app = controller();
    final shot = await pumpPhone(
      tester,
      FoodTabScreen(
        controller: app,
        openFoodFactsService: foods(),
        foodFormBuilder: formBuilder(overrides),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('食事を追加'));
    await tester.pumpAndSettle();
    expect(find.text('撮る'), findsOneWidget);
    expect(find.text('探す'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.text('写真で登録 (β)'), findsOneWidget);
    expect(find.text('食品を探す'), findsOneWidget);
    expect(find.text('保存済み'), findsNothing);
    expect(find.text('保存済み食品から選ぶ'), findsNothing);
    expect(find.text('食べたものを記録して、健康な毎日をつくりましょう'), findsNothing);
    expect(find.text('次回以降、保存済み食品から再利用できます'), findsNothing);
    expect(find.text('次回から「食品を探す」で選べます'), findsOneWidget);
    expect(find.text('入力内容をテンプレートとして保存'), findsNothing);
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('テンプレート'), findsOneWidget);
    expect(find.text('保存済み、定番の食品、公開食品をまとめて探します。'), findsOneWidget);
    expect(find.text('バーコードから追加'), findsNothing);
    expect(find.text('カメラで読み取る'), findsNothing);
    expectNoLegacyPublicScreen();
    await saveShot(tester, shot, 'meal-add-top');

    await tester.ensureVisible(find.text('食品として保存'));
    await tester.pumpAndSettle();
    expect(find.text('入力内容をテンプレートとして保存'), findsNothing);
    expect(find.text('食品として保存'), findsOneWidget);
    expect(find.text('バーコードから追加'), findsNothing);
    await saveShot(tester, shot, 'meal-form-bottom');

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.ensureVisible(find.text('バーコード'));
      await tester.tap(find.text('バーコード'));
      await tester.pumpAndSettle();
      expect(find.text('バーコードから追加'), findsOneWidget);
      expect(find.text('カメラで読み取る'), findsOneWidget);
      expect(find.text('または バーコードの番号を入力'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    await tester.tap(find.text('手入力'));
    await tester.pumpAndSettle();
    expect(find.text('バーコードから追加'), findsNothing);

    await openCombinedSearch(tester);
    expectThreeHeadings();
    expectNoLegacyPublicScreen();
    await saveShot(tester, shot, 'combined-search-three-headings');
  });

  testWidgets('home 食事追加 opens the same combined search', (tester) async {
    final overrides = overridesFor();
    final shot = await pumpPhone(
      tester,
      HomeScreen(
        controller: homeController(),
        openFoodFactsService: foods(),
        foodFormBuilder: formBuilder(overrides),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.text('食事追加');
    await tester.scrollUntilVisible(add, 200);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('食品を探す'), findsOneWidget);
    expectNoLegacyPublicScreen();

    await openCombinedSearch(tester);
    expectThreeHeadings();
    expectNoLegacyPublicScreen();
    expect(shot.currentContext, isNotNull);
  });

  testWidgets('day history 追加 opens the same combined search', (tester) async {
    final overrides = overridesFor();
    await pumpPhone(
      tester,
      DayHistoryScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        selectedDay: DateTime.now(),
        foodFormBuilder: formBuilder(overrides),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.text('追加').first;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('食品を探す'), findsOneWidget);
    expectNoLegacyPublicScreen();

    await openCombinedSearch(tester);
    expectThreeHeadings();
    expectNoLegacyPublicScreen();
  });

  testWidgets('typing in the food name field lists the three headings', (
    tester,
  ) async {
    final shot = await pumpPhone(
      tester,
      FoodFormScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        searchOverrides: overridesFor(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.officialHeading), findsNothing);
    expect(find.text(CombinedFoodSearch.publicHeading), findsNothing);
    expect(find.text('自家製おにぎり'), findsNothing);
    expectNoLegacyPublicScreen();

    await tester.enterText(
      find.byKey(const ValueKey('food_name_field')),
      'おにぎり',
    );
    await tester.pumpAndSettle();

    expectThreeHeadings();
    expectNoLegacyPublicScreen();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('food_name_field'))),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    await saveShot(tester, shot, 'name-field-search-results');
  });

  testWidgets('an empty name-field search says nothing matched', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      FoodFormScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        searchOverrides: overridesFor(
          searchSaved: (_) async => const [],
          searchOfficial: (_) async => const OfficialFoodSearchResult(),
          searchPublic: (_) async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('food_name_field')),
      'ない食品',
    );
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.emptyMessage), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialHeading), findsNothing);
    expect(find.text(CombinedFoodSearch.publicHeading), findsNothing);
    expectNoLegacyPublicScreen();
  });

  testWidgets('a failed name-field search shows each failure', (tester) async {
    await pumpPhone(
      tester,
      FoodFormScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        searchOverrides: overridesFor(
          searchSaved: (_) async => throw Exception('saved'),
          searchOfficial: (_) async => OfficialFoodSearchResult.failed('down'),
          searchPublic: (_) async => throw Exception('public'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('food_name_field')), '白米');
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.savedError), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialError), findsOneWidget);
    expect(find.text(CombinedFoodSearch.publicError), findsOneWidget);
    expect(find.text(CombinedFoodSearch.emptyMessage), findsNothing);
    expectNoLegacyPublicScreen();
  });

  testWidgets('Siri search text in the name field lists the three headings', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      FoodFormScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        initialQuery: 'おにぎり',
        searchOverrides: overridesFor(),
      ),
    );
    await tester.pumpAndSettle();

    expectThreeHeadings();
    expectNoLegacyPublicScreen();
  });

  testWidgets('the first-meal guide still opens combined search', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      FoodFormScreen(
        controller: controller(),
        openFoodFactsService: foods(),
        guideFirstMeal: true,
        searchOverrides: overridesFor(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsOneWidget);
    expectNoLegacyPublicScreen();

    await openCombinedSearch(tester);
    expectThreeHeadings();
    expectNoLegacyPublicScreen();
  });

  testWidgets('saved food magnifier opens the combined search', (tester) async {
    final listed = [
      saved('自家製おにぎり', useCount: 2),
      saved('のりおにぎり', useCount: 1),
    ];
    final shot = await pumpPhone(
      tester,
      SavedFoodListScreen(
        controller: controller(savedFoods: _ListedSavedFoods(listed)),
        searchOverrides: overridesFor(searchSaved: (_) async => listed),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('食品を探す'), findsOneWidget);
    expect(find.byTooltip('公開食品検索'), findsNothing);
    expectNoLegacyPublicScreen();
    expect(find.text('保存済み食品'), findsOneWidget);
    expect(find.text('保存食品'), findsNothing);
    expect(find.text('マイ食品がありません'), findsNothing);
    expect(find.text('自家製おにぎり'), findsOneWidget);
    expect(find.text('のりおにぎり'), findsOneWidget);
    await saveShot(tester, shot, 'saved-food-list-with-magnifier');

    await tester.tap(find.byTooltip('食品を探す'));
    await tester.pumpAndSettle();
    expect(find.text('食品を探す'), findsOneWidget);
    expectNoLegacyPublicScreen();

    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      'おにぎり',
    );
    await tester.pumpAndSettle();
    expectThreeHeadings();
    expect(find.text('のりおにぎり'), findsOneWidget);
    expectNoLegacyPublicScreen();
    await saveShot(tester, shot, 'saved-food-magnifier-search');
  });

  testWidgets('empty food search lists saved foods newest first', (
    tester,
  ) async {
    final newer = saved('のりおにぎり', updatedAt: DateTime(2026, 10, 6));
    final older = saved('自家製おにぎり', updatedAt: DateTime(2026, 9, 1));
    SavedFood? picked;
    final shot = await pumpPhone(
      tester,
      Builder(
        builder: (context) {
          return TextButton(
            onPressed: () async {
              picked = await Navigator.of(context).push<SavedFood>(
                MaterialPageRoute<SavedFood>(
                  builder: (context) => MealFoodSearchScreen(
                    controller: controller(),
                    searchOverrides: overridesFor(
                      searchSaved: (_) async => [older, newer],
                    ),
                  ),
                ),
              );
            },
            child: const Text('開く'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.text('保存済み・定番の食品・公開食品から探せます。'), findsOneWidget);
    expect(find.text(CombinedFoodSearch.savedBrowseEmpty), findsNothing);
    expect(find.text(CombinedFoodSearch.officialHeading), findsNothing);
    expect(find.text(CombinedFoodSearch.publicHeading), findsNothing);
    expect(find.text('のりおにぎり'), findsOneWidget);
    expect(find.text('自家製おにぎり'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('のりおにぎり')).dy,
      lessThan(tester.getTopLeft(find.text('自家製おにぎり')).dy),
    );
    await saveShot(tester, shot, 'food-search-empty-saved');

    await tester.tap(find.text('のりおにぎり'));
    await tester.pumpAndSettle();
    expect(picked?.name, 'のりおにぎり');
  });
}

/// 保存トグルはフォント名を持たない。テストの既定フォントは Ahem なので、
/// そのまま撮ると日本語が四角になる。画面の他の文字と同じ Zen Maru Gothic を当てる。
ThemeData _screenshotTheme() {
  final theme = AppTheme.light;
  return theme.copyWith(
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: AppTypography.titleM.copyWith(
        fontFamily: AppTypography.fontFamily,
      ),
      subtitleTextStyle: AppTypography.bodyS.copyWith(
        color: AppColors.textMuted,
        fontFamily: AppTypography.fontFamily,
      ),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.chipTheme.labelStyle?.copyWith(
        fontFamily: AppTypography.fontFamily,
      ),
      secondaryLabelStyle: theme.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: AppTypography.fontFamily,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: theme.segmentedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          AppTypography.titleS.copyWith(fontFamily: AppTypography.fontFamily),
        ),
      ),
    ),
  );
}

/// 戻る矢印などは Material Symbols。パッケージのフォントを名前で読み込む。
class _ListedSavedFoods implements SavedFoodRepositoryBase {
  _ListedSavedFoods(this.foods);

  final List<SavedFood> foods;

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    return foods;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadMaterialSymbols() async {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    return;
  }
  final decoded = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>;
  for (final package in packages) {
    final map = package as Map<String, dynamic>;
    if (map['name'] != 'material_symbols_icons') {
      continue;
    }
    final rootUri = map['rootUri'] as String;
    final root = rootUri.contains(':')
        ? Uri.parse(rootUri).toFilePath()
        : Directory('.dart_tool').uri.resolve(rootUri).toFilePath();
    final file = File('$root/lib/fonts/MaterialSymbolsRounded.ttf');
    if (!file.existsSync()) {
      return;
    }
    final loader = FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    );
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
    await loader.load();
  }
}
