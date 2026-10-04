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

  testWidgets('a plan must be chosen before the store purchase opens', (
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
    expect(
      tester
          .widget<DesignButton>(find.byKey(const Key('plus-purchase')))
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.byKey(const Key('plus-plan-yearly')));
    await tester.tap(find.byKey(const Key('plus-plan-yearly')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('購入する'));
    await tester.pumpAndSettle();

    expect(repository.purchased, PlusPlan.yearly);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-halfYear')));
    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('購入する'));
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
