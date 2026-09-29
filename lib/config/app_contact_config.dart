/// 運営連絡先。Git 管理外とし、実行時に dart-define で渡す。
///
/// 例:
/// flutter run --dart-define=SUPPORT_EMAIL=calonavi.ayg.support@gmail.com
class AppContactConfig {
  AppContactConfig._();

  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const String offContactEmail = String.fromEnvironment(
    'OFF_CONTACT_EMAIL',
  );

  /// `SUPPORT_EMAIL` を優先し、未設定なら `OFF_CONTACT_EMAIL` にフォールバックする。
  static String get contactEmail {
    final support = supportEmail.trim();
    if (support.isNotEmpty) {
      return support;
    }
    return offContactEmail.trim();
  }

  static bool get isConfigured => contactEmail.isNotEmpty;
}
