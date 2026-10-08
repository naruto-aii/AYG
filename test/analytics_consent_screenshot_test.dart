import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/screens/settings/analytics_settings_screen.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadZenMaru() async {
  final loader = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadZenMaru);

  testWidgets('renders the usage-record setting and external-send screens', (tester) async {
    final directory = Directory('/tmp/analytics_ui');
    directory.createSync(recursive: true);
    await _capture(
      tester,
      const AnalyticsSettingsScreen(),
      File('${directory.path}/analytics_settings.png'),
      find.text('利用状況の記録'),
    );
    await _capture(
      tester,
      const ExternalTransmissionScreen(),
      File('${directory.path}/external_transmission.png'),
      find.text('外部送信について'),
    );
  });
}

Future<void> _capture(
  WidgetTester tester,
  Widget screen,
  File file,
  Finder visible,
) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(visible, findsWidgets);
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
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
