import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/theme/app_typography.dart';
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

    expect(find.text('¥980 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥4,900 ・ 月あたり約817円'), findsOneWidget);
    expect(find.text('¥8,800 ・ 月あたり約733円'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
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
    expect(AppStrings.plusBenefitWidgetTitle, 'ウィジェットでワンタップ記録');
    expect(AppStrings.plusBenefitWidgetBody, contains('ホーム画面とロック画面のウィジェット'));
    expect(AppStrings.plusBenefitPhotoTitle, '写真で登録 (β)');
    expect(AppStrings.plusBenefitAiSearchTitle, 'AIで探す (β)');
    expect(AppStrings.plusBenefitAiSearchBody, contains('チェーン店'));
    expect(AppStrings.plusBenefitAiSearchBody, contains('推定だと表示します'));
    expect(AppStrings.plusBetaAccessBody, contains('音声登録 (β)'));
    expect(AppStrings.plusBetaAccessBody, contains('AIで探す (β)'));
    expect(find.textContaining('精度検証中'), findsNothing);
    final photoTitle = tester.widget<Text>(
      find.text(AppStrings.plusBenefitPhotoTitle),
    );
    final aiTitle = tester.widget<Text>(
      find.text(AppStrings.plusBenefitAiSearchTitle),
    );
    expect(photoTitle.style?.fontSize, AppTypography.titleS.fontSize);
    expect(aiTitle.style?.fontSize, AppTypography.titleS.fontSize);
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

    expect(find.text('¥1,200 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥7,200 ・ 月あたり1,200円'), findsOneWidget);
    expect(find.text('¥10,000 ・ 月あたり約833円'), findsOneWidget);
    expect(find.text('¥10,000で始める'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);
    expect(find.text('お得'), findsNothing);
    expect(find.textContaining('¥980'), findsNothing);
    expect(find.textContaining('¥4,900'), findsNothing);
    expect(find.textContaining('¥8,800'), findsNothing);
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
        localizedPrice: '¥980',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥4,900',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥8,800',
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
        localizedPrice: '¥1,200',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥7,200',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥10,000',
      ),
      loadFailed: false,
    );
  }
}
