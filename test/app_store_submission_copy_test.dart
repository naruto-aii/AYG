import 'dart:io';

import 'package:ayg/content/daily_calorie_target_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS copy does not name another store or OS', () {
    final explanation = DailyCalorieTargetExplanation.sections
        .map((section) => '${section.$1}\n${section.$2}')
        .join('\n');
    expect(explanation, isNot(contains('Android')));
    expect(explanation, isNot(contains('Google Play')));
    expect(explanation, isNot(contains('Health Connect')));
    expect(explanation, contains('ヘルスケア'));

    for (final path in [
      'legal/terms.html',
      'legal/tokushoho.html',
      'docs/legal/terms.html',
      'docs/legal/tokushoho.html',
    ]) {
      final html = File(path).readAsStringSync();
      expect(html, isNot(contains('Google Play')), reason: path);
      expect(html, isNot(contains('Android')), reason: path);
      expect(html, contains('App Store'), reason: path);
    }
  });

  test('Sign in with Apple and Health purpose strings are in the iOS target', () {
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    expect(entitlements, contains('com.apple.developer.applesignin'));
    expect(entitlements, contains('Default'));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSHealthShareUsageDescription'));
    expect(plist, contains('生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト'));
    expect(plist, contains('ヘルスケアへ書き込みません'));
    expect(plist, isNot(contains('必要に応じてHealthデータを更新')));
  });

  test('privacy policy names Singapore and drops draft wording', () {
    const required = [
      '3-2. 利用状況の記録',
      '保存先はシンガポールです（Supabase, Inc. のデータベース。Amazon Web Services のシンガポール地域）。シンガポールには個人情報保護法（PDPA）があり、運営者はその制度を把握したうえで保存します。',
      'Apple Health（Apple Inc.）の連携を許諾した場合の、',
      'Apple Health との連携は任意です。使わない場合は、活動量の手選択で目標を計算します。許諾の取り消しは、iPhone の設定（ヘルスケア）から行えます。',
      'Apple Health から取得したデータは、',
      'Google LLC（Google ログイン）',
      'Supabase, Inc.（クラウド上のデータベースと認証。保存先はシンガポール）',
      '個人データは日本国外（Supabase はシンガポール）で取り扱われます。',
      'アカウントを削除すると、氏名・メールアドレス・ログイン情報・生年月日・メモなど、個人を特定できる情報と、購入の取引番号との対応を消します。食事・運動・体重などの記録と操作の記録は、誰のものかわからない形（年代・性別など大まかな属性のみを付け、他の情報と照合しても本人を特定できない形）に加工し、サービスの改善と分析のために残します。',
      'アカウントを削除すると、個人を特定できる情報は削除し、記録は誰のものかわからない形に加工して残します。',
    ];
    String? first;
    for (final path in ['legal/privacy.html', 'docs/legal/privacy.html']) {
      final html = File(path).readAsStringSync();
      first ??= html;
      expect(html, first, reason: path);
      for (final phrase in required) {
        expect(html, contains(phrase), reason: path);
      }
      expect(html, isNot(contains('社長確認')), reason: path);
      expect(html, isNot(contains('文案')), reason: path);
      expect(html, isNot(contains('Health Connect')), reason: path);
      expect(html, isNot(contains('最終更新日は 2026-10-07 です。')), reason: path);
    }
  });
}
