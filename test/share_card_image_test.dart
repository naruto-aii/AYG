import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/daily_summary.dart';
import 'package:ayg/services/share_card_content.dart';
import 'package:ayg/services/share_links.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/share/share_card_view.dart';
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

  final day = DateTime(2026, 10, 6);
  final meal = DailySummary(
    targetKcal: 2000,
    remainingKcal: 180,
    targetProteinG: 80,
    targetFatG: 50,
    targetCarbG: 200,
    intakeKcal: 1820,
    intakeProteinG: 25,
    intakeFatG: 10,
    intakeCarbG: 30,
    exerciseBurnKcal: 320,
  );

  testWidgets('today meal card renders a square png', (tester) async {
    final content = buildMealShareCard(summary: meal, day: day);
    expect(content.figure, '1,820 / 2,000');
    expect(content.message, isNot(contains('320')));
    expect(content.message, isNot(contains('たんぱく質')));
    expect(content.message, contains(AppStrings.loginTagline));
    expect(content.message, contains(shareDownloadUrl));

    final key = GlobalKey();
    await tester.binding.setSurfaceSize(
      const Size(shareCardSize + 40, shareCardSize + 40),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: shareCardSize,
                height: shareCardSize,
                child: ShareCardView(content: content),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日の摂取カロリー'), findsOneWidget);
    expect(find.text('1,820 / 2,000'), findsOneWidget);
    expect(find.text('たんぱく質'), findsNothing);
    expect(find.textContaining('目標まで'), findsNothing);
    expect(find.text(AppStrings.loginTagline), findsOneWidget);

    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 2),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(500));
    expect(bytes[0], 0x89);
    expect(String.fromCharCodes(bytes.sublist(1, 4)), 'PNG');

    final directory = Platform.environment['SHARE_CARD_OUT'];
    if (directory != null && directory.isNotEmpty) {
      final folder = Directory(directory);
      folder.createSync(recursive: true);
      File('${folder.path}/meal_final2.png').writeAsBytesSync(bytes);
    }
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    });
    expect(image!.width, shareCardSize * 2);
    expect(image.height, shareCardSize * 2);
  });
}
