import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iPad 対応を残したまま、審査で見る向きとシステムの表示元が外れていないこと。
void main() {
  test('Info.plist keeps iPad multitasking and every orientation', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>UISupportedInterfaceOrientations~ipad</key>'));
    expect(plist, contains('<string>UIInterfaceOrientationPortrait</string>'));
    expect(
      plist,
      contains('<string>UIInterfaceOrientationPortraitUpsideDown</string>'),
    );
    expect(
      plist,
      contains('<string>UIInterfaceOrientationLandscapeLeft</string>'),
    );
    expect(
      plist,
      contains('<string>UIInterfaceOrientationLandscapeRight</string>'),
    );
    expect(plist, contains('<key>UIRequiresFullScreen</key>'));
    expect(plist, contains('<false/>'));
    expect(
      plist,
      isNot(contains('<key>UIRequiresFullScreen</key>\n\t<true/>')),
    );
  });

  test(
    'the app still targets iPhone and iPad, and the build number is 1.0.0+12',
    () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final families = RegExp(
        r'TARGETED_DEVICE_FAMILY = ([^;]+);',
      ).allMatches(project).map((match) => match.group(1)).toList();
      expect(families, isNotEmpty);
      expect(families, everyElement('"1,2"'));
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('version: 1.0.0+12'),
      );
    },
  );

  test(
    'Apple sign-in gets a scene window and other login paths are not swizzled',
    () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(source, contains('IpadSystemPresentation.install()'));
      expect(source, contains('@objc dynamic func ayg_performRequests'));
      expect(source, contains('presentationContextProvider'));
      expect(source, contains('UIWindow(windowScene: scene)'));
      expect(source, isNot(contains('ASPresentationAnchor()')));
      expect(source, isNot(contains('UIWindow()')));
      expect(source, isNot(contains('func ayg_keyWindow')));
      expect(source, isNot(contains('func ayg_present')));
      expect(source, isNot(contains('NSSelectorFromString("keyWindow")')));
      expect(source, isNot(contains('makeForegroundWindowKeyIfNeeded')));
      // 共有シートは差し替えではなく、出す直前に自分で起点を置く。
      expect(source, contains('popover.sourceView'));
    },
  );
}
