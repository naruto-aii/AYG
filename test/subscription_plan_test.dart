import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('half year and yearly use intro product ids only inside the window', () {
    final start = SubscriptionCatalog.introWindowStart;
    final inside = start.add(const Duration(days: 10));
    final outside = DateTime.utc(start.year, start.month + 1, start.day);

    expect(SubscriptionCatalog.introWindowOpen(start), isTrue);
    expect(SubscriptionCatalog.introWindowOpen(inside), isTrue);
    expect(SubscriptionCatalog.introWindowOpen(outside), isFalse);

    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.monthly, inside),
      SubscriptionCatalog.monthlyProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.halfYear, inside),
      SubscriptionCatalog.halfYearIntroProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.yearly, inside),
      SubscriptionCatalog.yearlyIntroProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.monthly, outside),
      SubscriptionCatalog.monthlyProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.halfYear, outside),
      SubscriptionCatalog.halfYearProductId,
    );
    expect(
      SubscriptionCatalog.productIdFor(PlusPlan.yearly, outside),
      SubscriptionCatalog.yearlyProductId,
    );
    expect(
      SubscriptionCatalog.isPlusProduct(SubscriptionCatalog.halfYearProductId),
      isTrue,
    );
    expect(
      SubscriptionCatalog.isPlusProduct(
        SubscriptionCatalog.yearlyIntroProductId,
      ),
      isTrue,
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
    expect(find.text('¥5,800で始める'), findsOneWidget);
    expect(find.textContaining('¥580'), findsWidgets);
    expect(repository.purchased, isNull);

    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();
    expect(repository.purchased, PlusPlan.yearly);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-monthly')));
    await tester.tap(find.byKey(const Key('plus-plan-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('¥580で始める'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-halfYear')));
    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    expect(find.text('¥2,900で始める'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();

    expect(repository.purchased, PlusPlan.halfYear);

    await tester.ensureVisible(find.text('特定商取引法に基づく表記'));
    await tester.tap(find.text('特定商取引法に基づく表記'));
    await tester.pumpAndSettle();
    expect(repository.purchased, PlusPlan.halfYear);
  });

  testWidgets('an intro store price replaces the fallback on the button', (
    tester,
  ) async {
    final repository = _IntroPlans();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥2,240で始める'), findsNothing);
    expect(find.text('¥4,640で始める'), findsOneWidget);
    expect(find.textContaining('初回はさらに1ヶ月分安い'), findsWidgets);
    expect(
      find.text('公開から1ヶ月のあいだ、半年と年額は初回の商品です。月額は同じです。2回目以降は通常価格です。'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('plus-plan-halfYear')));
    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    expect(find.text('¥2,240で始める'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();
    expect(repository.purchased, PlusPlan.halfYear);
  });
}

class _IntroPlans extends _Plans {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥480',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearIntroProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥2,240',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyIntroProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥4,640',
      ),
      introOffer: true,
      loadFailed: false,
    );
  }
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
