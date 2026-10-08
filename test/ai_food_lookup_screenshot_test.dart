import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/screens/food/ai_food_lookup_screen.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/services/ai_food_lookup.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/food/ai_food_lookup_row.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadZenMaru() async {
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
  await _loadSymbols();
}

Future<void> _loadSymbols() async {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final resolved = configUri.resolveUri(root);
  final file = File(
    '${resolved.toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final loader = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  loader.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadZenMaru);

  testWidgets('search row, AI candidates, and confirm', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);
    final now = DateTime(2026, 10, 8, 12);
    final controller = AppController();
    addTearDown(controller.dispose);

    SavedFood food(String name, {required String id}) {
      return SavedFood(
        foodId: id,
        ownerUserId: 'other',
        name: name,
        normalizedName: name,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        servingUnitLabel: 'g',
        kcalPerBase: 168,
        createdAt: now,
        updatedAt: now,
      );
    }

    AiFoodCandidate item({
      required String name,
      required String amount,
      required double kcal,
      required double protein,
      required double fat,
      required double carb,
      required bool known,
    }) {
      return AiFoodCandidate(
        name: name,
        amount: amount,
        kcal: kcal,
        proteinG: protein,
        fatG: fat,
        carbG: carb,
        knownProduct: known,
      );
    }

    final gyudon = item(
      name: '牛丼（大盛）',
      amount: '1杯',
      kcal: 872.0,
      protein: 32.0,
      fat: 28.0,
      carb: 112.0,
      known: true,
    );
    final chikuzen = item(
      name: '筑前煮',
      amount: '1人前',
      kcal: 290.0,
      protein: 20.0,
      fat: 10.0,
      carb: 30.0,
      known: false,
    );

    await _capture(
      tester,
      MealFoodSearchScreen(
        controller: controller,
        loggedAt: now,
        aiLookup: AiFoodLookupClient(invoke: (_) async => null),
        searchOverrides: CombinedFoodSearchOverrides(
          debounce: Duration.zero,
          searchSaved: (_) async => [food('自家製牛丼', id: 'saved-1')],
          searchOfficial: (_) async => const OfficialFoodSearchResult(
            matches: [
              OfficialFoodMatch(foodCode: '01083', name: '白米', kcal: 168),
            ],
          ),
          searchPublic: (_) async => [
            PublicFoodSearchMatch(
              food: food('公開牛丼', id: 'public-1'),
              goodCount: 2,
              badCount: 0,
              matchType: PublicFoodSearchMatchType.exactName,
            ),
          ],
        ),
      ),
      File('${directory.path}/ai_food_lookup_search.png'),
      find.text('食品を探す'),
      prepare: (tester) async {
        await tester.enterText(
          find.byKey(const Key('meal-food-search-field')),
          '吉野家 牛丼 大盛',
        );
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byType(MealFoodSearchScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        for (
          var i = 0;
          i < 8 &&
              find.text(AiFoodLookupRow.label).hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(scrollable, const Offset(0, -280));
          await tester.pumpAndSettle();
        }
      },
    );
    expect(find.text(AiFoodLookupRow.label), findsOneWidget);
    expect(find.text('自家製牛丼'), findsOneWidget);
    expect(find.text('公開食品を選ぶ'), findsNothing);
    expect(find.textContaining('公式'), findsNothing);

    await _capture(
      tester,
      AiFoodLookupScreen(
        controller: controller,
        query: '吉野家 牛丼 大盛',
        loggedAt: now,
        client: AiFoodLookupClient(
          invoke: (_) async => {
            'ok': true,
            'usage_id': 'usage-1',
            'cache_hit': false,
            'candidates': [
              {
                'name': gyudon.name,
                'amount': gyudon.amount,
                'kcal': gyudon.kcal,
                'protein_g': gyudon.proteinG,
                'fat_g': gyudon.fatG,
                'carb_g': gyudon.carbG,
                'known_product': gyudon.knownProduct,
              },
              {
                'name': chikuzen.name,
                'amount': chikuzen.amount,
                'kcal': chikuzen.kcal,
                'protein_g': chikuzen.proteinG,
                'fat_g': chikuzen.fatG,
                'carb_g': chikuzen.carbG,
                'known_product': chikuzen.knownProduct,
              },
            ],
          },
        ),
      ),
      File('${directory.path}/ai_food_lookup_results.png'),
      find.text('牛丼（大盛）'),
    );
    expect(find.text(aiFoodLookupEstimateTitle), findsOneWidget);
    expect(find.text(aiFoodLookupKnownProductNote), findsOneWidget);
    expect(find.textContaining('公式'), findsNothing);

    await _capture(
      tester,
      PhotoMealConfirmScreen(
        controller: controller,
        loggedAt: now,
        hadUserDishName: true,
        title: aiFoodLookupEstimateTitle,
        subtitle: aiFoodLookupEstimateSubtitle,
        analysis: PhotoMealAnalysis(
          usageId: 'usage-1',
          estimate: gyudon.toEstimate(),
        ),
      ),
      File('${directory.path}/ai_food_lookup_confirm.png'),
      find.text(aiFoodLookupEstimateTitle),
    );
    expect(find.text(aiFoodLookupEstimateSubtitle), findsOneWidget);
    expect(find.text('872'), findsOneWidget);
    expect(find.textContaining('公式'), findsNothing);

    await _capture(
      tester,
      MealFoodSearchScreen(
        controller: controller,
        loggedAt: now,
        aiLookup: AiFoodLookupClient(invoke: (_) async => null),
        searchOverrides: const CombinedFoodSearchOverrides(
          debounce: Duration.zero,
          searchSaved: _emptySaved,
          searchOfficial: _emptyOfficial,
          searchPublic: _emptyPublic,
        ),
      ),
      File('${directory.path}/ai_food_lookup_empty.png'),
      find.byKey(const Key('ai-food-lookup-empty')),
      prepare: (tester) async {
        await tester.enterText(
          find.byKey(const Key('meal-food-search-field')),
          '筑前煮',
        );
        await tester.pumpAndSettle();
      },
    );
    expect(find.text(AiFoodLookupEmptySuggestion.headline), findsOneWidget);
    expect(find.byKey(const Key('ai-food-lookup-row')), findsNothing);
    expect(find.text('該当する食品が見つかりませんでした'), findsOneWidget);
  });
}

Future<List<SavedFood>> _emptySaved(String _) async => const [];

Future<OfficialFoodSearchResult> _emptyOfficial(String _) async {
  return const OfficialFoodSearchResult(matches: []);
}

Future<List<PublicFoodSearchMatch>> _emptyPublic(String _) async => const [];

Future<void> _capture(
  WidgetTester tester,
  Widget screen,
  File file,
  Finder visible, {
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  if (prepare != null) {
    await prepare(tester);
  }
  expect(visible, findsWidgets);
  await _write(tester, file, key: key);
}

Future<void> _write(
  WidgetTester tester,
  File file, {
  required GlobalKey key,
}) async {
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
  expect(image!.width, greaterThan(0));
}
