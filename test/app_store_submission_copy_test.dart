import 'dart:io';

import 'package:ayg/constants/app_strings.dart';
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

  test('published plus prices are the tax-included catalog', () {
    const sentence =
        '月額980円、半年4,900円（月あたり約817円。1か月分お得）、年額8,800円（月あたり約733円。月額より約25%お得）';
    for (final path in [
      'legal/terms.html',
      'docs/legal/terms.html',
      'legal/tokushoho.html',
      'docs/legal/tokushoho.html',
      'docs/app-store-listing-ja.md',
      'docs/index.html',
    ]) {
      expect(File(path).readAsStringSync(), contains(sentence), reason: path);
    }
    expect(
      File('legal/terms.html').readAsStringSync(),
      File('docs/legal/terms.html').readAsStringSync(),
    );
    expect(
      File('legal/tokushoho.html').readAsStringSync(),
      File('docs/legal/tokushoho.html').readAsStringSync(),
    );
    expect(AppStrings.plusFallbackMonthlyPrice, '¥980');
    expect(AppStrings.plusFallbackHalfYearPrice, '¥4,900');
    expect(AppStrings.plusFallbackYearlyPrice, '¥8,800');
    expect(980 * 5, 4900);
    expect((4900 / 6).round(), 817);
    expect((8800 / 12).round(), 733);
    final yearlyPerMonth = 8800 / 12;
    expect((980 - yearlyPerMonth) / 980, closeTo(0.2517, 0.0001));
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
      expect(html, isNot(contains('期限が来たら捨てます')), reason: path);
    }
  });

  test('estimate caches stay for reuse and are not described as discarded', () {
    const banned = '期限が来たら捨てます';
    const searchKept =
        '同じ検索の推定は、同じ利用者が再利用するために残します。キャッシュは食品の一覧としては出さず、他の利用者には出しません。アカウントを削除すると消します';
    const cookKept =
        '手持ちの食材だけでは作れる案が無かったときだけ、正規化した食材名と時刻を残します。利用者の識別子は入れないので、アカウントを削除しても消えません';
    for (final path in [
      'legal/privacy.html',
      'docs/legal/privacy.html',
      'legal/terms.html',
      'docs/legal/terms.html',
      'docs/app-store-privacy.md',
      'lib/screens/settings/analytics_settings_screen.dart',
      'supabase/functions/README.md',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains(banned)), reason: path);
      expect(text, isNot(contains('期限を過ぎた行は、次にその機能を使ったときに消します')), reason: path);
    }
    for (final path in ['legal/privacy.html', 'docs/legal/privacy.html']) {
      final html = File(path).readAsStringSync();
      expect(html, contains(searchKept), reason: path);
      expect(html, contains(cookKept), reason: path);
      expect(html, contains('推定に使ったあと捨てます'), reason: path);
    }
    final terms = File('legal/terms.html').readAsStringSync();
    expect(terms, contains('入力した食材や条件は外部のAI事業者へ送りません'));
    expect(terms, contains(cookKept));
    expect(terms, isNot(contains('献立の推定のため Anthropic')));
    final screen = File(
      'lib/screens/settings/analytics_settings_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('推定は同じ利用者が再利用するために残し、アカウントを削除すると消します'));
    expect(screen, isNot(contains('自炊コーチの、手元にある食材')));
    expect(
      File('supabase/functions/_shared/expired_cache.ts').existsSync(),
      isFalse,
    );
    expect(File('supabase/functions/expired_cache_test.ts').existsSync(), isFalse);
    for (final path in [
      'supabase/functions/lookup-food-text/handler.ts',
      'supabase/functions/cook-coach/handler.ts',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('deleteExpiredCache')));
    }
  });
}
