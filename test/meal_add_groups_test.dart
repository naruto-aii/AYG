import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/official_food_logger.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Analytics.onEmitForTest = null;
  });

  final now = DateTime(2026, 10, 8, 12);

  SavedFood food(
    String name, {
    required String id,
    String ownerUserId = AppController.localOwnerUserId,
    FoodVisibility visibility = FoodVisibility.private,
  }) {
    return SavedFood(
      foodId: id,
      ownerUserId: ownerUserId,
      name: name,
      normalizedName: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      servingUnitLabel: 'g',
      kcalPerBase: 168,
      visibility: visibility,
      createdAt: now,
      updatedAt: now,
    );
  }

  MealTemplate template(String name, {required String id}) {
    return MealTemplate(
      templateId: id,
      ownerUserId: AppController.localOwnerUserId,
      name: name,
      normalizedName: name,
      totalKcal: 300,
      totalProteinG: 10,
      totalFatG: 8,
      totalCarbG: 40,
      createdAt: now,
      updatedAt: now,
    );
  }

  const official = [
    OfficialFoodMatch(foodCode: '01083', name: '白米', kcal: 168),
    OfficialFoodMatch(foodCode: '04023', name: '鶏むね肉', kcal: 108),
  ];

  late List<SavedFood> savedFoods;
  late List<MealTemplate> templates;
  late List<PublicFoodSearchMatch> publicFoods;

  setUp(() {
    savedFoods = [
      food('自家製おにぎり', id: 'saved-1'),
      food('鶏むね肉（皮なし）', id: 'saved-2'),
    ];
    templates = [template('おにぎり定食', id: 'template-1')];
    publicFoods = [
      PublicFoodSearchMatch(
        food: food(
          '公開おにぎり',
          id: 'public-1',
          ownerUserId: 'other-user',
          visibility: FoodVisibility.public,
        ),
        goodCount: 1,
        badCount: 0,
        matchType: PublicFoodSearchMatchType.exactName,
      ),
    ];
  });

  CombinedFoodSearchOverrides overrides() {
    return CombinedFoodSearchOverrides(
      debounce: Duration.zero,
      searchSaved: (_) async => savedFoods,
      searchOfficial: (_) async =>
          const OfficialFoodSearchResult(matches: official),
      searchPublic: (_) async => publicFoods,
    );
  }

  testWidgets('撮る・探す・その他 still opens the same three search headings', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: FoodFormScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'AYG/test (test@example.com)',
          ),
          searchOverrides: overrides(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('撮る'), findsOneWidget);
    expect(find.text('探す'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.text('写真で登録 (β)'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('テンプレート'), findsOneWidget);
    expect(find.byKey(const ValueKey('food_name_field')), findsOneWidget);

    await tester.tap(find.text('食品を探す'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      'おにぎり',
    );
    await tester.pumpAndSettle();

    expect(find.text(CombinedFoodSearch.savedHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.officialHeading), findsOneWidget);
    expect(find.text(CombinedFoodSearch.publicHeading), findsOneWidget);
    expect(find.text('自家製おにぎり'), findsOneWidget);
    expect(find.text('鶏むね肉（皮なし）'), findsOneWidget);
    expect(find.text('白米'), findsOneWidget);
    expect(find.text('鶏むね肉'), findsOneWidget);
    expect(find.text('公開おにぎり'), findsOneWidget);
    expect(find.text('公開食品を選ぶ'), findsNothing);
    expect(find.text('公開食品から追加'), findsNothing);
    expect(find.byType(MealFoodSearchScreen), findsOneWidget);
  });

  test(
    'each save path still writes one food through the same outbox',
    () async {
      Future<void> expectOneFood({
        required String label,
        required Future<void> Function(AppController controller) save,
        required bool Function(FoodEntry entry) matches,
      }) async {
        final events = <Map<String, Object?>>[];
        Analytics.onEmitForTest = (name, props) {
          if (name == 'food_entry_added') {
            events.add(props);
          }
        };
        final pending = PendingRecordStore();
        final controller = AppController(pendingRecords: pending);
        addTearDown(controller.dispose);
        await save(controller);
        expect(controller.foodEntries, hasLength(1), reason: label);
        expect(
          controller.foodEntries.where(matches),
          hasLength(1),
          reason: label,
        );
        final id = controller.foodEntries.single.id;
        expect(await pending.preferLocalIds(PendingRecordKind.food), {
          id,
        }, reason: label);
        expect(await pending.pendingDeleteIds(PendingRecordKind.food), isEmpty);
        expect(events, hasLength(1), reason: label);
        expect(events.single['method'], 'manual', reason: label);
        expect(events.single['food_entry_ids'], [id], reason: label);
      }

      await expectOneFood(
        label: '手入力',
        save: (controller) {
          return controller.saveFoodEntryWithOptionalSavedFood(
            entry: FoodEntry(id: 'manual-1', name: '手入力の丼', loggedAt: now),
            saveAsFood: false,
          );
        },
        matches: (entry) =>
            entry.name == '手入力の丼' && entry.sourceType == FoodEntrySource.manual,
      );
      await expectOneFood(
        label: '保存済み',
        save: (controller) {
          return controller.addMealEntryFromSavedFoodMaster(
            food: savedFoods.first,
            consumedQuantity: 100,
            loggedAt: now,
          );
        },
        matches: (entry) =>
            entry.name == '自家製おにぎり' &&
            entry.sourceType == FoodEntrySource.savedFood &&
            entry.savedFoodId == 'saved-1',
      );
      await expectOneFood(
        label: '公開食品',
        save: (controller) {
          return controller.addMealEntryFromSavedFoodMaster(
            food: publicFoods.single.food,
            consumedQuantity: 100,
            loggedAt: now,
          );
        },
        matches: (entry) =>
            entry.name == '公開おにぎり' &&
            entry.sourceType == FoodEntrySource.savedFood &&
            entry.sourceFoodOwnerUserId == 'other-user',
      );
      await expectOneFood(
        label: '成分表',
        save: (controller) {
          final entry = const OfficialFoodLogger().buildEntry(
            match: official.first,
            entryId: 'official-1',
            grams: 100,
            loggedAt: now,
          );
          return controller.addFood(entry);
        },
        matches: (entry) =>
            entry.officialFoodCode == '01083' &&
            entry.sourceType == FoodEntrySource.mextSfct,
      );
      await expectOneFood(
        label: 'テンプレート',
        save: (controller) {
          return controller.registerFoodMealFromDrafts(
            mealGroupName: templates.first.name,
            loggedAt: now,
            items: const [
              MealTemplateItemDraft(
                name: '白米',
                baseAmount: 150,
                unitType: FoodUnitType.g,
                consumedAmount: 150,
                sortOrder: 1,
              ),
            ],
          );
        },
        matches: (entry) =>
            entry.name == '白米' && entry.mealGroupName == 'おにぎり定食',
      );
    },
  );
}
