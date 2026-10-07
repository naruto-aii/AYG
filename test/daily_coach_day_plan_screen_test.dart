import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:ayg/repositories/coach_slot_store.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 今日の残りに対して、どの食事で何を食べ、それぞれ何kcalで合計がいくつかが分かる画面。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<CoachDayPlan> plansAt(DateTime now, double remaining,
      {Set<MealSlot> skip = const {}}) {
    return planCoachDay(
      foods: CoachFoodCatalog.stocks,
      excludedFoodCodes: const {},
      remainingKcal: remaining,
      now: now,
      skipSlots: skip,
    );
  }

  /// 画面に出ている案（日付で選ばれる）と、その通し番号の先頭。
  (CoachDayPlan, int) visiblePlan(List<CoachDayPlan> plans, DateTime now) {
    final day = DateTime(now.year, now.month, now.day)
        .difference(DateTime(now.year))
        .inDays;
    final visible = day % plans.length;
    var offset = 0;
    for (var i = 0; i < visible; i++) {
      offset += plans[i].meals.length;
    }
    return (plans[visible], offset);
  }

  String textOf(WidgetTester tester, Key key) {
    final widget = tester.widget(find.byKey(key));
    if (widget is Text) {
      return widget.data!;
    }
    return [
      for (final text in tester.widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      ))
        text.data,
    ].join(' ');
  }

  Future<void> openCoach(
    WidgetTester tester, {
    required DateTime now,
    required DailyCoachLoadResult result,
    CoachSlotStore? slotStore,
    List<CoachMealProposal>? saved,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'test'),
            builder: (context) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'coach'),
                      builder: (context) => DailyCoachScreen(
                        introStore: _SeenIntro(),
                        now: now,
                        slotStore: slotStore ?? MemoryCoachSlotStore(),
                        load: () async => result,
                        onSelectMeal: (proposal, grams) async {
                          saved?.add(proposal);
                          return ['id-${saved?.length ?? 0}'];
                        },
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('6:00 shows today\'s remainder split by meal, with a total', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 6);
    final plans = plansAt(now, 2438);
    expect(plans, isNotEmpty);
    final (plan, offset) = visiblePlan(plans, now);
    final slotStore = MemoryCoachSlotStore();
    final saved = <CoachMealProposal>[];
    await openCoach(
      tester,
      now: now,
      slotStore: slotStore,
      saved: saved,
      result: DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: plans,
      ),
    );

    // 上のまとめ: 今日の残りに対する食べ方。
    expect(find.text('今日の残り 2,438kcal の食べ方'), findsOneWidget);
    final labels = ['朝食', '昼食', '間食', '夕食'];
    for (var m = 0; m < 4; m++) {
      expect(
        textOf(tester, Key('coach_summary_row_${offset + m}')),
        '${labels[m]} ${formatCoachKcal(plan.meals[m].kcal.round())}kcal',
      );
    }
    final total = plan.kcal.round();
    final percent = (total / 2438 * 100).round();
    expect(percent, greaterThanOrEqualTo(95));
    expect(
      textOf(tester, const Key('coach_day_total')),
      '合計 ${formatCoachKcal(total)}kcal（残りの$percent%）',
    );
    // まとめの行は時間の順。
    final rowTops = [
      for (var m = 0; m < 4; m++)
        tester.getTopLeft(find.byKey(Key('coach_summary_row_${offset + m}'))).dy,
    ];
    for (var i = 1; i < rowTops.length; i++) {
      expect(rowTops[i], greaterThan(rowTops[i - 1]));
    }

    // 枠ごとの見出し（枠名と kcal）と、食品・おすすめの量・kcal。
    final sectionTops = <double>[];
    for (var m = 0; m < 4; m++) {
      final index = offset + m;
      expect(textOf(tester, Key('coach_meal_label_$index')), labels[m]);
      expect(
        textOf(tester, Key('coach_meal_kcal_$index')),
        '${formatCoachKcal(plan.meals[m].kcal.round())}kcal',
      );
      sectionTops.add(
        tester.getTopLeft(find.byKey(Key('coach_meal_label_$index'))).dy,
      );
      var sum = 0;
      for (var c = 0; c < plan.meals[m].components.length; c++) {
        final item = plan.meals[m].components[c];
        final kcal = (item.kcalPerUnit + 1e-9).round();
        sum += kcal;
        expect(textOf(tester, Key('coach_food_kcal_${index}_$c')),
            '${formatCoachKcal(kcal)}kcal');
        expect(find.textContaining('おすすめ ${item.grams}g'), findsWidgets);
      }
      expect(sum, plan.meals[m].kcal.round(),
          reason: 'foods add up to the meal');
    }
    expect(sectionTops.first,
        greaterThan(tester.getBottomLeft(find.byKey(const Key('coach_day_total'))).dy));
    for (var i = 1; i < sectionTops.length; i++) {
      expect(sectionTops[i], greaterThan(sectionTops[i - 1]));
    }

    // 量を変えると、食品・食事・まとめ・合計の kcal がその場で変わる。
    final first = plan.meals[0].components[0];
    final edited = first.grams * 1.5;
    await tester.enterText(
      find.byKey(Key('coach_meal_grams_${offset}_0')),
      formatCoachAmount(edited),
    );
    await tester.pump();
    final newFood = (first.kcalPerUnit * 1.5 + 1e-9).round();
    final oldFood = (first.kcalPerUnit + 1e-9).round();
    final newMeal = plan.meals[0].kcal.round() - oldFood + newFood;
    final newTotal = total - oldFood + newFood;
    expect(textOf(tester, Key('coach_food_kcal_${offset}_0')),
        '${formatCoachKcal(newFood)}kcal');
    expect(textOf(tester, Key('coach_meal_kcal_$offset')),
        '${formatCoachKcal(newMeal)}kcal');
    expect(textOf(tester, Key('coach_summary_row_$offset')),
        '朝食 ${formatCoachKcal(newMeal)}kcal');
    expect(
      textOf(tester, const Key('coach_day_total')),
      '合計 ${formatCoachKcal(newTotal)}kcal'
      '（残りの${(newTotal / 2438 * 100).round()}%）',
    );

    // 押した枠（昼食）だけを登録し、登録済みの枠として残す。
    final lunch = find.byKey(Key('coach_register_meal_${offset + 1}'));
    await tester.ensureVisible(lunch);
    await tester.tap(lunch);
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.slotLabel, '昼食');
    expect(saved.single.headline, plan.meals[1].headline);
    final registered = await slotStore.registeredOn(now);
    expect(registered.map((item) => item.slot), [MealSlot.lunch]);
    expect(registered.single.kcal, plan.meals[1].kcal.round());
    expect(registered.single.entryIds, ['id-1']);

    final shown = coachProposalRecords(
      now: now,
      result: DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: plans,
      ),
    );
    expect(shown.length, plans.fold<int>(0, (n, p) => n + p.meals.length));
  });

  testWidgets('16:00 dinner only keeps the same layout with the note', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 16);
    final plans = plansAt(now, 1200);
    final (plan, offset) = visiblePlan(plans, now);
    await openCoach(
      tester,
      now: now,
      result: DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: plans,
      ),
    );
    expect(find.text('今日の残り 1,200kcal の食べ方'), findsOneWidget);
    expect(textOf(tester, Key('coach_summary_row_$offset')),
        '夕食 ${formatCoachKcal(plan.kcal.round())}kcal');
    expect(find.byKey(Key('coach_summary_row_${offset + 1}')), findsNothing);
    expect(textOf(tester, const Key('coach_day_note')), contains('850kcal'));
    expect(textOf(tester, Key('coach_meal_label_$offset')), '夕食');
  });

  testWidgets('22:30 snacks only are numbered and keep the gentle note', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 22, 30);
    final plans = plansAt(now, 800);
    final (plan, offset) = visiblePlan(plans, now);
    expect(plan.meals, hasLength(2));
    await openCoach(
      tester,
      now: now,
      result: DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: plans,
      ),
    );
    expect(find.text('今日の残り 800kcal の食べ方'), findsOneWidget);
    expect(textOf(tester, Key('coach_summary_row_$offset')),
        '間食 1 ${plan.meals[0].kcal.round()}kcal');
    expect(textOf(tester, Key('coach_summary_row_${offset + 1}')),
        '間食 2 ${plan.meals[1].kcal.round()}kcal');
    expect(textOf(tester, const Key('coach_day_note')),
        '夜遅い時間なので、間食までにしています。残りは無理に食べなくて大丈夫です。');
  });

  testWidgets('a registered slot is shown as 登録済み and left out of the total', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 6, 10);
    final plans = plansAt(now, 1726, skip: {MealSlot.breakfast});
    final (plan, offset) = visiblePlan(plans, now);
    expect(plan.meals.map((meal) => meal.slotLabel), ['昼食', '間食', '夕食']);
    await openCoach(
      tester,
      now: now,
      result: DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        plans: plans,
        registered: const [
          CoachRegisteredSlot(
            slot: MealSlot.breakfast,
            kcal: 712,
            entryIds: ['a'],
          ),
        ],
      ),
    );
    expect(textOf(tester, const Key('coach_summary_registered_breakfast')),
        '朝食 登録済み 712kcal');
    final total = plan.kcal.round();
    expect(
      textOf(tester, const Key('coach_day_total')),
      '合計 ${formatCoachKcal(total)}kcal（残りの${(total / 1726 * 100).round()}%）',
    );
    expect(find.byKey(Key('coach_meal_label_$offset')), findsOneWidget);
    expect(textOf(tester, Key('coach_meal_label_$offset')), '昼食');
  });
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}
