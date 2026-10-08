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
      'NSPrivacyCollectedDataTypeOtherUsageData',
    ];
    const analyticsOnly = [
      'NSPrivacyCollectedDataTypeCrashData',
      'NSPrivacyCollectedDataTypePerformanceData',
      'NSPrivacyCollectedDataTypeOtherDiagnosticData',
      'NSPrivacyCollectedDataTypeDeviceID',
      'NSPrivacyCollectedDataTypeAdvertisingData',
    ];
    const functionalityOnly = ['NSPrivacyCollectedDataTypePhotosorVideos'];
    for (final type in [...collected, ...analyticsOnly, ...functionalityOnly]) {
      expect(manifest, contains(type), reason: type);
    }
    expect(
      'NSPrivacyCollectedDataTypePurposeAppFunctionality'.allMatches(manifest),
      hasLength(collected.length + functionalityOnly.length),
    );
    expect(
      'NSPrivacyCollectedDataTypePurposeAnalytics'.allMatches(manifest),
      hasLength(collected.length + analyticsOnly.length),
    );
    expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(
      '<key>NSPrivacyCollectedDataTypeTracking</key>\n\t\t\t<false/>'
          .allMatches(manifest),
      hasLength(
        collected.length + analyticsOnly.length + functionalityOnly.length,
      ),
    );
    expect(
      manifest,
      isNot(
        contains(
          '<true/>\n\t\t\t<key>NSPrivacyCollectedDataTypePurposes</key>',
        ),
      ),
    );
  });

  test('records ads attribution without an ads SDK or tracking', () {
    expect(manifest, contains('NSPrivacyCollectedDataTypeAdvertisingData'));
    expect(manifest, contains('NSPrivacyCollectedDataTypeDeviceID'));
    expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(pubspec, isNot(contains('google_mobile_ads')));
    expect(pubspec, isNot(contains('app_tracking_transparency')));
    expect(worksheet, contains('広告SDKは入れていません'));
    expect(worksheet, contains('ヘルスケア由来のデータ'));
    expect(worksheet, contains('広告に使いません'));
    expect(worksheet, contains('追跡もしません'));
  });

  test(
    'worksheet matches the stored name, gender, purchase, search, and screens',
    () {
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
    },
  );

  test('widget extension records the button press on the device', () {
    expect(
      widgetManifest,
      contains('NSPrivacyCollectedDataTypeProductInteraction'),
    );
    expect(
      widgetManifest,
      contains('NSPrivacyCollectedDataTypeOtherUsageData'),
    );
    expect(widgetManifest, contains('1C8F.1'));
    expect(widgetManifest, isNot(contains('NSPrivacyCollectedDataTypeName')));
    expect(
      widgetManifest,
      contains('<key>NSPrivacyTracking</key>\n\t<false/>'),
    );
  });
}
