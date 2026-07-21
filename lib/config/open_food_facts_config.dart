/// Open Food Facts API 用の連絡先設定。
/// 連絡先メールは Git 管理外とし、実行時に dart-define で渡す。
///
/// 例:
/// flutter run --dart-define=OFF_CONTACT_EMAIL=your-contact@example.com
class OpenFoodFactsConfig {
  OpenFoodFactsConfig._();

  static const String contactEmail = String.fromEnvironment(
    'OFF_CONTACT_EMAIL',
  );
  static const String _placeholder = 'CONTACT_PLACEHOLDER';

  static String get userAgent => 'AYG/0.1 ($contactEmail)';

  static bool get isContactConfigured {
    final email = contactEmail.trim();
    if (email.isEmpty) {
      return false;
    }
    if (email.contains(_placeholder)) {
      return false;
    }
    return true;
  }
}
