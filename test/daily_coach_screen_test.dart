import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/subscription_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/repositories/coach_nutrition_source.dart';
import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const headline = '卵かけご飯（白米150gと卵1個）';

  CoachMealProposal sampleMeal() {
    return const CoachMealProposal(
      headline: headline,
      kcal: 301,
      proteinG: 10,
      fatG: 5,
      carbG: 40,
      macroNote: 'これだとたんぱく質が約10g多くなります。今提案できる範囲で最善です。',
      components: [
        CoachMealComponent(
          foodCode: '01088',
          displayName: '白米（めし）',
          officialName: '精白米',
          units: 1,
          grams: 150,
          kcalPerUnit: 234,
          proteinPerUnit: 3.75,
          fatPerUnit: 0.45,
          carbPerUnit: 55.65,
        ),
      ],
    );
  }

  Future<void> openCoach(
    WidgetTester tester, {
    required Future<DailyCoachLoadResult> Function() load,
    Future<void> Function(CoachMealProposal proposal, List<double> grams)?
    onSelectMeal,
    Future<void> Function(CoachExerciseProposal proposal, double amount)?
    onSelectExercise,
    CoachIntroStore? introStore,
    CoachProposalLog? proposalLog,
    DateTime? now,
  }) async {
    final intros = introStore ?? _MemoryIntro(seen: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => DailyCoachScreen(
                      load: load,
                      onSelectMeal: onSelectMeal,
                      onSelectExercise: onSelectExercise,
                      introStore: intros,
                      proposalLog: proposalLog,
                      now: now,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the coach screen explains the proposal and shows a meal', (
    tester,
  ) async {
    var selected = false;
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        meals: [sampleMeal()],
      ),
      onSelectMeal: (_, grams) async {
        selected = grams.single == 150;
      },
    );

    expect(find.text(AppStrings.coachFeatureBody), findsOneWidget);
    expect(find.text(AppStrings.coachBetaNotice), findsNothing);
    expect(find.text('今日のコーチ (β)'), findsOneWidget);
    final mealBottom = tester.getBottomLeft(find.text(headline)).dy;
    final noteTop = tester
        .getTopLeft(find.byKey(const Key('coach_beta_notice')))
        .dy;
    expect(noteTop, greaterThan(mealBottom));
    expect(find.text(headline), findsOneWidget);
    expect(find.textContaining('約10g多くなります'), findsOneWidget);
    expect(find.text('今日は提案できません'), findsNothing);
    expect(find.text('Good'), findsNothing);
    expect(find.text('悪い'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('coach_meal_grams_0_0')))
          .controller
          ?.text,
      '150',
    );

    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an unpaid account cannot open the coach', (tester) async {
    final controller = _profiledController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('今日のコーチ (β)'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyCoachScreen), findsNothing);
    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(find.text(AppStrings.coachBetaNotice), findsOneWidget);
    expect(find.text('カロナビ+を見る'), findsOneWidget);
    expect(find.text('2回目以降はカロナビ+です。'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
  });

  testWidgets('the coach screen does not propose when unpaid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DailyCoachScreen(
          controller: _profiledController(),
          load: () async => DailyCoachLoadResult(
            status: DailyCoachStatus.ready,
            meals: [sampleMeal()],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(headline), findsNothing);
    expect(find.text('この量で登録'), findsNothing);
    expect(find.text(AppStrings.coachBetaNotice), findsOneWidget);
    expect(find.text('カロナビ+を見る'), findsOneWidget);
  });

  testWidgets(
    'the first open shows the notice in a dialog, later opens do not',
    (tester) async {
      final intros = _MemoryIntro();
      await openCoach(
        tester,
        introStore: intros,
        load: () async => DailyCoachLoadResult(
          status: DailyCoachStatus.ready,
          meals: [sampleMeal()],
        ),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(AppStrings.coachFeatureBody), findsNWidgets(2));
      expect(find.text(AppStrings.coachBetaNotice), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, '閉じる'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(intros.seen, isTrue);
      expect(find.text(AppStrings.coachFeatureBody), findsOneWidget);
      expect(find.text(AppStrings.coachBetaNotice), findsNothing);
      expect(find.byType(DailyCoachScreen), findsOneWidget);

      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(AppStrings.coachFeatureBody), findsOneWidget);
      expect(find.text(AppStrings.coachBetaNotice), findsNothing);
    },
  );

  testWidgets('shown proposals are saved and a chosen meal is marked', (
    tester,
  ) async {
    final log = MemoryCoachProposalLog();
    await openCoach(
      tester,
      proposalLog: log,
      now: DateTime(2026, 10, 4, 9),
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        meals: [sampleMeal()],
      ),
      onSelectMeal: (_, _) async {},
    );

    expect(log.records, hasLength(1));
    expect(log.records.single.proposal, contains(headline));
    expect(log.records.single.proposal, contains('白米（めし） 150g'));
    expect(log.records.single.registered, isFalse);
    expect(log.records.single.recordedAt, DateTime(2026, 10, 4, 9));
    expect(find.text('Good'), findsNothing);
    expect(find.text('悪い'), findsNothing);
    expect(find.textContaining('km'), findsNothing);

    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();

    expect(log.records.single.registered, isTrue);
  });

  testWidgets('a changed gram is what gets registered', (tester) async {
    List<double>? saved;
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        meals: [sampleMeal()],
      ),
      onSelectMeal: (_, grams) async {
        saved = grams;
      },
    );

    await tester.enterText(
      find.byKey(const Key('coach_meal_grams_0_0')),
      '80',
    );
    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();

    expect(saved, [80]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a zero amount stays on the coach page', (tester) async {
    var saved = false;
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.meals,
        meals: [sampleMeal()],
      ),
      onSelectMeal: (_, _) async {
        saved = true;
      },
    );

    await tester.enterText(find.byKey(const Key('coach_meal_grams_0_0')), '0');
    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();

    expect(saved, isFalse);
    expect(find.text('量は0より大きい数字にしてください'), findsOneWidget);
    expect(find.byType(DailyCoachScreen), findsOneWidget);
  });

  testWidgets('an overage day shows exercise only and registers the edit', (
    tester,
  ) async {
    double? saved;
    final proposal = buildCoachExerciseProposal(
      overageKcal: 744,
      weightKg: 60,
      now: DateTime(2026, 10, 4),
      exercises: [
        ExerciseEntry(
          id: 'run',
          name: 'ランニング',
          activityId: 'running',
          durationMin: 20,
          distanceKm: 2,
          burnedKcal: 120,
          loggedAt: DateTime(2026, 10, 3),
        ),
      ],
    );
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.exercise,
        meals: [sampleMeal()],
        exercise: proposal,
      ),
      onSelectExercise: (_, amount) async {
        saved = amount;
      },
    );

    expect(find.text(headline), findsNothing);
    expect(find.textContaining('3kmまでにします'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('coach_exercise_amount')))
          .controller
          ?.text,
      '3',
    );

    await tester.enterText(
      find.byKey(const Key('coach_exercise_amount')),
      '2.5',
    );
    await tester.tap(find.byKey(const Key('coach_register_exercise')));
    await tester.pumpAndSettle();

    expect(saved, 2.5);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('meals and exercise are not shown together', (tester) async {
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        meals: [sampleMeal()],
        exerciseMessage: '今日やるなら3kmまでにします。',
      ),
    );

    expect(find.text(headline), findsNothing);
    expect(find.textContaining('3km'), findsNothing);
    expect(find.text('この量で登録'), findsNothing);
    expect(find.text(AppStrings.coachFeatureBody), findsOneWidget);
    expect(find.text(AppStrings.coachBetaNotice), findsNothing);
  });

  testWidgets('remaining days load meals and overage days load exercise', (
    tester,
  ) async {
    final controller = _profiledController();
    final session = DailyCoachSession(
      controller: controller,
      nutritionSource: _FixedNutrition([_riceStock()]),
    );
    final meals = await session.load(DateTime.now());
    expect(controller.summary!.remainingKcal, greaterThan(0));
    expect(meals.focus, DailyCoachFocus.meals);
    expect(meals.meals, isNotEmpty);
    expect(meals.exercise, isNull);
    expect(meals.offersExercise, isFalse);

    final missing = await DailyCoachSession(
      controller: controller,
      nutritionSource: _FixedNutrition(const [], fail: true),
    ).load(DateTime.now());
    expect(missing.status, DailyCoachStatus.nutritionMissing);

    controller.foodEntries.add(
      FoodEntry(
        id: 'big',
        name: '多い',
        kcalPerBase: 20000,
        loggedAt: DateTime.now(),
      ),
    );
    controller.refreshDailySummary();
    expect(controller.summary!.remainingKcal, lessThan(0));

    final exerciseDay = await DailyCoachSession(
      controller: controller,
      nutritionSource: _FixedNutrition(const [], fail: true),
    ).load(DateTime.now());
    expect(exerciseDay.focus, DailyCoachFocus.exercise);
    expect(exerciseDay.meals, isEmpty);
    expect(exerciseDay.offersMeals, isFalse);
    expect(exerciseDay.exercise, isNotNull);
    expect(exerciseDay.exercise!.canRegister, isTrue);

    final proposal = exerciseDay.exercise!;
    final registered = await DailyCoachSession(
      controller: controller,
    ).saveExercise(proposal, amount: proposal.amount!);
    expect(registered, isTrue);
    expect(controller.exerciseEntries.single.activityId, proposal.activityId);

    final edited = await DailyCoachSession(
      controller: controller,
    ).saveExercise(proposal, amount: proposal.amount! + 1);
    expect(edited, isTrue);
    expect(
      controller.exerciseEntries.last.effectiveNetKcal,
      isNot(closeTo(controller.exerciseEntries.first.effectiveNetKcal, 0.001)),
    );

    await DailyCoachSession(controller: controller).saveMeal(sampleMeal());
    expect(controller.foodEntries.last.consumedAmount, 1);
    await DailyCoachSession(
      controller: controller,
    ).saveMeal(sampleMeal(), grams: const [100]);
    expect(controller.foodEntries.last.consumedAmount, closeTo(100 / 150, 0.0001));
    expect(controller.foodEntries.last.totalKcal, closeTo(234 * 100 / 150, 0.01));
  });

  testWidgets('home shows 今日のコーチ', (tester) async {
    final controller = _profiledController(subscription: _Plus(true));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('お知らせ'), findsOneWidget);
    expect(find.byKey(const Key('announcement_unread_dot')), findsNothing);
    final remainingTop = tester.getTopLeft(find.text('今日あと')).dy;
    final coachTop = tester.getTopLeft(find.text('今日のコーチ (β)')).dy;
    expect(coachTop, greaterThan(remainingTop));
    expect(tester.widget<DesignButton>(find.byType(DesignButton)).height, 52);

    await tester.tap(find.text('今日のコーチ (β)'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyCoachScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('戻る')));
    expect(route, isA<MaterialPageRoute<CoachSavedKind>>());
    expect((route! as PageRoute<CoachSavedKind>).fullscreenDialog, isFalse);

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyCoachScreen), findsNothing);

    await tester.tap(find.text('今日のコーチ (β)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyCoachScreen), findsNothing);
    expect(find.text('今日あと'), findsOneWidget);
  });
}

class _MemoryIntro implements CoachIntroStore {
  _MemoryIntro({this.seen = false});

  bool seen;

  @override
  Future<bool> hasSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
  }
}

AppController _profiledController({SubscriptionRepository? subscription}) {
  final controller = AppController(
    nutritionEngine: NutritionEngine(),
    healthRepository: MockHealthRepository(isAvailable: false),
    subscriptionRepository: subscription,
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

CoachFoodStock _riceStock() {
  return CoachFoodStock(
    candidate: CoachFoodCatalog.find('01088')!,
    nutrition: const CoachFoodNutrition(
      foodCode: '01088',
      kcal: 156,
      proteinG: 2.5,
      fatG: 0.3,
      carbG: 37.1,
      officialName: '精白米',
    ),
  );
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;
}

class _FixedNutrition implements CoachNutritionSource {
  _FixedNutrition(this.stocks, {this.fail = false});

  final List<CoachFoodStock> stocks;
  final bool fail;

  @override
  Future<List<CoachFoodStock>> load() async {
    if (fail) {
      throw StateError('nutrition');
    }
    return stocks;
  }
}
