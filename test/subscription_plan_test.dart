import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchases use only the three standard product ids', () {
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.monthly),
      SubscriptionCatalog.monthlyProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.halfYear),
      SubscriptionCatalog.halfYearProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.yearly),
      SubscriptionCatalog.yearlyProductId,
    );
    expect(SubscriptionCatalog.plusProductIds, {
      SubscriptionCatalog.monthlyProductId,
      SubscriptionCatalog.halfYearProductId,
      SubscriptionCatalog.yearlyProductId,
    });
    expect(
      SubscriptionCatalog.isPlusProduct('calonavi_plus_half_year_intro'),
      isFalse,
    );
    expect(
      SubscriptionCatalog.isPlusProduct('calonavi_plus_yearly_intro'),
      isFalse,
    );
  });

  testWidgets('the screen opens on yearly and the button follows the plan', (
    tester,
  ) async {
    final repository = _Plans();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('月額'), findsOneWidget);
    expect(find.text('半年'), findsOneWidget);
    expect(find.text('年額'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(find.textContaining('¥980'), findsWidgets);
    expect(find.textContaining('初回'), findsNothing);
    expect(find.textContaining('公開から1ヶ月'), findsNothing);
    expect(repository.purchased, isNull);

    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();
    expect(repository.purchased, PlusPlan.yearly);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-monthly')));
    await tester.tap(find.byKey(const Key('plus-plan-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('¥980で始める'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-halfYear')));
    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    expect(find.text('¥4,900で始める'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();

    expect(repository.purchased, PlusPlan.halfYear);

    await tester.ensureVisible(find.text('特定商取引法に基づく表記'));
    await tester.tap(find.text('特定商取引法に基づく表記'));
    await tester.pumpAndSettle();
    expect(repository.purchased, PlusPlan.halfYear);
  });
}

class _Plans extends UnavailableSubscriptionRepository {
  PlusPlan? purchased;

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return SubscriptionOfferings.failed;
  }

  @override
  Future<void> purchasePlan(PlusPlan plan) async {
    purchased = plan;
  }
}
