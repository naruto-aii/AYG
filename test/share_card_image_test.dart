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
    expect(find.text('1,820'), findsOneWidget);
    expect(find.text('/ 2,000 kcal'), findsOneWidget);
    expect(find.text('超過'), findsNothing);
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
      File('${folder.path}/meal_final3.png').writeAsBytesSync(bytes);
    }
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    });
    expect(image!.width, shareCardSize * 2);
    expect(image.height, shareCardSize * 2);
  });

  testWidgets('progress samples stay inside the ring', (tester) async {
    final samples = <String, DailySummary>{
      'meal_0': _summary(intake: 0),
      'meal_50': _summary(intake: 1000),
      'meal_100': _summary(intake: 2000, remaining: 0),
      'meal_120': _summary(
        intake: 2400,
        remaining: -400,
        overage: true,
        overageKcal: 400,
      ),
      'meal_digits': _summary(
        intake: 12800,
        target: 10000,
        remaining: -2800,
        overage: true,
        overageKcal: 2800,
      ),
    };
    final directory = Platform.environment['SHARE_CARD_OUT'];
    for (final sample in samples.entries) {
      final content = buildMealShareCard(summary: sample.value, day: day);
      final key = GlobalKey();
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
      expect(find.text(content.intakeLabel), findsOneWidget);
      expect(find.text('/ ${content.targetLabel} kcal'), findsOneWidget);
      expect(
        find.text('超過'),
        content.isOverage ? findsOneWidget : findsNothing,
      );
      final bytes = await tester.runAsync(
        () => pngBytesFromBoundary(key, pixelRatio: 2),
      );
      expect(bytes, isNotNull);
      if (directory != null && directory.isNotEmpty) {
        Directory(directory).createSync(recursive: true);
        File('$directory/${sample.key}.png').writeAsBytesSync(bytes!);
      }
    }
  });
}

DailySummary _summary({
  required double intake,
  double target = 2000,
  double remaining = 2000,
  bool overage = false,
  double overageKcal = 0,
}) {
  return DailySummary(
    targetKcal: target,
    remainingKcal: remaining,
    targetProteinG: 80,
    targetFatG: 50,
    targetCarbG: 200,
    intakeKcal: intake,
    exerciseBurnKcal: 0,
    intakeProteinG: 0,
    intakeFatG: 0,
    intakeCarbG: 0,
    isCalorieOverage: overage,
    calorieOverageKcal: overageKcal,
  );
}
