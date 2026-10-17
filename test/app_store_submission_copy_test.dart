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
      'Apple Health から取得したデータは、1日の食事目標の計算と記録に使います。分析には使いません。',
      '写真で登録、外食・コンビニ、AIで探すでは、入力内容をAnthropic, PBC（米国）に送ります。',
      '同意してはじめる',
      '委託先も、このポリシーと同等の保護をします。',
      'Google LLC（Google ログイン）',
      'Supabase, Inc.（クラウド上のデータベースと認証。保存先はシンガポール）',
      '個人データは日本国外（Supabase はシンガポール、Anthropic, PBC は米国）で取り扱われます。',
      '利用者IDとは別の、退会のたびに新しく作る番号を付けて残します。この番号は利用者IDからは作れず、対応表は残しません。',
      'ワークアウトの種目と開始と終了と消費カロリー',
      'アクティブエネルギーの数値、運動の検索語、テンプレートの名前と中身、メモの文面、端末の機種、インストールごとの番号は残しません。',
      '医療上の注意は、利用規約に書いています。',
      '最終更新日: 公開する日',
      'Slack Technologies, LLC（米国',
      '退会後も、ワークアウトの種目、開始、終了、消費カロリーと、体重の記録（記録元を含む）は、利用者IDと切り離した番号を付けて残します。',
    ];
    const forbidden = [
      '社長確認',
      '文案',
      'Health Connect',
      '最終更新日は 2026-10-07 です。',
      '誰のものかわからない',
      '大まかな属性のみ',
      '分析のために',
      '利用状況の分析',
      'サービス改善のための分析',
      '医療上の診断・治療・予防・栄養指導を目的としません',
      '初回起動時に、ログインの前に',
      '30日以内に削除',
    ];
    String? first;
    for (final path in ['legal/privacy.html', 'docs/legal/privacy.html']) {
      final html = File(path).readAsStringSync();
      first ??= html;
      expect(html, first, reason: path);
      for (final phrase in required) {
        expect(html, contains(phrase), reason: path);
      }
      for (final phrase in forbidden) {
        expect(html, isNot(contains(phrase)), reason: '$path contains $phrase');
      }
    }

    final terms = File('legal/terms.html').readAsStringSync();
    expect(terms, contains('医療行為、診断、治療、予防、栄養指導の代替ではありません。'));

    const usagePurpose =
        '使いにくい画面を直すこと、およびどの機能がカロナビ+の利用につながっているかを見るために使う場合があります。';
    final publishedTerms = File('docs/legal/terms.html').readAsStringSync();
    expect(publishedTerms, contains(usagePurpose));
    expect(publishedTerms, contains('最終更新日: 公開する日'));
    expect(publishedTerms, isNot(contains('サービス改善のための分析')));
    expect(publishedTerms, isNot(contains('30日以内に削除')));

    String? deletion;
    for (final path in [
      'legal/account-deletion.html',
      'docs/legal/account-deletion.html',
    ]) {
      final html = File(path).readAsStringSync();
      deletion ??= html;
      expect(html, deletion, reason: path);
      expect(html, isNot(contains('分析のために')), reason: path);
      expect(html, isNot(contains('誰のものかわからない')), reason: path);
      expect(html, contains('プライバシーポリシーの「保管と削除」と同じです。'), reason: path);
    }
  });
}
