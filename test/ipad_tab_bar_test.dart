import 'package:ayg/widgets/design/design_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBar(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: DesignTabBar(
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );
  }

  Rect painted(WidgetTester tester, String label) {
    final box = tester.renderObject<RenderBox>(find.bySemanticsLabel(label));
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
    return Rect.fromPoints(topLeft, bottomRight);
  }

  testWidgets('iPhone tab bar stays on the Figma coordinates', (tester) async {
    await pumpBar(tester, const Size(390, 844));
    expect(painted(tester, '食事').left, lessThan(8));
    expect(painted(tester, '設定').right, lessThanOrEqualTo(391));
  });

  testWidgets('slide over and narrow split keep every tab on screen', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 1194),
      Size(320, 834),
      Size(375, 834),
    ]) {
      await pumpBar(tester, size);
      expect(
        painted(tester, '食事').left,
        greaterThanOrEqualTo(-1),
        reason: '$size',
      );
      expect(
        painted(tester, '設定').right,
        lessThanOrEqualTo(size.width + 1),
        reason: '$size',
      );
    }
  });

  testWidgets('iPad 11 portrait centers the tab bar with the page', (
    tester,
  ) async {
    const size = Size(834, 1194);
    await pumpBar(tester, size);
    const scale = 1.5;
    final inset = (size.width - 390 * scale) / 2;
    expect(painted(tester, '食事').left, closeTo(inset, 16));
    expect(painted(tester, '設定').right, lessThanOrEqualTo(size.width + 1));
  });
}
