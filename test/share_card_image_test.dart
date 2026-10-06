import 'dart:io';
import 'dart:ui' as ui;

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

  Future<void> expectPng(
    WidgetTester tester, {
    required String name,
    required ShareCardContent content,
  }) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(
      Size(content.format.width + 40, content.format.height + 40),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: content.format.width,
                height: content.format.height,
                child: ShareCardView(content: content),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
      File('${folder.path}/$name.png').writeAsBytesSync(bytes);
    }
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    });
    expect(image!.width, content.format.width * 2);
    expect(image.height, content.format.height * 2);
  }

  testWidgets('meal, streak, and weight cards render pngs', (tester) async {
    await expectPng(
      tester,
      name: 'meal_story',
      content: buildMealShareCard(
        summary: meal,
        day: day,
        format: ShareCardFormat.story,
      ),
    );
    await expectPng(
      tester,
      name: 'meal_square',
      content: buildMealShareCard(
        summary: meal,
        day: day,
        format: ShareCardFormat.square,
      ),
    );
    await expectPng(
      tester,
      name: 'streak_story',
      content: buildStreakShareCard(
        days: 7,
        day: day,
        format: ShareCardFormat.story,
      ),
    );
    await expectPng(
      tester,
      name: 'weight_shown_square',
      content: buildWeightShareCard(
        periodLabel: '1ヶ月',
        weightsKg: const [80, 79.2, 78.4],
        privacy: WeightPrivacy.shown,
        day: day,
        format: ShareCardFormat.square,
      ),
    );
    await expectPng(
      tester,
      name: 'weight_blurred_story',
      content: buildWeightShareCard(
        periodLabel: '1ヶ月',
        weightsKg: const [80, 79.2, 78.4],
        privacy: WeightPrivacy.blurred,
        day: day,
        format: ShareCardFormat.story,
      ),
    );
    await expectPng(
      tester,
      name: 'weight_hidden_square',
      content: buildWeightShareCard(
        periodLabel: '1ヶ月',
        weightsKg: const [80, 79.2, 78.4],
        privacy: WeightPrivacy.hidden,
        day: day,
        format: ShareCardFormat.square,
      ),
    );
    expect(shareDownloadUrl, startsWith('https://'));
  });
}
