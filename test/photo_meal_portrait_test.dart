import 'dart:typed_data';

import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/widgets/design/design_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// iPhone の縦写真と同じく、画素は横長のまま保存し、EXIF の向きで縦に見せる JPEG。
/// 保存上の左半分が赤、右半分が青。
Uint8List _sidewaysJpeg({required int orientation, int width = 4032, int height = 3024}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (x < width ~/ 2) {
        image.setPixelRgb(x, y, 220, 30, 30);
      } else {
        image.setPixelRgb(x, y, 30, 30, 220);
      }
    }
  }
  image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

bool _isRed(img.Pixel p) => p.r > 150 && p.b < 100;
bool _isBlue(img.Pixel p) => p.b > 150 && p.r < 100;

void main() {
  test('EXIF で縦にする写真（向き6）は、縦のまま全体を送る', () {
    final out = img.decodeJpg(compressMealPhoto(_sidewaysJpeg(orientation: 6)))!;
    expect([out.width, out.height], [768, 1024]);
    // 向き6は時計回り90度。保存上の左（赤）が上に来る。
    expect(_isRed(out.getPixel(384, 40)), isTrue);
    expect(_isBlue(out.getPixel(384, 984)), isTrue);
    // 向きは画素に焼き込み済み。送る JPEG に回転の指示は残さない。
    final tag = out.exif.imageIfd.orientation;
    expect(tag == null || tag == 1, isTrue, reason: 'orientation=$tag');
  });

  test('向き8の写真も縦のまま。上下も切れない', () {
    final out = img.decodeJpg(compressMealPhoto(_sidewaysJpeg(orientation: 8)))!;
    expect([out.width, out.height], [768, 1024]);
    expect(_isBlue(out.getPixel(384, 2)), isTrue);
    expect(_isRed(out.getPixel(384, 1021)), isTrue);
  });

  test('すでに縦の画素の写真は、縦横比を保って長辺1024にする', () {
    final image = img.Image(width: 1536, height: 2048);
    img.fill(image, color: img.ColorRgb8(10, 200, 10));
    final out = img.decodeJpg(
      compressMealPhoto(Uint8List.fromList(img.encodeJpg(image))),
    )!;
    expect([out.width, out.height], [768, 1024]);
  });

  test('1024以下の縦写真はそのままの大きさ（切り取りも拡大もしない）', () {
    final image = img.Image(width: 720, height: 960);
    final out = img.decodeJpg(
      compressMealPhoto(Uint8List.fromList(img.encodeJpg(image))),
    )!;
    expect([out.width, out.height], [720, 960]);
  });

  testWidgets('プレビューは送る写真の全体を、縦横比を保って見せる', (tester) async {
    final jpeg = compressMealPhoto(_sidewaysJpeg(orientation: 6, width: 800, height: 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 358, child: MealPhotoPreview(jpeg: jpeg)),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    final box = tester.getSize(find.byKey(const ValueKey('photo_meal_preview')));
    expect(box.width, 358);
    expect(box.height, 360, reason: '縦写真は上限の高さまで。上下を切らない');
    expect(mealPhotoAspectRatio(jpeg), closeTo(0.75, 0.001));

    final wide = compressMealPhoto(
      Uint8List.fromList(img.encodeJpg(img.Image(width: 800, height: 600))),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 358, child: MealPhotoPreview(jpeg: wide)),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('photo_meal_preview'))).height,
      closeTo(358 * 3 / 4, 0.01),
    );
  });

  testWidgets('自炊コーチの入口は押せる部品の形で、説明文は付けない', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CookCoachEntryButton(
            key: const Key('cook_coach_entry'),
            onPressed: () => opened += 1,
          ),
        ),
      ),
    );
    expect(find.text('自炊コーチ (β)'), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.skillet_rounded), findsOneWidget);
    expect(find.textContaining('押す'), findsNothing);
    expect(find.textContaining('タップ'), findsNothing);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('cook_coach_entry')),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, isNot(Colors.transparent));
    await tester.tap(find.byKey(const Key('cook_coach_entry')));
    expect(opened, 1);
    expect(tester.getSemantics(find.byKey(const Key('cook_coach_entry'))),
        matchesSemantics(isButton: true, label: '自炊コーチ (β)', hasTapAction: true));
  });
}
