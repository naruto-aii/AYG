/// 成分表の一覧用ラベル。
///
/// 大きい見出しは品名から始める。＜魚類＞（まぐろ類）のような分類は
/// 見出しに出さず、下の行へ短く置く。
abstract final class OfficialFoodListLabel {
  static const categoryKcalSeparator = ' · ';

  /// 分類として見出しから外す、先頭の ＜＞ と （）。
  static final _leadingClass = RegExp(r'^(?:[＜<][^＞>]+[＞>]|[（(][^）)]+[）)])');

  /// 類を取るだけでは長い見出し。一覧の1行に収まる短い呼び方。
  static const _shortNames = <String, String>{
    '牛乳及び乳製品': '乳',
    '和生菓子・和半生菓子類': '和菓子',
    '和干菓子類': '干菓子',
    'アルコール飲料類': '酒',
    'でん粉・でん粉製品': 'でん粉',
    '水産練り製品': '練り物',
    'ケーキ・ペストリー類': 'ケーキ',
    'コーヒー・ココア類': 'コーヒー',
    '発酵乳・乳酸菌飲料': '発酵乳',
    '植物油脂類': '植物油',
    '動物油脂類': '動物油',
    'その他': '',
  };

  /// カロリー行に置ける分類の長さ。超えたら後ろの分類から省く。
  static const _maxCategoryLength = 8;

  /// 一覧の大きい見出し。表示名を優先し、分類見出しは除く。
  static String productTitle({
    String? displayName,
    required String officialName,
    String? alias,
  }) {
    final display = displayName?.trim() ?? '';
    if (display.isNotEmpty) {
      return _withoutLeadingClass(display);
    }
    final aliasText = alias?.trim() ?? '';
    if (aliasText.isNotEmpty) {
      return _withoutLeadingClass(aliasText);
    }
    return _withoutLeadingClass(officialName);
  }

  /// 正式名称の先頭にある分類を、短い語にして「魚・まぐろ」の形にする。
  static String category(String officialName) {
    final parts = _leadingParts(officialName);
    if (parts.isEmpty) {
      return '';
    }
    final kept = <String>[];
    for (final part in parts) {
      final next = kept.isEmpty ? part : '${kept.join('・')}・$part';
      if (next.runes.length > _maxCategoryLength) {
        break;
      }
      kept.add(part);
    }
    return kept.join('・');
  }

  static String _withoutLeadingClass(String text) {
    final rest = _remainder(text).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (rest.isEmpty) {
      return text.trim();
    }
    return rest;
  }

  static List<String> _leadingParts(String text) {
    final parts = <String>[];
    var rest = text.trim();
    while (true) {
      final match = _leadingClass.firstMatch(rest);
      if (match == null) {
        break;
      }
      final inner = match.group(0)!;
      final short = _shorten(_innerText(inner));
      if (short.isNotEmpty) {
        parts.add(short);
      }
      rest = rest.substring(match.end).trim();
    }
    return parts;
  }

  static String _remainder(String text) {
    var rest = text.trim();
    while (_leadingClass.hasMatch(rest)) {
      rest = rest.replaceFirst(_leadingClass, '').trim();
    }
    return rest;
  }

  static String _innerText(String token) {
    if (token.length < 2) {
      return '';
    }
    return token.substring(1, token.length - 1).trim();
  }

  static String _shorten(String inner) {
    final mapped = _shortNames[inner];
    if (mapped != null) {
      return mapped;
    }
    if (inner.endsWith('類') && inner.runes.length > 1) {
      return String.fromCharCodes(inner.runes.toList()..removeLast());
    }
    return inner;
  }
}
