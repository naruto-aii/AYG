import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 初画面に ¥980 / ¥4,900 / ¥8,800 と、その直下の3日間無料の注記が出ること。
///
/// `ipad11_landscape_design640` は PR #109 の倍率をこのブランチの DesignScreen
/// で再現する。短辺 600pt 以上かつ設計高さ 640 未満の iPad は scale を
/// 高さ/640 まで下げるので、iPad 11 横 (1194×834) の設計高さは 640 になる。
/// 幅スケールが 1.5 で頭打ちのこのブランチでは、高さ 960 が同じ設計高さになる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  const cases = <_Surface>[
    _Surface(
      'ipad11_landscape',
      Size(1194, 834),
      top: 24,
      bottom: 20,
      pinPrices: true,
    ),
    _Surface(
      'ipad11_landscape_design640',
      Size(1194, 960),
      top: 24,
      bottom: 20,
      pinPrices: true,
    ),
    _Surface(
      'ipad11_portrait',
      Size(834, 1194),
      top: 24,
      bottom: 20,
      pinPrices: false,
    ),
    _Surface(
      'ipad13_landscape',
      Size(1376, 1032),
      top: 24,
      bottom: 20,
      pinPrices: true,
    ),
    _Surface(
      'ipad13_portrait',
      Size(1032, 1376),
      top: 24,
      bottom: 20,
      pinPrices: false,
    ),
    _Surface('iphone_se', Size(375, 667), top: 20, bottom: 0, pinPrices: true),
    _Surface(
      'iphone15',
      Size(393, 852),
      top: 59,
      bottom: 34,
      pinPrices: false,
      keepBenefitOrder: true,
    ),
    _Surface(
      'iphone16_pro',
      Size(402, 874),
      top: 59,
      bottom: 34,
      pinPrices: false,
      keepBenefitOrder: true,
    ),
    _Surface(
      'iphone_67_no_safe_area',
      Size(430, 932),
      pinPrices: false,
      keepBenefitOrder: true,
    ),
  ];

  for (final surface in cases) {
    testWidgets('${surface.name} shows prices and the trial note first', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(surface.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        top: surface.top,
        bottom: surface.bottom,
      );
      tester.view.viewPadding = FakeViewPadding(
        top: surface.top,
        bottom: surface.bottom,
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: key,
            child: CalonaviPlusEntryScreen(repository: _TrialPrices()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      _expectPricesAndNote(tester, surface);

      final directory = Directory(
        '/opt/cursor/artifacts/screenshots/paywall-after',
      )..createSync(recursive: true);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      );
      final bytes = await tester.runAsync(() async {
        final data = await image!.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('${directory.path}/${surface.name}.png').writeAsBytesSync(bytes!);
      image!.dispose();

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/paywall_fold/${surface.name}.png'),
      );
    });
  }
}

void _expectPricesAndNote(WidgetTester tester, _Surface surface) {
  final button = tester.getRect(find.byKey(const Key('plus-purchase')));
  final plans = tester.getRect(find.byKey(const Key('plus-plans')));
  final note = tester.getRect(find.byKey(const Key('plus-cta-note')));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

  expect(find.text('3日間無料ではじめる'), findsOneWidget);
  expect(find.text('3日間無料。期間終了後は年額¥8,800で自動更新。\nいつでも解約できます。'), findsOneWidget);

  expect(plans.top, greaterThanOrEqualTo(0), reason: surface.name);
  expect(plans.left, greaterThanOrEqualTo(0), reason: surface.name);
  expect(
    plans.right,
    lessThanOrEqualTo(screen.width + 0.5),
    reason: surface.name,
  );
  expect(plans.bottom, lessThanOrEqualTo(button.top), reason: surface.name);

  for (final price in ['¥980', '¥4,900', '¥8,800']) {
    final rect = tester.getRect(find.text(price));
    expect(
      rect.height,
      greaterThanOrEqualTo(18),
      reason: '$price ${surface.name}',
    );
    expect(rect.top, greaterThanOrEqualTo(plans.top), reason: price);
    expect(rect.bottom, lessThanOrEqualTo(plans.bottom + 1), reason: price);
    expect(rect.bottom, lessThanOrEqualTo(note.top), reason: price);
    expect(rect.bottom, lessThanOrEqualTo(button.top), reason: price);
  }

  expect(
    note.top,
    greaterThanOrEqualTo(plans.bottom - 1),
    reason: surface.name,
  );
  expect(note.bottom, lessThanOrEqualTo(button.top), reason: surface.name);
  expect(note.left, greaterThanOrEqualTo(0), reason: surface.name);
  expect(
    note.right,
    lessThanOrEqualTo(screen.width + 0.5),
    reason: surface.name,
  );

  final plansInScroll =
      Scrollable.maybeOf(tester.element(find.byKey(const Key('plus-plans')))) !=
      null;
  expect(plansInScroll, isNot(surface.pinPrices), reason: surface.name);

  for (final label in ['購入を復元', '利用規約', 'プライバシーポリシー']) {
    expect(find.text(label), findsOneWidget, reason: surface.name);
  }
  if (surface.pinPrices) {
    for (final label in ['購入を復元', '利用規約', 'プライバシーポリシー']) {
      final rect = tester.getRect(find.text(label));
      expect(
        rect.top,
        greaterThanOrEqualTo(0),
        reason: '${surface.name} $label',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(button.top + 0.5),
        reason: '${surface.name} $label',
      );
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(
        rect.right,
        lessThanOrEqualTo(screen.width + 0.5),
        reason: '${surface.name} $label',
      );
    }
  }

  _expectBadgeClearance(tester, surface);

  if (surface.keepBenefitOrder) {
    for (final title in [
      AppStrings.plusBenefitPhotoTitle,
      AppStrings.plusBenefitAiSearchTitle,
      AppStrings.plusBenefitCoachTitle,
      AppStrings.plusBenefitWidgetTitle,
    ]) {
      final rect = tester.getRect(find.text(title));
      expect(rect.top, greaterThanOrEqualTo(0), reason: title);
      expect(rect.bottom, lessThan(plans.top), reason: title);
      expect(rect.bottom, lessThan(button.top), reason: title);
    }
  }
}

/// 見えている特典の行が、価格バッジの 8pt 以内に入らないこと。
void _expectBadgeClearance(WidgetTester tester, _Surface surface) {
  final badgeTops = [
    tester.getRect(find.text('一番お得')).top,
    tester.getRect(find.text('1か月分お得')).top,
  ];
  final badgeTop = badgeTops.reduce((a, b) => a < b ? a : b);
  final scroll = tester.getRect(find.byKey(const Key('plus-paywall-scroll')));
  const lines = [
    AppStrings.plusHeroSubtitle,
    AppStrings.plusBenefitPhotoTitle,
    AppStrings.plusHeroPhotoBody,
    AppStrings.plusBenefitAiSearchTitle,
    AppStrings.plusHeroAiSearchBody,
    AppStrings.plusBenefitCoachTitle,
    AppStrings.plusHeroCoachBody,
    AppStrings.plusBenefitWidgetTitle,
    AppStrings.plusHeroWidgetBody,
    AppStrings.plusMoreFeaturesLink,
  ];
  for (final line in lines) {
    final finder = find.text(line);
    if (finder.evaluate().isEmpty) {
      continue;
    }
    final rect = tester.getRect(finder);
    final visible = rect.intersect(scroll);
    if (visible.height < 1 || visible.width < 1) {
      continue;
    }
    expect(
      badgeTop - visible.bottom,
      greaterThanOrEqualTo(8),
      reason: '${surface.name} $line',
    );
  }
}

class _Surface {
  const _Surface(
    this.name,
    this.size, {
    this.top = 0,
    this.bottom = 0,
    required this.pinPrices,
    this.keepBenefitOrder = false,
  });

  final String name;
  final Size size;
  final double top;
  final double bottom;
  final bool pinPrices;
  final bool keepBenefitOrder;
}

class _TrialPrices extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    SubscriptionProductOffer offer(
      String id,
      PlusBillingPeriod period,
      String price,
    ) {
      return SubscriptionProductOffer(
        productId: id,
        period: period,
        localizedPrice: price,
        freeTrialDays: 3,
      );
    }

    return SubscriptionOfferings(
      monthly: offer(
        SubscriptionCatalog.monthlyProductId,
        PlusBillingPeriod.month,
        '¥980',
      ),
      halfYear: offer(
        SubscriptionCatalog.halfYearProductId,
        PlusBillingPeriod.halfYear,
        '¥4,900',
      ),
      yearly: offer(
        SubscriptionCatalog.yearlyProductId,
        PlusBillingPeriod.year,
        '¥8,800',
      ),
      loadFailed: false,
    );
  }
}

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    zen.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await zen.load();
}
