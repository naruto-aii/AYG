/// Supabase / Google Auth 設定。
///
/// 例:
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ... \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=xxxx.apps.googleusercontent.com
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://ayg.app/terms',
  );
  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://ayg.app/privacy',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
