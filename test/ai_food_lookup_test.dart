import 'dart:io';

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/food/ai_food_lookup_screen.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/services/ai_food_lookup.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/food/ai_food_lookup_row.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Analytics.onEmitForTest = null;
  });

  final now = DateTime(2026, 10, 8, 12);

  SavedFood food(String name, {required String id, String owner = 'other'}) {
    return SavedFood(
      foodId: id,
      ownerUserId: owner,
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

  Map<String, Object?> candidate({
    required String name,
    required int kcal,
    required bool known,
  }) {
    return {
      'name': name,
      'amount': '1人前',
      'kcal': kcal,
      'protein_g': 20,
      'fat_g': 10,
      'carb_g': 30,
      'known_product': known,
    };
  }

  CombinedFoodSearchOverrides overrides({
    List<SavedFood>? saved,
    List<OfficialFoodMatch>? official,
    List<PublicFoodSearchMatch>? public,
  }) {
    return CombinedFoodSearchOverrides(
      debounce: Duration.zero,
      searchSaved: (_) async => saved ?? [food('自家製おにぎり', id: 'saved-1')],
      searchOfficial: (_) async => OfficialFoodSearchResult(
        matches:
            official ??
            const [OfficialFoodMatch(foodCode: '01083', name: '白米', kcal: 168)],
      ),
      searchPublic: (_) async =>
          public ??
          [
            PublicFoodSearchMatch(
              food: food('公開おにぎり', id: 'public-1'),
              goodCount: 1,
              badCount: 0,
              matchType: PublicFoodSearchMatchType.exactName,
            ),
          ],
    );
  }

  test('candidates keep sane numbers and drop the rest', () {
    final parsed = parseAiFoodCandidates([
      candidate(name: '牛丼', kcal: 290, known: true),
      {
        'name': '壊れた丼',
        'amount': '1杯',
        'kcal': -1,
        'protein_g': 1,
        'fat_g': 1,
        'carb_g': 1,
        'known_product': false,
      },
      candidate(name: '筑前煮', kcal: 290, known: false),
    ]);
    expect(parsed, isNotNull);
    expect(parsed!.map((item) => item.name), ['牛丼', '筑前煮']);
    expect(parsed.first.knownProduct, isTrue);
    expect(parsed.first.collectionId, isNull);
  });

  test('a collection id is kept and is not a food record', () {
    final parsed = parseAiFoodCandidates([
      {
        ...candidate(name: '牛丼', kcal: 290, known: true),
        'collection_id': 'col-1',
      },
    ]);
    expect(parsed!.single.collectionId, 'col-1');
  });

  test('a different dish is dropped for the query', () {
    expect(aiFoodCandidateMatchesQuery('吉野家 牛丼 大盛', '牛丼（大盛）'), isTrue);
    expect(aiFoodCandidateMatchesQuery('吉野家 牛丼 大盛', '牛丼（並盛）'), isTrue);
    expect(aiFoodCandidateMatchesQuery('吉野家 牛丼 大盛', '筑前煮'), isFalse);
    final parsed = parseAiFoodCandidates(
      [
        candidate(name: '牛丼（大盛）', kcal: 290, known: true),
        candidate(name: '筑前煮', kcal: 290, known: false),
      ],
      query: '吉野家 牛丼 大盛',
    );
    expect(parsed!.map((item) => item.name), ['牛丼（大盛）']);
  });

  test('lookup sends only the clipped query', () async {
    final sent = <Map<String, Object?>>[];
    final client = AiFoodLookupClient(
      invoke: (body) async {
        sent.add(body);
        final query = body['query'] as String;
        return {
          'ok': true,
          'usage_id': 'usage-1',
          'cache_hit': false,
          'candidates': [
            candidate(
              name: query.contains('牛丼') ? '牛丼' : query,
              kcal: 290,
              known: true,
            ),
          ],
        };
      },
    );
    final result = await client.lookup('  吉野家 牛丼  ');
    expect(sent, [
      {'query': '吉野家 牛丼'},
    ]);
    expect(result.candidates.single.name, '牛丼');
    expect(result.usageId, 'usage-1');
    await client.lookup('あ' * 90);
    expect((sent.last['query'] as String).length, aiFoodLookupQueryMaxLength);
  });

  test('migration logs usage without the query and is not a food catalog', () {
    final sql = File(
      'supabase/migrations/20261008160000_ai_food_lookup.sql',
    ).readAsStringSync();
    expect(sql, contains('enable row level security'));
    expect(sql, contains("'ai_food_lookup'"));
    expect(sql, contains('only saved and user_edited can change'));
    expect(sql, contains('cache_hit boolean not null'));
    expect(sql, isNot(contains('query text')));
    expect(sql, contains('食品データベースではなく'));
    expect(sql, isNot(contains('insert into public.saved_foods')));
    final cache = sql.indexOf(
      'create table if not exists public.ai_food_estimate_cache',
    );
    final usage = sql.indexOf(
      'create table if not exists public.meal_text_lookups',
    );
    expect(usage, greaterThanOrEqualTo(0));
    expect(sql.substring(usage, cache), contains('user_id uuid not null'));
    expect(sql.substring(cache), isNot(contains('user_id')));
  });

  testWidgets(
    'typing does not call AI, and the public-only screen stays gone',
    (tester) async {
      final taps = <String>[];
      final query = TextEditingController();
      addTearDown(query.dispose);
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: query),
                  CombinedFoodSearch(
                    controller: controller,
                    query: query,
                    debounce: Duration.zero,
                    searchSaved: overrides().searchSaved,
                    searchOfficial: overrides().searchOfficial,
                    searchPublic: overrides().searchPublic,
                    onAiFoodLookup: taps.add,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(AiFoodLookupRow.label), findsNothing);

      await tester.enterText(find.byType(TextField), 'おにぎり');
      await tester.pumpAndSettle();
      expect(find.text(CombinedFoodSearch.savedHeading), findsOneWidget);
      expect(find.text(CombinedFoodSearch.officialHeading), findsOneWidget);
      expect(find.text(CombinedFoodSearch.publicHeading), findsOneWidget);
      expect(find.text('自家製おにぎり'), findsOneWidget);
      expect(find.text('白米'), findsOneWidget);
      expect(find.text('公開おにぎり'), findsOneWidget);
      expect(find.text('公開食品を選ぶ'), findsNothing);
      expect(find.text('公開食品から追加'), findsNothing);
      expect(find.text(AiFoodLookupRow.label), findsOneWidget);
      expect(taps, isEmpty);

      await tester.tap(find.text(AiFoodLookupRow.label));
      await tester.pump();
      expect(taps, ['おにぎり']);
    },
  );

  testWidgets('an empty catalog offers AI as a prominent suggestion', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFoodSearchScreen(
          controller: controller,
          searchOverrides: overrides(
            saved: const [],
            official: const [],
            public: const [],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      '筑前煮',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-food-lookup-empty')));
    expect(find.text(AiFoodLookupEmptySuggestion.message), findsOneWidget);
    expect(find.text('該当する食品が見つかりませんでした'), findsNothing);
    expect(find.text('データベースには見当たりません'), findsNothing);
    expect(find.byKey(const Key('ai-food-lookup-empty')), findsOneWidget);
    expect(find.byKey(const Key('ai-food-lookup-row')), findsNothing);
    expect(find.text(AiFoodLookupRow.label), findsOneWidget);
    expect(find.text('公開食品を選ぶ'), findsNothing);
  });

  testWidgets('zero results still save one food through the confirm screen', (
    tester,
  ) async {
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'food_entry_added') {
        events.add(props);
      }
    };
    final pending = PendingRecordStore();
    final controller = AppController(
      subscriptionRepository: _ActivePlus(),
      pendingRecords: pending,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFoodSearchScreen(
          controller: controller,
          loggedAt: now,
          aiLookup: AiFoodLookupClient(
            invoke: (body) async {
              expect(body, {'query': '筑前煮'});
              return {
                'ok': true,
                'usage_id': 'usage-empty',
                'cache_hit': false,
                'candidates': [candidate(name: '筑前煮', kcal: 272, known: false)],
              };
            },
          ),
          searchOverrides: overrides(
            saved: const [],
            official: const [],
            public: const [],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      '筑前煮',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-food-lookup-empty')));
    await tester.tap(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    expect(find.text(aiFoodLookupEstimateTitle), findsWidgets);
    expect(controller.foodEntries, isEmpty);
    await tester.tap(find.text('筑前煮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();
    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.name, '筑前煮');
    expect(await pending.preferLocalIds(PendingRecordKind.food), {
      controller.foodEntries.single.id,
    });
    expect(events, hasLength(1));
    expect(events.single['method'], 'manual');
  });

  testWidgets('without Plus the row does not call the model', (tester) async {
    var calls = 0;
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFoodSearchScreen(
          controller: controller,
          aiLookup: AiFoodLookupClient(
            invoke: (_) async {
              calls += 1;
              return null;
            },
          ),
          searchOverrides: overrides(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      '牛丼',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('Plus tap saves exactly one food through the confirm screen', (
    tester,
  ) async {
    final sent = <Map<String, Object?>>[];
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'food_entry_added') {
        events.add(props);
      }
    };
    final pending = PendingRecordStore();
    final controller = AppController(
      subscriptionRepository: _ActivePlus(),
      pendingRecords: pending,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFoodSearchScreen(
          controller: controller,
          loggedAt: now,
          aiLookup: AiFoodLookupClient(
            invoke: (body) async {
              sent.add(body);
              return {
                'ok': true,
                'usage_id': 'usage-1',
                'cache_hit': true,
                'candidates': [
                  candidate(name: '牛丼（大盛）', kcal: 290, known: true),
                  candidate(name: '牛丼（並盛）', kcal: 290, known: true),
                  candidate(name: '筑前煮', kcal: 290, known: false),
                ],
              };
            },
          ),
          searchOverrides: overrides(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('meal-food-search-field')),
      '吉野家 牛丼',
    );
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.text('白米'), findsOneWidget);
    await tester.ensureVisible(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    expect(sent, [
      {'query': '吉野家 牛丼'},
    ]);
    expect(find.text(aiFoodLookupEstimateTitle), findsWidgets);
    expect(find.text('牛丼（大盛）'), findsOneWidget);
    expect(find.text('牛丼（並盛）'), findsOneWidget);
    expect(find.text('筑前煮'), findsNothing);
    expect(find.textContaining('公式'), findsNothing);
    expect(controller.foodEntries, isEmpty);

    await tester.tap(find.text('牛丼（大盛）'));
    await tester.pumpAndSettle();
    expect(find.text(aiFoodLookupEstimateTitle), findsWidgets);
    expect(find.text(aiFoodLookupEstimateSubtitle), findsOneWidget);
    expect(find.textContaining('公式'), findsNothing);
    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();

    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.name, '牛丼（大盛）');
    expect(await pending.preferLocalIds(PendingRecordKind.food), {
      controller.foodEntries.single.id,
    });
    expect(events, hasLength(1));
    expect(events.single['method'], 'manual');
  });

  testWidgets('confirm from an AI candidate writes one record', (tester) async {
    final pending = PendingRecordStore();
    final controller = AppController(pendingRecords: pending);
    addTearDown(controller.dispose);
    final outcomes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoMealConfirmScreen(
          controller: controller,
          loggedAt: now,
          hadUserDishName: true,
          title: aiFoodLookupEstimateTitle,
          subtitle: aiFoodLookupEstimateSubtitle,
          analysis: PhotoMealAnalysis(
            usageId: 'usage-1',
            estimate: const AiFoodCandidate(
              name: '筑前煮',
              amount: '1人前',
              kcal: 290,
              proteinG: 20,
              fatG: 10,
              carbG: 30,
              knownProduct: false,
            ).toEstimate(),
          ),
          recordEdit: (usageId, edited) async {
            expect(usageId, 'usage-1');
            outcomes.add(edited);
          },
        ),
      ),
    );
    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();
    expect(controller.foodEntries, hasLength(1));
    expect(outcomes, [false]);
    expect(await pending.preferLocalIds(PendingRecordKind.food), {
      controller.foodEntries.single.id,
    });
  });
}

class _ActivePlus extends UnavailableSubscriptionRepository {
  @override
  bool get isPlusActive => true;
}
