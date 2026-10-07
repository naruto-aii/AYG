import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the proposal event waits for a valid saved meal', (
    tester,
  ) async {
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'coach_proposal_registered') {
        events.add(props);
      }
    };
    addTearDown(() => Analytics.onEmitForTest = null);

    const meal = CoachMealProposal(
      headline: '白米',
      kcal: 234,
      proteinG: 4,
      fatG: 1,
      carbG: 50,
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DailyCoachScreen(
          introStore: _SeenIntro(),
          load: () async => const DailyCoachLoadResult(
            status: DailyCoachStatus.ready,
            focus: DailyCoachFocus.meals,
            meals: [meal],
          ),
          onSelectMeal: (_, grams) async => ['saved-${grams.single.round()}'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('coach_meal_grams_0_0')), '0');
    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    expect(find.text('量は0より大きい数字にしてください'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coach_meal_grams_0_0')), '80');
    await tester.tap(find.widgetWithText(DesignButton, 'この量で登録'));
    await tester.pumpAndSettle();

    expect(events, hasLength(1));
    expect(events.single['food_entry_ids'], ['saved-80']);
    expect(events.single['coach_proposal_log_id'], isNotEmpty);
  });
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}
