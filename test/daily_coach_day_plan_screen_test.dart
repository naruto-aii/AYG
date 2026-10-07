import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2,438kcal 残り（1:10）で、朝食・昼食・夕食の案が並び、食べた回だけ登録できる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a day plan lists each meal and registers only the tapped one', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 1, 10);
    final plans = planCoachDay(
      foods: CoachFoodCatalog.stocks,
      excludedFoodCodes: const {},
      remainingKcal: 2438,
      now: now,
    );
    expect(plans, isNotEmpty);
    final result = DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      focus: DailyCoachFocus.meals,
      plans: plans,
    );
    final saved = <CoachMealProposal>[];
    await tester.binding.setSurfaceSize(const Size(390, 4000));
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
                        load: () async => result,
                        onSelectMeal: (proposal, grams) async {
                          saved.add(proposal);
                          return ['id-${saved.length}'];
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

    expect(find.byKey(const Key('coach_day_plan_summary')), findsOneWidget);
    expect(find.text('朝食'), findsOneWidget);
    expect(find.text('昼食'), findsOneWidget);
    expect(find.text('夕食'), findsOneWidget);
    // 間食は食事のあとの端数だけ。出るときは夕食より下。
    final snack = find.text('間食');
    if (snack.evaluate().isNotEmpty) {
      expect(
        tester.getTopLeft(snack.first).dy,
        greaterThan(tester.getTopLeft(find.text('夕食')).dy),
      );
    }

    final shown = coachProposalRecords(now: now, result: result);
    expect(shown.length, plans.fold<int>(0, (n, p) => n + p.meals.length));

    final day = DateTime(now.year, now.month, now.day)
        .difference(DateTime(now.year))
        .inDays;
    final visible = day % plans.length;
    var offset = 0;
    for (var i = 0; i < visible; i++) {
      offset += plans[i].meals.length;
    }
    final lunch = find.byKey(Key('coach_register_meal_${offset + 1}'));
    await tester.ensureVisible(lunch);
    await tester.tap(lunch);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.slotLabel, '昼食');
    expect(saved.single.headline, plans[visible].meals[1].headline);
  });
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}
