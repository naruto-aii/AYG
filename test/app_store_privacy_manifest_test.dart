import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;
  late String worksheet;
  late String widgetManifest;
  late String pubspec;

  setUpAll(() {
    manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    worksheet = File('docs/app-store-privacy.md').readAsStringSync();
    widgetManifest = File(
      'ios/LockScreenMealWidget/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    pubspec = File('pubspec.yaml').readAsStringSync();
  });

  test('declares the data the app now stores, for the app and analytics', () {
    const collected = [
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeHealth',
      'NSPrivacyCollectedDataTypeFitness',
      'NSPrivacyCollectedDataTypeSensitiveInfo',
      'NSPrivacyCollectedDataTypePurchaseHistory',
      'NSPrivacyCollectedDataTypeSearchHistory',
      'NSPrivacyCollectedDataTypeProductInteraction',
      'NSPrivacyCollectedDataTypeOtherUserContent',
    ];
    for (final type in collected) {
      expect(manifest, contains(type), reason: type);
    }
    expect(
      'NSPrivacyCollectedDataTypePurposeAppFunctionality'.allMatches(manifest),
      hasLength(collected.length),
    );
    expect(
      'NSPrivacyCollectedDataTypePurposeAnalytics'.allMatches(manifest),
      hasLength(collected.length),
    );
    expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(
      '<key>NSPrivacyCollectedDataTypeTracking</key>\n\t\t\t<false/>'
          .allMatches(manifest),
      hasLength(collected.length),
    );
    expect(manifest, isNot(contains('<true/>\n\t\t\t<key>NSPrivacyCollectedDataTypePurposes</key>')));
  });

  test('does not declare advertising or an ads SDK', () {
    expect(manifest, isNot(contains('Advertising')));
    expect(manifest, isNot(contains('NSPrivacyCollectedDataTypeDeviceID')));
    expect(pubspec, isNot(contains('google_mobile_ads')));
    expect(pubspec, isNot(contains('app_tracking_transparency')));
    expect(worksheet, contains('広告SDKは入れていません'));
    expect(worksheet, contains('ヘルスケア由来のデータ'));
    expect(worksheet, contains('広告に使いません'));
  });

  test('worksheet matches the stored name, gender, purchase, search, and screens', () {
    expect(worksheet, contains('profiles.display_name'));
    expect(worksheet, contains('account_display_names'));
    expect(worksheet, contains('機微な情報'));
    expect(worksheet, contains('profiles.gender'));
    expect(worksheet, contains('calonavi_plus_entitlements'));
    expect(worksheet, contains('food_search_queries'));
    expect(worksheet, contains('exercise_search_queries'));
    expect(worksheet, contains('app_screen_actions'));
    expect(worksheet, contains('レシート本文'));
    expect(worksheet, contains('購入トークン'));
    expect(worksheet, contains('集めない'));
    expect(worksheet, isNot(contains('要確認')));
  });

  test('widget extension still sends nothing off the device', () {
    expect(
      widgetManifest,
      contains('<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>'),
    );
    expect(widgetManifest, contains('1C8F.1'));
    expect(widgetManifest, isNot(contains('NSPrivacyCollectedDataTypeName')));
  });
}
