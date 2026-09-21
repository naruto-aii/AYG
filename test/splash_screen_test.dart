import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/screens/splash/splash_screen.dart';

/// スプラッシュ演出を時刻ごとに検証する。
/// 390x844 で動かすと設計座標 = 論理座標になるので、Figma の実測値と直接比較できる。
void main() {
  const design = Size(390, 844);

  Finder dot() => find.byKey(const ValueKey('splash-dot'));
  Finder char(int i) => find.byKey(ValueKey('splash-char-$i'));

  double opacityOf(WidgetTester tester, int i) =>
      tester.widget<Opacity>(char(i)).opacity;

  Future<void> pumpSplash(
    WidgetTester tester, {
    Size size = design,
    VoidCallback? onCompleted,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onCompleted: onCompleted ?? () {})),
    );
  }

  void expectRect(Rect actual, Rect expected, String label) {
    for (final v in [
      [actual.left, expected.left, 'left'],
      [actual.top, expected.top, 'top'],
      [actual.width, expected.width, 'width'],
      [actual.height, expected.height, 'height'],
    ]) {
      expect(
        v[0] as double,
        moreOrLessEquals(v[1] as double, epsilon: 1.0),
        reason: '$label の ${v[2]}',
      );
    }
  }

  testWidgets('開始時は点が画面外にあり、文字も出ていない', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expectRect(
      tester.getRect(dot()),
      const Rect.fromLTWH(249.95, -50.75, 21.5, 21.5),
      '開始',
    );
    for (var i = 0; i < 4; i++) {
      expect(opacityOf(tester, i), 0, reason: '${i + 1}文字目はまだ見えない');
    }
  });

  testWidgets('文字は1文字ずつ順に現れる', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 680));
    expect(opacityOf(tester, 0), 1);
    expect(opacityOf(tester, 1), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester, 1), 1);
    expect(opacityOf(tester, 2), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester, 2), 1);
    expect(opacityOf(tester, 3), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester, 3), 1);
  });

  testWidgets('点は落下し、つぶれ、跳ねる（Figma の実測値どおり）', (tester) async {
    await pumpSplash(tester);

    await tester.pump(const Duration(milliseconds: 1920));
    expectRect(
      tester.getRect(dot()),
      const Rect.fromLTWH(251.55, 373.3, 18.3, 28),
      '落下',
    );

    await tester.pump(const Duration(milliseconds: 100));
    expectRect(
      tester.getRect(dot()),
      const Rect.fromLTWH(245.1, 387.95, 31.2, 13.3),
      '着地',
    );

    await tester.pump(const Duration(milliseconds: 201));
    expectRect(
      tester.getRect(dot()),
      const Rect.fromLTWH(257.95, 327.85, 21.5, 21.5),
      'バウンド',
    );
  });

  // 画面サイズや縦横比が変わっても、最後にオレンジが画面全体を覆いきること。
  for (final size in const [
    Size(390, 844), // iPhone 13
    Size(440, 956), // iPhone 16 Pro Max
    Size(320, 568), // iPhone SE
    Size(1032, 1376), // iPad Pro 13
    Size(1280, 800), // 横長
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} で画面を埋めきる', (
      tester,
    ) async {
      await pumpSplash(tester, size: size);
      await tester.pump(const Duration(milliseconds: 2622));

      final r = tester.getRect(dot());
      expect(r.left, lessThanOrEqualTo(0), reason: '左端まで届いていない');
      expect(r.top, lessThanOrEqualTo(0), reason: '上端まで届いていない');
      expect(r.right, greaterThanOrEqualTo(size.width), reason: '右端まで届いていない');
      expect(r.bottom, greaterThanOrEqualTo(size.height), reason: '下端まで届いていない');

      // 円なので四隅が覆われているかまで確認する
      final center = r.center;
      final radius = r.width / 2;
      for (final corner in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        expect(
          (corner - center).distance,
          lessThanOrEqualTo(radius),
          reason: '角 $corner が円の外',
        );
      }
    });
  }

  testWidgets('2.92秒で終了を通知する', (tester) async {
    var completed = false;
    await pumpSplash(tester, onCompleted: () => completed = true);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(completed, isFalse, reason: '2.9秒ではまだ終わらない');

    await tester.pump(const Duration(milliseconds: 50));
    expect(completed, isTrue, reason: '2.92秒で終了');
  });
}
