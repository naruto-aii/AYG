/// サインインが実際に返した名前と、ユーザー名欄の初期値。
///
/// 読むのは次だけ。
/// - Apple の認可クレデンシャルの givenName / familyName
/// - Google アカウントの displayName
/// - Supabase の user_metadata に入っている `full_name` または `name`
///
/// HealthKit / Health Connect からは氏名を読まない。上のどれも無いときは null。
class DisplayName {
  DisplayName._();

  static const maxLength = 40;

  static String? normalize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  /// Apple が返した givenName と familyName を、空でないものだけ空白でつなぐ。
  static String? fromPersonName({String? givenName, String? familyName}) {
    final parts = <String>[?normalize(givenName), ?normalize(familyName)];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  }

  /// Google / Apple の OAuth が user_metadata に置くキーだけを見る。
  static String? fromUserMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      return null;
    }
    for (final key in const ['full_name', 'name']) {
      final value = metadata[key];
      if (value is! String) {
        continue;
      }
      final normalized = normalize(value);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  /// 保存済みの名前があればそれを、無ければ連携の提案を、どちらも無ければ空欄。
  static String fieldValue({String? saved, String? suggested}) {
    return normalize(saved) ?? normalize(suggested) ?? '';
  }

  static DisplayNameError? validate(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      return DisplayNameError.empty;
    }
    if (name.length > maxLength) {
      return DisplayNameError.tooLong;
    }
    return null;
  }
}

enum DisplayNameError { empty, tooLong }
