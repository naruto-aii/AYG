import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/screens/subscription/calonavi_plus_screen.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_subscription_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plus screen offers monthly and yearly prices', (tester) async {
    final repository = MockSubscriptionRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );

    expect(find.text(AppStrings.plusTitle), findsOneWidget);
    expect(find.textContaining(SubscriptionCatalog.monthlyLabel), findsOneWidget);
    expect(find.textContaining(SubscriptionCatalog.yearlyLabel), findsOneWidget);

    await tester.tap(find.textContaining(SubscriptionCatalog.monthlyLabel));
    await tester.pumpAndSettle();

    expect(repository.monthlyCalled, isTrue);
    expect(repository.plus, isTrue);

    await repository.dispose();
  });
}
