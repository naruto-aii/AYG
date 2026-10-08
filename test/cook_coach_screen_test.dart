import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/cook_coach.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:ayg/theme/app_typography.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 8, 18);
  const target = CookCoachMealTarget(
    slot: MealSlot.dinner,
    kcal: 650,
    proteinG: 32,
    fatG: 18,
    carbG: 75,
    remainingKcal: 650,
    remainingProteinG: 32,
    remainingFatG: 18,
    remainingCarbG: 75,
  );

  setUp(() {
    Analytics.onEmitForTest = null;
  });

  testWidgets('input, two patterns, and the gap vs the meal target', (
    tester,
  ) async {
    final events = <String>[];
    Analytics.onEmitForTest = (name, _) => events.add(name);
    Map<String, Object?>? sent;
    await tester.pumpWidget(
      _app(
        CookCoachScreen(
          now: now,
          target: target,
          client: CookCoachClient(
            invoke: (body) async {
              sent = body;
              return _payload();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自炊コーチ (β)'), findsOneWidget);
    final title = tester.widget<Text>(find.byKey(const Key('cook_coach_title')));
    expect(title.style?.fontSize, AppTypography.headingL.fontSize);
    expect(find.text('夕食の目標 650kcal（P 32g / F 18g / C 75g）'), findsOneWidget);
    expect(events, contains('cook_coach_open'));

    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.enterText(
      find.byKey(const Key('cook_ingredient_input')),
      '玉ねぎ、ごはん',
    );
    await tester.ensureVisible(find.byKey(const Key('cook_add_ingredient')));
    await tester.tap(find.byKey(const Key('cook_add_ingredient')));
    await tester.ensureVisible(find.byKey(const Key('cook_note_20分')));
    await tester.tap(find.byKey(const Key('cook_note_20分')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();

    expect(sent?['ingredients'], ['卵', '玉ねぎ', 'ごはん']);
    expect(sent?['slot'], 'dinner');
    expect(sent?['note'], '20分');
    expect(sent?['target_kcal'], 650);
    expect(find.text('あと＋508kcal'), findsOneWidget);
    expect(find.text('あと＋516kcal'), findsOneWidget);
    expect(find.text('142kcal　P 29.0g　F 2.0g　C 2.0g'), findsOneWidget);
    expect(find.text('134kcal　P 27.0g　F 2.0g　C 3.0g'), findsOneWidget);
    expect(find.text('目標の範囲に入っています'), findsNothing);
    expect(find.text('手持ちだけで作れます'), findsOneWidget);
    expect(find.text('買い足しで作れます'), findsOneWidget);
    expect(find.byKey(const Key('cook_ingredient_on_hand_鶏むね肉')), findsOneWidget);
    expect(find.text('120g'), findsWidgets);
    expect(find.byKey(const Key('cook_kcal_on_hand_鶏むね肉')), findsOneWidget);
    expect(find.text('成分表に無い食品はAIの目安です。'), findsOneWidget);
    expect(events, contains('cook_coach_generate'));
    expect(events, contains('cook_coach_retry'));
  });

  testWidgets('register writes the shown grams and nutrition to the outbox', (
    tester,
  ) async {
    final pending = PendingRecordStore();
    final controller = AppController(pendingRecords: pending);
    addTearDown(controller.dispose);
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'cook_coach_register' || name == 'food_entry_added') {
        events.add({'name': name, ...props});
      }
    };
    final loggedAt = DateTime(2026, 10, 8, 18, 5);

    await tester.pumpWidget(
      _app(
        CookCoachScreen(
          now: now,
          target: target,
          client: CookCoachClient(invoke: (_) async => _payload()),
          onRegister: (dish, slot) {
            expect(slot, MealSlot.dinner);
            return saveCookCoachDish(
              controller: controller,
              dish: dish,
              loggedAt: loggedAt,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();

    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.byKey(const Key('cook_saved_totals')), findsOneWidget);
    expect(controller.foodEntries, hasLength(2));
    final chicken = controller.foodEntries[0];
    final sauce = controller.foodEntries[1];
    expect(chicken.name, '鶏むね肉');
    expect(chicken.mealGroupName, '鶏肉と野菜の煮物');
    expect(chicken.baseAmount, 120);
    expect(chicken.consumedAmount, 120);
    expect(chicken.unitType, FoodUnitType.g);
    expect(chicken.totalKcal, 130);
    expect(chicken.totalProteinG, 28);
    expect(chicken.totalFatG, 2);
    expect(chicken.totalCarbG, 0);
    expect(chicken.sourceType, FoodEntrySource.mextSfct);
    expect(chicken.officialFoodCode, '11226');
    expect(sauce.name, '自家製つゆ');
    expect(sauce.consumedAmount, 15);
    expect(sauce.totalKcal, 12);
    expect(sauce.totalProteinG, 1);
    expect(sauce.totalFatG, 0);
    expect(sauce.totalCarbG, 2);
    expect(sauce.sourceType, FoodEntrySource.manual);
    expect(sauce.officialFoodCode, isNull);
    expect(sauce.mealGroupId, chicken.mealGroupId);
    expect(sauce.loggedAt, loggedAt);
    expect(chicken.totalKcal + sauce.totalKcal, 142);
    final savedTotals = tester.widget<Text>(
      find.byKey(const Key('cook_saved_totals')),
    );
    expect(savedTotals.data, startsWith('142kcal'));
    expect(
      chicken.totalKcal + sauce.totalKcal,
      int.parse(savedTotals.data!.split('kcal').first),
    );
    expect(
      await pending.preferLocalIds(PendingRecordKind.food),
      {chicken.id, sauce.id},
    );
    expect(await pending.pendingDeleteIds(PendingRecordKind.food), isEmpty);
    expect(
      events.where((event) => event['name'] == 'food_entry_added'),
      hasLength(2),
    );
    final registered = events.singleWhere(
      (event) => event['name'] == 'cook_coach_register',
    );
    expect(registered['pattern'], 'on_hand');
    expect(registered['food_entry_ids'], [chicken.id, sauce.id]);
  });

  testWidgets('the daily cap uses the shared message', (tester) async {
    final events = <String>[];
    Analytics.onEmitForTest = (name, _) => events.add(name);
    await tester.pumpWidget(
      _app(
        CookCoachScreen(
          now: now,
          target: target,
          client: CookCoachClient(
            invoke: (_) async => {
              'ok': false,
              'code': 'daily_cap',
              'message': cookCoachCapMessage,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(find.text('本日の上限に達しました'), findsOneWidget);
    expect(events, contains('cook_coach_cap'));
  });

  testWidgets('plus is required and the coach screen opens it', (tester) async {
    final controller = AppController(
      subscriptionRepository: _Plus(false),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        DailyCoachScreen(
          controller: controller,
          now: now,
          introStore: _SeenIntro(),
          load: () async => const DailyCoachLoadResult(
            status: DailyCoachStatus.ready,
            focus: DailyCoachFocus.none,
            message: '今日はちょうどいいところです',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cook_coach_entry')), findsNothing);
    expect(find.text('カロナビ+を見る'), findsOneWidget);

    await tester.pumpWidget(
      _app(CookCoachScreen(controller: controller, now: now)),
    );
    await tester.pumpAndSettle();
    expect(find.text('カロナビ+を見る'), findsOneWidget);
    expect(find.byKey(const Key('cook_generate')), findsNothing);
  });

  testWidgets('a day already at the target explains that and does not generate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CookCoachScreen(
          now: now,
          target: const CookCoachMealTarget(
            slot: MealSlot.dinner,
            kcal: 0,
            proteinG: 0,
            fatG: 0,
            carbG: 0,
            remainingKcal: 0,
            remainingProteinG: 0,
            remainingFatG: 0,
            remainingCarbG: 0,
          ),
          client: CookCoachClient(invoke: (_) async => _payload()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日の目標は、もう足りています。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cook_choice_卵')));
    await tester.pumpAndSettle();
    final button = tester.widget<DesignButton>(find.byKey(const Key('cook_generate')));
    expect(button.onPressed, isNull);
  });
}

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.light, home: home);
}

Map<String, Object?> _payload() {
  return {
    'ok': true,
    'retried': true,
    'calls': [
      {'input_tokens': 400, 'output_tokens': 220, 'latency_ms': 300},
      {'input_tokens': 260, 'output_tokens': 180, 'latency_ms': 250},
    ],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏肉と野菜の煮物',
        'steps': ['鶏肉は中まで火を通す', '野菜と煮る'],
        'extras': <String>[],
        'kcal': 142,
        'protein_g': 29,
        'fat_g': 2,
        'carb_g': 2,
        'gap_kcal': 80,
        'gap_protein_g': 3,
        'gap_fat_g': 16,
        'gap_carb_g': 73,
        'within_tolerance': false,
        'ingredients': [
          {
            'name': '鶏むね肉',
            'grams': 120,
            'kcal': 130,
            'protein_g': 28,
            'fat_g': 2,
            'carb_g': 0,
            'source': 'db',
            'food_code': '11226',
            'official_name': '鶏むね肉',
          },
          {
            'name': '自家製つゆ',
            'grams': 15,
            'kcal': 12,
            'protein_g': 1,
            'fat_g': 0,
            'carb_g': 2,
            'source': 'ai',
          },
        ],
      },
      {
        'kind': 'extra',
        'name': 'トマト煮',
        'steps': ['肉の中まで火を通す'],
        'extras': ['トマト'],
        'kcal': 160,
        'protein_g': 28,
        'fat_g': 2,
        'carb_g': 5,
        'gap_kcal': 80,
        'gap_protein_g': 4,
        'gap_fat_g': 16,
        'gap_carb_g': 70,
        'ingredients': [
          {
            'name': '鶏むね肉',
            'grams': 110,
            'kcal': 119,
            'protein_g': 26,
            'fat_g': 2,
            'carb_g': 0,
            'source': 'db',
            'food_code': '11226',
            'official_name': '鶏むね肉',
          },
          {
            'name': 'トマト',
            'grams': 80,
            'kcal': 15,
            'protein_g': 1,
            'fat_g': 0,
            'carb_g': 3,
            'source': 'db',
            'food_code': '06199',
            'official_name': 'トマト',
            'extra': true,
          },
        ],
      },
    ],
  };
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}
