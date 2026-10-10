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
    'the app still targets iPhone and iPad, and the build number is unchanged',
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
        contains('version: 1.0.0+10'),
      );
    },
  );

  test(
    'iPad system sheets get a window, a popover anchor, and an Apple sign-in anchor',
    () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(source, contains('IpadSystemPresentation.install()'));
      expect(source, contains('presentationContextProvider'));
      expect(source, contains('popover.sourceView'));
      expect(source, contains('foregroundKeyWindow'));
      expect(source, contains('UIImagePickerController'));
      expect(source, contains('makeForegroundWindowKeyIfNeeded'));
    },
  );
}
