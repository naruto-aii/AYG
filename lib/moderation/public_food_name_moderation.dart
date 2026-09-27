import '../utils/food_name_normalizer.dart';
import 'public_food_banned_words.dart';

/// Client check for public food names.
///
/// Normalization is trim, case fold, full-width ASCII to half-width,
/// half-width and full-width katakana to hiragana, and separator folding.
class PublicFoodNameModeration {
  const PublicFoodNameModeration._();

  static const rejectionMessage = 'この食品名は公開できません。別の名前を入力してください。';

  /// Short Japanese terms that are common inside ordinary words.
  /// These match only on a boundary. Longer Japanese terms match as substrings.
  static const boundaryOnlyTerms = <String>{'えろ'};

  static bool isBanned(String raw) {
    final spaced = normalizeForMatch(raw);
    if (spaced.isEmpty) {
      return false;
    }
    final compact = spaced.replaceAll(' ', '');
    for (final term in publicFoodBannedWords) {
      final normalizedTerm = normalizeForMatch(term).replaceAll(' ', '');
      if (normalizedTerm.isEmpty) {
        continue;
      }
      if (_useSubstring(normalizedTerm)) {
        if (compact.contains(normalizedTerm)) {
          return true;
        }
      } else if (_containsBounded(spaced, normalizedTerm) ||
          _containsBounded(compact, normalizedTerm)) {
        return true;
      }
    }
    return false;
  }

  /// True when a public row's name is changing into a banned name.
  /// An unchanged name is left alone so older rows can still edit other fields.
  static bool rejectsPublicUpdate({
    required String previousName,
    required String nextName,
  }) {
    if (FoodNameNormalizer.normalize(previousName) ==
        FoodNameNormalizer.normalize(nextName)) {
      return false;
    }
    return isBanned(nextName);
  }

  static String normalizeForMatch(String raw) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in raw.runes) {
      final mapped = _mapRune(rune);
      if (mapped == null) {
        if (buffer.isNotEmpty) {
          pendingSpace = true;
        }
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.writeCharCode(mapped);
    }
    return buffer.toString();
  }

  static bool _useSubstring(String term) {
    if (RegExp('[a-z0-9]').hasMatch(term)) {
      return false;
    }
    if (boundaryOnlyTerms.contains(term)) {
      return false;
    }
    return term.runes.length >= 2;
  }

  static bool _containsBounded(String haystack, String term) {
    var start = 0;
    while (true) {
      final index = haystack.indexOf(term, start);
      if (index < 0) {
        return false;
      }
      final beforeOk =
          index == 0 || !_isWordCode(haystack.codeUnitAt(index - 1));
      final afterIndex = index + term.length;
      final afterOk =
          afterIndex >= haystack.length ||
          !_isWordCode(haystack.codeUnitAt(afterIndex));
      if (beforeOk && afterOk) {
        return true;
      }
      start = index + 1;
    }
  }

  static int? _mapRune(int rune) {
    if (rune == 0x3000 ||
        rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D) {
      return null;
    }

    var code = rune;
    if (code >= 0xFF10 && code <= 0xFF19) {
      code = 0x30 + (code - 0xFF10);
    } else if (code >= 0xFF21 && code <= 0xFF3A) {
      code = 0x61 + (code - 0xFF21);
    } else if (code >= 0xFF41 && code <= 0xFF5A) {
      code = 0x61 + (code - 0xFF41);
    } else {
      final halfwidth = _halfwidthKatakana[code];
      if (halfwidth != null) {
        code = halfwidth;
      }
    }

    if (code >= 0x30A1 && code <= 0x30F3) {
      code -= 0x60;
    }
    if (code >= 0x41 && code <= 0x5A) {
      code = 0x61 + (code - 0x41);
    }
    if (_isWordCode(code)) {
      return code;
    }
    return null;
  }

  static bool _isWordCode(int code) {
    if (code >= 0x30 && code <= 0x39) {
      return true;
    }
    if (code >= 0x61 && code <= 0x7A) {
      return true;
    }
    if (code >= 0x3041 && code <= 0x3096) {
      return true;
    }
    if (code >= 0x30A1 && code <= 0x30FA) {
      return true;
    }
    if (code >= 0x4E00 && code <= 0x9FFF) {
      return true;
    }
    return code == 0x30FC;
  }

  static final Map<int, int> _halfwidthKatakana = _buildHalfwidthMap();

  static Map<int, int> _buildHalfwidthMap() {
    final from = publicFoodHalfwidthKatakanaFrom.runes.toList();
    final to = publicFoodHalfwidthKatakanaTo.runes.toList();
    final map = <int, int>{};
    for (var i = 0; i < from.length && i < to.length; i++) {
      map[from[i]] = to[i];
    }
    return map;
  }
}
