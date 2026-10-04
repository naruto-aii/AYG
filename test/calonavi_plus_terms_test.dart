import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paywall shows the store price, renewal, and period', (
    tester,
  ) async {
    final repository = _PricedPlus();
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
      find.text('¥580 ・ ${AppStrings.plusMonthlyNote}'),
      findsOneWidget,
    );
    expect(
      find.text('¥2,900 ・ ${AppStrings.plusSemiannualNote}'),
      findsOneWidget,
    );
    expect(
      find.text('¥5,800 ・ ${AppStrings.plusYearlyNote}'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.plusBadgeSave), findsOneWidget);
    expect(find.text(AppStrings.plusBadgeBestValue), findsOneWidget);
    expect(find.text(AppStrings.plusBillingPeriod), findsOneWidget);
    expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);
    expect(find.text(AppStrings.plusCancelHow), findsOneWidget);
    expect(find.textContaining('現在の有効期限'), findsNothing);
    expect(find.textContaining('380'), findsNothing);

    // 一番お得な年額が初期選択され、CTA にその価格が出る。
    expect(find.text('¥5,800${AppStrings.plusCtaPrefix}'), findsOneWidget);
  });

  testWidgets('paywall shows a store expiry when one is already known', (
    tester,
  ) async {
    final repository = _PricedPlus(
      entitlements: [
        SubscriptionEntitlementRecord(
          productId: SubscriptionCatalog.yearlyProductId,
          expiresAt: DateTime.utc(2099, 1, 2, 12),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('現在の有効期限: 2099/01/02'), findsOneWidget);
  });
}

class _PricedPlus extends UnavailableSubscriptionRepository {
  _PricedPlus({this.entitlements = const []});

  final List<SubscriptionEntitlementRecord> entitlements;

  @override
  List<SubscriptionEntitlementRecord> get confirmedEntitlements => entitlements;

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥580',
      ),
      semiannual: SubscriptionProductOffer(
        productId: SubscriptionCatalog.semiannualProductId,
        period: PlusBillingPeriod.semiannual,
        localizedPrice: '¥2,900',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥5,800',
      ),
      loadFailed: false,
    );
  }
}
