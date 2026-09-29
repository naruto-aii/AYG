/// 公式食品検索の正規化。
///
/// SQL の `public.normalize_food_search_text` と同じ手順:
/// 半角濁点の合成、NFKC 相当（半角カナ→全角、全角英数→半角）、
/// カタカナ→ひらがな、小文字化、長音とハイフンの除去、空白除去。
///
/// [FoodNameNormalizer] は変えない。こちらは公式食品の検索専用。
abstract final class FoodSearchNormalizer {
  static const _dakutenBase = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';
  static const _dakutenTo = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ';
  static const _handakutenBase = 'ﾊﾋﾌﾍﾎ';
  static const _handakutenTo = 'パピプペポ';
  static const _halfwidthFrom =
      'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
  static const _halfwidthTo =
      'ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';

  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final composed = _composeHalfwidthVoiced(raw);
    final buffer = StringBuffer();
    for (final rune in composed.runes) {
      var code = rune;
      if (code >= 0xFF01 && code <= 0xFF5E) {
        code -= 0xFEE0;
      } else if (code == 0x3000) {
        code = 0x20;
      } else {
        final mapped = _halfwidthKatakana(code);
        if (mapped != null) {
          code = mapped;
        }
      }
      if (code >= 0x30A1 && code <= 0x30F6) {
        code -= 0x60;
      }
      if (code >= 0x41 && code <= 0x5A) {
        code += 0x20;
      }
      if (_isLongVowelOrHyphen(code) || _isWhitespace(code)) {
        continue;
      }
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  static String _composeHalfwidthVoiced(String text) {
    final buffer = StringBuffer();
    final runes = text.runes.toList();
    var index = 0;
    while (index < runes.length) {
      final code = runes[index];
      if (index + 1 < runes.length) {
        final next = runes[index + 1];
        if (next == 0xFF9E) {
          final at = _dakutenBase.indexOf(String.fromCharCode(code));
          if (at >= 0) {
            buffer.write(_dakutenTo[at]);
            index += 2;
            continue;
          }
        } else if (next == 0xFF9F) {
          final at = _handakutenBase.indexOf(String.fromCharCode(code));
          if (at >= 0) {
            buffer.write(_handakutenTo[at]);
            index += 2;
            continue;
          }
        }
      }
      buffer.writeCharCode(code);
      index += 1;
    }
    return buffer.toString();
  }

  static int? _halfwidthKatakana(int code) {
    if (code < 0xFF66 || code > 0xFF9D) {
      return null;
    }
    final ch = String.fromCharCode(code);
    final at = _halfwidthFrom.indexOf(ch);
    if (at < 0) {
      return null;
    }
    return _halfwidthTo.runes.elementAt(at);
  }

  static bool _isLongVowelOrHyphen(int code) {
    return code == 0x30FC ||
        code == 0x002D ||
        code == 0x2010 ||
        code == 0x2011 ||
        code == 0x2013 ||
        code == 0x2014 ||
        code == 0x2212;
  }

  static bool _isWhitespace(int code) {
    return code == 9 ||
        code == 10 ||
        code == 11 ||
        code == 12 ||
        code == 13 ||
        code == 32 ||
        code == 133 ||
        code == 160 ||
        code == 5760 ||
        (code >= 8192 && code <= 8202) ||
        code == 8232 ||
        code == 8233 ||
        code == 8239 ||
        code == 8287 ||
        code == 12288 ||
        code == 65279;
  }
}
