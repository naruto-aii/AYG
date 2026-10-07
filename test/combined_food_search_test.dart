import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_field.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SavedFood saved(String name) {
    final now = DateTime(2026, 10, 6);
    return SavedFood(
      foodId: name,
      ownerUserId: 'user-1',
      name: name,
      normalizedName: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      servingUnitLabel: 'g',
      kcalPerBase: 50,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> pumpSearch(
    WidgetTester tester, {
    required TextEditingController query,
    Future<List<SavedFood>> Function(String query)? searchSaved,
    Future<OfficialFoodSearchResult> Function(String query)? searchOfficial,
    Future<List<PublicFoodSearchMatch>> Function(String query)? searchPublic,
    Duration debounce = Duration.zero,
    bool browseSavedWhenEmpty = false,
  }) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    addTearDown(query.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: query),
                CombinedFoodSearch(
                  controller: controller,
                  query: query,
                  debounce: debounce,
                  searchSaved: searchSaved ?? (_) async => const [],
                  searchOfficial:
                      searchOfficial ??
                      (_) async => const OfficialFoodSearchResult(),
                  searchPublic: searchPublic ?? (_) async => const [],
                  browseSavedWhenEmpty: browseSavedWhenEmpty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('typing lists saved, official, and public foods together', (
    tester,
  ) async {
    final query = TextEditingController();
    await pumpSearch(
      tester,
      query: query,
      searchSaved: (_) async => [saved('自家製おにぎり')],
      searchOfficial: (_) async => const OfficialFoodSearchResult(
        matches: [OfficialFoodMatch(foodCode: '01083', name: '白米', kcal: 168)],
      ),
      searchPublic: (_) async => [
        PublicFoodSearchMatch(
          food: saved('公開おにぎり'),
          goodCount: 1,
          badCount: 0,
          matchType: PublicFoodSearchMatchType.exactName,
        ),
      ],
    );

    expect(find.text(CombinedFoodSearch.hint), findsOneWidget);
    expect(find.text('公開食品を検索'), findsNothing);

    await tester.enterText(find.byType(TextField), 'おにぎり');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.hint), findsNothing);
    expect(find.text(CombinedFoodSearch.savedHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.publicHeading), findsOneWidget);
    expect(find.text('自家製おにぎり'), findsOneWidget);
    expect(find.text('白米'), findsOneWidget);
    expect(find.text('公開おにぎり'), findsOneWidget);
    expect(find.text('分類'), findsNothing);
  });

  testWidgets('an empty result replaces the typing hint', (tester) async {
    final query = TextEditingController();
    await pumpSearch(tester, query: query);

    await tester.enterText(find.byType(TextField), 'ない食品');
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.hint), findsNothing);
    expect(find.text(CombinedFoodSearch.emptyMessage), findsOneWidget);
  });

  testWidgets('a failed official search is shown', (tester) async {
    final query = TextEditingController();
    await pumpSearch(
      tester,
      query: query,
      searchOfficial: (_) async => OfficialFoodSearchResult.failed('down'),
    );

    await tester.enterText(find.byType(TextField), '白米');
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.officialError), findsOneWidget);
    expect(find.text(CombinedFoodSearch.hint), findsNothing);
    expect(find.text(CombinedFoodSearch.emptyMessage), findsNothing);
  });

  testWidgets('the meal search tab opens the combined search', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FoodFormScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'AYG/test (test@example.com)',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('食品を探す'));
    await tester.pumpAndSettle();

    expect(find.text('食品を探す'), findsOneWidget);
    expect(find.text('公開食品を選ぶ'), findsNothing);
    expect(find.text('公開食品から追加'), findsNothing);
    expect(find.text(CombinedFoodSearch.savedBrowseEmpty), findsOneWidget);
    expect(find.text(CombinedFoodSearch.hint), findsNothing);
    expect(find.byType(DesignSearchField), findsOneWidget);
    expect(find.text('公開食品を検索'), findsNothing);
  });

  testWidgets('an empty query lists saved foods newest first', (tester) async {
    final query = TextEditingController();
    final older = saved('古いおにぎり').copyWith(
      updatedAt: DateTime(2026, 9, 1),
    );
    final newer = saved('新しいおにぎり').copyWith(
      updatedAt: DateTime(2026, 10, 6),
    );
    await pumpSearch(
      tester,
      query: query,
      browseSavedWhenEmpty: true,
      searchSaved: (_) async => [older, newer],
    );
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.hint), findsNothing);
    expect(find.text(CombinedFoodSearch.savedHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialHeading), findsNothing);
    expect(find.text('新しいおにぎり'), findsOneWidget);
    expect(find.text('古いおにぎり'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('新しいおにぎり')).dy,
      lessThan(tester.getTopLeft(find.text('古いおにぎり')).dy),
    );
  });
}
