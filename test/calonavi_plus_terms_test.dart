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

    expect(find.text('¥980'), findsOneWidget);
    expect(find.text('¥4,900'), findsOneWidget);
    expect(find.text('¥8,800'), findsOneWidget);
    expect(find.text('1か月ごと'), findsOneWidget);
    expect(find.text('月あたり約817円'), findsOneWidget);
    expect(find.text('月あたり約733円'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(AppStrings.plusBenefitSiriBody.contains('β'), isFalse);
    expect(AppStrings.plusBenefitSiriBody.contains('カロナビ+'), isFalse);
    expect(find.text('1か月分お得'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);
    expect(
      tester
          .widget<DesignButton>(find.byKey(const Key('plus-purchase')))
          .onPressed,
      isNotNull,
    );
    expect(find.text(AppStrings.plusHeroSubtitle), findsOneWidget);
    // 案A: 大きく出す4つと、その下のリンク。
    const hero = [
      AppStrings.plusBenefitPhotoTitle,
      AppStrings.plusBenefitAiSearchTitle,
      AppStrings.plusBenefitCoachTitle,
      AppStrings.plusBenefitWidgetTitle,
    ];
    for (final title in hero) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(
        tester.widget<Text>(find.text(title)).style?.fontSize,
        AppTypography.titleM.fontSize,
        reason: title,
      );
    }
    expect(find.text(AppStrings.plusHeroPhotoBody), findsOneWidget);
    expect(find.text(AppStrings.plusHeroAiSearchBody), findsOneWidget);
    expect(find.text(AppStrings.plusHeroCoachBody), findsOneWidget);
    expect(find.text(AppStrings.plusHeroWidgetBody), findsOneWidget);
    expect(find.text('その他の機能を見る'), findsOneWidget);
    // 残りはシートの中だけ。
    expect(find.text(AppStrings.plusMoreTemplateTitle), findsNothing);
    expect(find.text(AppStrings.plusBenefitSiriTitle), findsNothing);
    expect(find.text(AppStrings.plusBenefitEatingOutTitle), findsNothing);
    expect(find.text(AppStrings.plusAiLimitTitle), findsNothing);
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
    _expectNoBannedWording();
    expect(find.text('食事・運動の記録にメモを追加'), findsNothing);
    expect(find.textContaining('無料ではメモは使えません'), findsNothing);

    // 案B: リンクを押すと、画面内のシートで残りの機能を出す。
    await tester.ensureVisible(find.byKey(const Key('plus-more-features')));
    await tester.tap(find.byKey(const Key('plus-more-features')));
    await tester.pumpAndSettle();
    expect(find.text('カロナビ+のその他の機能'), findsOneWidget);
    expect(find.text(AppStrings.plusMoreFeaturesLead), findsOneWidget);
    for (final entry in {
      AppStrings.plusMoreTemplateTitle: AppStrings.plusMoreTemplateBody,
      AppStrings.plusBenefitSiriTitle: AppStrings.plusBenefitSiriBody,
      AppStrings.plusBenefitEatingOutTitle: AppStrings.plusMoreEatingOutBody,
      AppStrings.plusAiLimitTitle: AppStrings.plusMoreAiLimitBody,
    }.entries) {
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      expect(find.text(entry.value), findsOneWidget, reason: entry.value);
    }
    expect(find.text(AppStrings.siriVoicePaidGuidance), findsOneWidget);
    expect(find.textContaining('(β)'), findsWidgets);
    _expectNoBannedWording();
    await tester.tap(find.byKey(const Key('plus-more-features-close')));
    await tester.pumpAndSettle();
    expect(find.text('カロナビ+のその他の機能'), findsNothing);
    expect(find.text('¥8,800で始める'), findsOneWidget);

    expect(AppStrings.plusBenefitSiriTitle, '音声登録 (β)');
    expect(AppStrings.plusBenefitWidgetTitle, 'ウィジェットでワンタップ記録');
    expect(AppStrings.plusBenefitPhotoTitle, '写真で登録 (β)');
    expect(AppStrings.plusBenefitEatingOutTitle, '外食・コンビニ (β)');
    expect(AppStrings.plusBenefitAiSearchTitle, 'AIで探す (β)');
    expect(AppStrings.plusBenefitCoachTitle, 'パーソナルコーチ (β)');
    expect(AppStrings.plusAiDailyLimit, contains('あわせて1日15回まで'));
    expect(AppStrings.plusAiLimitTitle, 'AI機能は1日15回まで');
    expect(AppStrings.plusMoreFeaturesTitle, 'カロナビ+のその他の機能');
    expect(find.textContaining('精度検証中'), findsNothing);
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

    expect(find.text('¥1,200'), findsOneWidget);
    expect(find.text('¥7,200'), findsOneWidget);
    expect(find.text('月あたり1,200円'), findsOneWidget);
    expect(find.text('¥10,000'), findsOneWidget);
    expect(find.text('月あたり約833円'), findsOneWidget);
    expect(
      find.text('年額¥10,000で自動更新。\nいつでも解約できます。'),
      findsOneWidget,
    );
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

/// 課金画面とシートに出さない言葉。
void _expectNoBannedWording() {
  expect(find.textContaining('有料'), findsNothing);
  expect(find.textContaining('先行アクセス'), findsNothing);
  expect(find.textContaining('先行公開'), findsNothing);
  expect(find.textContaining('β版'), findsNothing);
  expect(find.textContaining('メモ'), findsNothing);
}
