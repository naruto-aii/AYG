import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_button.dart';
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

    expect(find.text('¥580 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥2,900 ・ 月あたり約483円'), findsOneWidget);
    expect(find.text('¥5,400 ・ 月あたり450円'), findsOneWidget);
    expect(find.text('¥5,400で始める'), findsOneWidget);
    expect(AppStrings.plusBenefitSiriBody.contains('β'), isFalse);
    expect(AppStrings.plusBenefitSiriBody.contains('カロナビ+'), isFalse);
    expect(find.text('お得'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);
    expect(
      tester
          .widget<DesignButton>(find.byKey(const Key('plus-purchase')))
          .onPressed,
      isNotNull,
    );
    expect(find.text(AppStrings.plusHeroSubtitle), findsOneWidget);
    expect(find.text(AppStrings.plusBetaAccessLead), findsOneWidget);
    expect(find.text(AppStrings.plusBenefitWidgetTitle), findsOneWidget);
    expect(find.text(AppStrings.plusBenefitWidgetBody), findsOneWidget);
    expect(find.text(AppStrings.plusBenefitSiriTitle), findsOneWidget);
    expect(find.text(AppStrings.plusBenefitSiriBody), findsOneWidget);
    expect(find.text(AppStrings.plusBetaAccessTitle), findsOneWidget);
    expect(find.text(AppStrings.plusBetaAccessBody), findsOneWidget);
    expect(find.textContaining('(β)'), findsWidgets);
    expect(find.text(AppStrings.plusBillingPeriod), findsOneWidget);
    expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);
    expect(find.text(AppStrings.plusCancelHow), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('特定商取引法に基づく表記'), findsOneWidget);
    expect(AppStrings.plusAutoRenew, contains('Apple ID'));
    expect(AppStrings.plusAutoRenew, contains('24時間以上前'));
    expect(AppStrings.plusAutoRenew, contains('24時間以内'));
    expect(AppStrings.plusCancelHow, contains('App Store'));
    expect(AppStrings.plusBenefitSiriTitle, '音声登録 (β)');
    expect(AppStrings.plusBetaAccessBody, contains('音声登録 (β)'));
    expect(find.textContaining('現在の有効期限'), findsNothing);
    expect(find.textContaining('380'), findsNothing);
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

  testWidgets('a different store price keeps its own monthly note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: _DifferentStorePrices()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥580 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥3,480 ・ 月あたり580円'), findsOneWidget);
    expect(find.text('¥5,800 ・ 月あたり約483円'), findsOneWidget);
    expect(find.text('¥5,800で始める'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);
    expect(find.text('お得'), findsNothing);
    expect(find.textContaining('¥5,400'), findsNothing);
    expect(find.textContaining('¥2,900'), findsNothing);
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
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥2,900',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥5,400',
      ),
      loadFailed: false,
    );
  }
}

class _DifferentStorePrices extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥580',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥3,480',
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
