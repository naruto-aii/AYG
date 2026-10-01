/// 利用者に見せるサポート窓口。メールの送信先もここ。
class AppContactConfig {
  AppContactConfig._();

  static const String publicSupportEmail = 'support@ayg.life';

  static String get contactEmail => publicSupportEmail;

  static bool get isConfigured => contactEmail.isNotEmpty;
}
