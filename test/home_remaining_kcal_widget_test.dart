import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/widgets/home/remaining_macros_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RemainingKcalHero shows formatted remaining kcal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RemainingKcalHero(remainingKcal: 1234)),
      ),
    );

    expect(find.text('1234 kcal'), findsOneWidget);
    expect(find.text(AppStrings.remainingKcalSuffix), findsOneWidget);
  });
}
