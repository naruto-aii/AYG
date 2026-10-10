import 'package:ayg/widgets/layout/design_scale.dart';
import 'package:ayg/widgets/layout/tablet_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iPhone sizes keep the width-only scale', () {
    expect(
      designScreenScale(maxWidth: 390, maxHeight: 844, shortestSide: 390),
      1,
    );
    expect(
      designScreenScale(maxWidth: 430, maxHeight: 932, shortestSide: 430),
      closeTo(430 / 390, 0.0001),
    );
    // 横向き iPhone は短い辺が 600 未満なので、倍率は下げない。
    expect(
      designScreenScale(maxWidth: 932, maxHeight: 430, shortestSide: 430),
      1.5,
    );
  });

  test('tall iPad caps the login canvas and short iPad shrinks the screen', () {
    expect(designCanvasScale(maxWidth: 1032, maxHeight: 1376), 1.5);
    final uncapped = 1376 / 844;
    expect(uncapped, greaterThan(1.5));

    expect(
      designScreenScale(maxWidth: 1194, maxHeight: 834, shortestSide: 834),
      closeTo(834 / 640, 0.0001),
    );
    expect(
      designScreenScale(maxWidth: 1032, maxHeight: 1376, shortestSide: 1032),
      1.5,
    );
    // Slide Over の狭い幅はスマホと同じ倍率。
    expect(
      designScreenScale(maxWidth: 320, maxHeight: 1194, shortestSide: 320),
      closeTo(320 / 390, 0.0001),
    );
  });

  test('slide over is compact, iPhone sizes are not', () {
    expect(isCompactTabletWindow(const Size(320, 1194)), isTrue);
    expect(isCompactTabletWindow(const Size(320, 834)), isTrue);
    expect(isCompactTabletWindow(const Size(375, 834)), isTrue);
    expect(isCompactTabletWindow(const Size(320, 568)), isFalse);
    expect(isCompactTabletWindow(const Size(375, 812)), isFalse);
    expect(isCompactTabletWindow(const Size(390, 844)), isFalse);
    expect(isCompactTabletWindow(const Size(800, 600)), isFalse);
  });
}
