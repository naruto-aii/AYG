/// Google OAuth クライアント ID の形を確かめる。
///
/// iOS の Google Sign-In SDK は、クライアント ID が壊れている・Info.plist に
/// 逆順 ID の URL スキームが無いと、例外でアプリごと落ちる（エラーで返らない）。
/// ネイティブを呼ぶ前にここで止めて、クラッシュではなく失敗表示にする。
class GoogleClientId {
  GoogleClientId._();

  static final RegExp _pattern = RegExp(
    r'^([0-9]+)-[0-9a-z]+\.apps\.googleusercontent\.com$',
  );

  /// `123-abc.apps.googleusercontent.com` の形なら true。
  /// 逆順 ID（com.googleusercontent.apps.…）やバンドル ID、カンマ区切りは false。
  static bool isValid(String value) => _pattern.hasMatch(value);

  /// Google Cloud のプロジェクト番号（ID の先頭の数字）。形が違えば null。
  static String? projectNumber(String value) =>
      _pattern.firstMatch(value)?.group(1);

  /// Info.plist の URL スキームに入れる逆順 ID。形が違えば null。
  static String? reversed(String value) {
    if (!isValid(value)) {
      return null;
    }
    final prefix = value.substring(
      0,
      value.length - '.apps.googleusercontent.com'.length,
    );
    return 'com.googleusercontent.apps.$prefix';
  }

  /// iOS でネイティブの Google ログインを呼んでよいか。問題があれば理由を返す。
  static String? iosProblem({
    required String iosClientId,
    required String webClientId,
  }) {
    if (iosClientId.isEmpty) {
      return 'GOOGLE_IOS_CLIENT_ID is not set.';
    }
    if (!isValid(iosClientId)) {
      return 'GOOGLE_IOS_CLIENT_ID is not a Google iOS client ID.';
    }
    if (webClientId.isEmpty) {
      return null;
    }
    if (!isValid(webClientId)) {
      return 'GOOGLE_WEB_CLIENT_ID is not a Google client ID.';
    }
    if (projectNumber(iosClientId) != projectNumber(webClientId)) {
      return 'GOOGLE_IOS_CLIENT_ID and GOOGLE_WEB_CLIENT_ID are from '
          'different Google Cloud projects.';
    }
    return null;
  }
}
