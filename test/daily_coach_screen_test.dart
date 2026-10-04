import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
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
    Future<void> Function(CoachMealProposal proposal)? onSelectMeal,
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

  testWidgets('the coach screen always shows the trial notice and a meal', (
    tester,
  ) async {
    var selected = false;
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        meals: [sampleMeal()],
        exerciseMessage:
            '今日の超過を戻すには、ランニング12.4kmが必要です。今日やるなら3kmまでにします。残りは明日以降の食事で調整しましょう。',
      ),
      onSelectMeal: (_) async {
        selected = true;
      },
    );

    expect(find.text(coachTrialNotice), findsOneWidget);
    final mealBottom = tester.getBottomLeft(find.text(headline)).dy;
    final noteTop = tester
        .getTopLeft(find.byKey(const Key('coach_verification_notice')))
        .dy;
    expect(noteTop, greaterThan(mealBottom));
    expect(find.text(headline), findsOneWidget);
    expect(find.textContaining('約10g多くなります'), findsOneWidget);
    expect(find.textContaining('ランニング12.4km'), findsOneWidget);
    expect(find.text('今日は提案できません'), findsNothing);
    expect(find.text('Good'), findsNothing);
    expect(find.text('悪い'), findsNothing);

    await tester.tap(find.text(headline));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the coach stays open without a paid gate', (tester) async {
    await openCoach(
      tester,
      load: () async => DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        meals: [sampleMeal()],
      ),
    );

    expect(find.text(coachTrialNotice), findsOneWidget);
    expect(find.text('2回目以降はカロナビ+です。'), findsNothing);
    expect(find.text('カロナビ+を見る'), findsNothing);
    expect(find.text(headline), findsOneWidget);
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
      expect(find.text(coachTrialNotice), findsNWidgets(2));

      await tester.tap(find.widgetWithText(TextButton, '閉じる'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(intros.seen, isTrue);
      expect(find.text(coachTrialNotice), findsOneWidget);
      expect(find.byType(DailyCoachScreen), findsOneWidget);

      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(coachTrialNotice), findsOneWidget);
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
        meals: [sampleMeal()],
        exerciseMessage: '今日やるなら3kmまでにします。',
      ),
      onSelectMeal: (_) async {},
    );

    expect(log.records, hasLength(2));
    expect(log.records.first.proposal, contains(headline));
    expect(log.records.first.proposal, contains('白米（めし） 150g'));
    expect(log.records.first.registered, isFalse);
    expect(log.records.first.recordedAt, DateTime(2026, 10, 4, 9));
    expect(log.records.last.proposal, '今日やるなら3kmまでにします。');
    expect(log.records.last.registered, isFalse);
    expect(find.text('Good'), findsNothing);
    expect(find.text('悪い'), findsNothing);

    await tester.tap(find.text(headline));
    await tester.pumpAndSettle();

    expect(log.records.first.registered, isTrue);
    expect(log.records.last.registered, isFalse);
  });

  testWidgets('home shows 今日のコーチ', (tester) async {
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: MockHealthRepository(isAvailable: false),
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

    expect(find.text('お知らせ'), findsOneWidget);
    expect(find.byKey(const Key('announcement_unread_dot')), findsNothing);
    final remainingTop = tester.getTopLeft(find.text('今日あと')).dy;
    final coachTop = tester.getTopLeft(find.text('今日のコーチ')).dy;
    expect(coachTop, greaterThan(remainingTop));
    expect(tester.widget<DesignButton>(find.byType(DesignButton)).height, 52);

    await tester.tap(find.text('今日のコーチ'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyCoachScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('戻る')));
    expect(route, isA<MaterialPageRoute<bool>>());
    expect((route! as PageRoute<bool>).fullscreenDialog, isFalse);

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyCoachScreen), findsNothing);

    await tester.tap(find.text('今日のコーチ'));
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
