import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final info = File('ios/Runner/Info.plist').readAsStringSync();
  final entitlements = File(
    'ios/Runner/Runner.entitlements',
  ).readAsStringSync();
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  test(
    'privacy manifest covers the required-reason APIs and collected data',
    () {
      expect(privacy, contains('<key>NSPrivacyTracking</key>'));
      expect(privacy, contains('<false/>'));
      expect(
        privacy,
        isNot(contains('<key>NSPrivacyTracking</key>\n\t<true/>')),
      );
      expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
      expect(privacy, contains('CA92.1'));
      expect(privacy, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
      expect(privacy, contains('C617.1'));
      expect(privacy, contains('0A2A.1'));
      expect(privacy, contains('NSPrivacyAccessedAPICategorySystemBootTime'));
      expect(privacy, contains('35F9.1'));
      expect(privacy, contains('NSPrivacyAccessedAPICategoryDiskSpace'));
      expect(privacy, contains('7D9E.1'));
      expect(
        privacy,
        isNot(contains('NSPrivacyAccessedAPICategoryActiveKeyboards')),
      );
      expect(privacy, contains('NSPrivacyCollectedDataTypeEmailAddress'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeName'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeUserID'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeHealth'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeFitness'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeProductInteraction'));
      expect(privacy, contains('NSPrivacyCollectedDataTypePurchaseHistory'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeOtherUserContent'));
      expect(privacy, contains('NSPrivacyCollectedDataTypeOtherDataTypes'));
      expect(privacy, contains('NSPrivacyCollectedDataTypePurposeAnalytics'));
      expect(
        privacy,
        contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
      );
      expect(
        privacy,
        isNot(
          contains('NSPrivacyCollectedDataTypePurposeProductPersonalization'),
        ),
      );
    },
  );

  test('privacy manifest Name entry matches the App Privacy draft', () {
    final draft = File(
      'docs/app-review/app-privacy-draft.md',
    ).readAsStringSync();
    final nameSection = _markdownSection(draft, '### Contact Info > Name');
    expect(_tableAnswer(nameSection, '収集する'), 'はい');
    expect(nameSection, contains('NSPrivacyCollectedDataTypeName'));

    final entry = _collectedDataType(privacy, 'NSPrivacyCollectedDataTypeName');
    expect(entry.linked, _tableAnswer(nameSection, 'ユーザーに紐づく') == 'はい');
    expect(entry.tracking, _tableAnswer(nameSection, 'トラッキング') == 'はい');
    expect(entry.purposes, _purposesFromDraft(_tableAnswer(nameSection, '目的')));
  });

  test('privacy manifest is a Runner resource and the app is iPhone-only', () {
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(
      project,
      contains(
        'A91B2C3D4E5F60718293A4B6 /* PrivacyInfo.xcprivacy in Resources */',
      ),
    );
    expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2"')));
    expect('TARGETED_DEVICE_FAMILY = 1;'.allMatches(project).length, 6);
    expect(info, contains('NSHealthShareUsageDescription'));
    expect(
      info,
      contains(
        '生年月日、性別、身長、体重、アクティブエネルギー、ワークアウトを読み取り、カロリー目標の計算と記録の表示に使います。広告やマーケティングには使いません。',
      ),
    );
    expect(info, isNot(contains('NSHealthUpdateUsageDescription')));
    expect(info, isNot(contains('UISupportedInterfaceOrientations~ipad')));
    expect(info, contains('UIInterfaceOrientationPortrait'));
  });

  test('Android manifest does not declare Health Connect reads', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('android.permission.health.READ_')));
    expect(manifest, isNot(contains('android.permission.health.WRITE_')));
  });

  test('HealthKit entitlement is read access without clinical records', () {
    expect(entitlements, contains('com.apple.developer.healthkit'));
    expect(entitlements, contains('com.apple.developer.healthkit.access'));
    expect(entitlements, contains('<array/>'));
    expect(entitlements, isNot(contains('health-records')));
    expect(
      entitlements,
      isNot(contains('com.apple.developer.healthkit.background-delivery')),
    );

    final appSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in appSources) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('writeHealthData')), reason: file.path);
      expect(
        source,
        isNot(contains('HealthDataAccess.WRITE')),
        reason: file.path,
      );
    }
  });
}

String _markdownSection(String markdown, String heading) {
  final start = markdown.indexOf(heading);
  expect(start, greaterThanOrEqualTo(0), reason: heading);
  final next = markdown.indexOf('\n### ', start + heading.length);
  return markdown.substring(start, next == -1 ? markdown.length : next);
}

String _tableAnswer(String section, String label) {
  final row = RegExp('\\|\\s*$label\\s*\\|\\s*([^|]+)\\|').firstMatch(section);
  expect(row, isNotNull, reason: label);
  return row!.group(1)!.trim();
}

final class _CollectedDataType {
  _CollectedDataType({
    required this.linked,
    required this.tracking,
    required this.purposes,
  });

  final bool linked;
  final bool tracking;
  final List<String> purposes;
}

_CollectedDataType _collectedDataType(String privacy, String type) {
  final blocks = RegExp(
    r'<dict>\s*<key>NSPrivacyCollectedDataType</key>\s*<string>([^<]+)</string>(.*?)</dict>',
    dotAll: true,
  ).allMatches(privacy);
  final match = blocks.cast<RegExpMatch?>().firstWhere(
    (candidate) => candidate!.group(1) == type,
    orElse: () => null,
  );
  expect(match, isNotNull, reason: '$type is missing');
  final body = match!.group(2)!;

  bool flag(String key) {
    final flagMatch = RegExp(
      '<key>$key</key>\\s*<(true|false)/>',
    ).firstMatch(body);
    expect(flagMatch, isNotNull, reason: key);
    return flagMatch!.group(1) == 'true';
  }

  final purposes = RegExp(
    r'<key>NSPrivacyCollectedDataTypePurposes</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(body);
  expect(purposes, isNotNull, reason: type);
  return _CollectedDataType(
    linked: flag('NSPrivacyCollectedDataTypeLinked'),
    tracking: flag('NSPrivacyCollectedDataTypeTracking'),
    purposes: RegExp(
      r'<string>([^<]+)</string>',
    ).allMatches(purposes!.group(1)!).map((item) => item.group(1)!).toList(),
  );
}

List<String> _purposesFromDraft(String cell) {
  const known = <(String, String)>[
    ('App Functionality', 'NSPrivacyCollectedDataTypePurposeAppFunctionality'),
    ('Analytics', 'NSPrivacyCollectedDataTypePurposeAnalytics'),
    (
      'Product Personalization',
      'NSPrivacyCollectedDataTypePurposeProductPersonalization',
    ),
    (
      'Third-Party Advertising',
      'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
    ),
    (
      "Developer's Advertising",
      'NSPrivacyCollectedDataTypePurposeDevelopersAdvertising',
    ),
  ];
  final hits = <MapEntry<int, String>>[];
  for (final (label, key) in known) {
    final index = cell.indexOf(label);
    if (index >= 0) {
      hits.add(MapEntry(index, key));
    }
  }
  expect(hits, isNotEmpty, reason: 'unmapped purpose: $cell');
  hits.sort((a, b) => a.key.compareTo(b.key));
  return hits.map((hit) => hit.value).toList();
}
