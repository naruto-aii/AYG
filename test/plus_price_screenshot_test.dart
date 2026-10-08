import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final file = File(
    '${configUri.resolveUri(root).toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('paywall plans show the new tax-included prices', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);

    await _capture(
      tester,
      UnavailableSubscriptionRepository(),
      File('${directory.path}/paywall_top.png'),
      scrollToPlans: false,
    );
    expect(find.text('¥8,800で始める'), findsOneWidget);

    await _capture(
      tester,
      UnavailableSubscriptionRepository(),
      File('${directory.path}/paywall_plans_fallback.png'),
      scrollToPlans: true,
    );
    expect(find.text('¥980 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥4,900 ・ 月あたり約817円'), findsOneWidget);
    expect(find.text('¥8,800 ・ 月あたり約733円'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(find.text('お得'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);

    await _capture(
      tester,
      _StorePrices(),
      File('${directory.path}/paywall_plans_store.png'),
      scrollToPlans: true,
    );
    expect(find.text('¥8,800で始める'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: key,
          child: const LegalDocumentScreen(document: LegalDocument.tokushoho),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('月額980円'), findsOneWidget);
    expect(find.textContaining('半年4,900円'), findsOneWidget);
    expect(find.textContaining('年額8,800円'), findsOneWidget);
    expect(find.textContaining('約817円'), findsOneWidget);
    expect(find.textContaining('約733円'), findsOneWidget);
    expect(find.textContaining('1か月分お得'), findsOneWidget);
    expect(find.textContaining('約25%お得'), findsOneWidget);
    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 2),
    );
    File('${directory.path}/tokushoho_price.png').writeAsBytesSync(bytes!);
  });
}

Future<void> _capture(
  WidgetTester tester,
  UnavailableSubscriptionRepository repository,
  File file, {
  required bool scrollToPlans,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: key,
        child: CalonaviPlusEntryScreen(repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (scrollToPlans) {
    await tester.scrollUntilVisible(find.text('プランを選ぶ'), 400);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('年額'));
    await tester.pumpAndSettle();
  }
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 2),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, greaterThan(100));
}

class _StorePrices extends UnavailableSubscriptionRepository {
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
